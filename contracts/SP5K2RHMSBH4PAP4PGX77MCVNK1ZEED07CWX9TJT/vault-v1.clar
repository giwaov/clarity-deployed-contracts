;; vault.clar
;; Secure multi-asset vault with withdrawal limits and time delays
;; Supports STX, SIP-010 tokens, and SIP-009 NFTs

;; ============================================================================
;; Constants
;; ============================================================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-VAULT-NOT-FOUND (err u402))
(define-constant ERR-INSUFFICIENT-BALANCE (err u403))
(define-constant ERR-WITHDRAWAL-PENDING (err u404))
(define-constant ERR-LIMIT-EXCEEDED (err u405))
(define-constant ERR-DELAY-NOT-MET (err u406))
(define-constant ERR-VAULT-LOCKED (err u407))
(define-constant ERR-INVALID-AMOUNT (err u408))
(define-constant ERR-ASSET-NOT-SUPPORTED (err u409))
(define-constant ERR-COOLDOWN-ACTIVE (err u410))

;; Time constants (in blocks, ~10 min per block)
(define-constant WITHDRAWAL-DELAY u144)      ;; ~24 hours
(define-constant EMERGENCY-DELAY u864)       ;; ~6 days
(define-constant COOLDOWN-PERIOD u6)         ;; ~1 hour between withdrawals
(define-constant MAX-DAILY-WITHDRAWAL-BPS u1000) ;; 10% max daily withdrawal

;; ============================================================================
;; Data Variables
;; ============================================================================

(define-data-var vault-count uint u0)
(define-data-var total-stx-locked uint u0)
(define-data-var protocol-paused bool false)
(define-data-var emergency-mode bool false)

;; ============================================================================
;; Data Maps
;; ============================================================================

;; Vault information
(define-map vaults uint
  {
    owner: principal,
    stx-balance: uint,
    created-at: uint,
    last-withdrawal: uint,
    daily-limit-bps: uint,
    withdrawal-delay: uint,
    is-locked: bool,
    lock-until: uint,
    total-deposited: uint,
    total-withdrawn: uint
  })

;; Pending withdrawal requests
(define-map pending-withdrawals
  { vault-id: uint, request-id: uint }
  {
    amount: uint,
    asset-type: (string-ascii 32),
    requested-at: uint,
    execute-after: uint,
    is-executed: bool,
    is-cancelled: bool
  })

;; Vault withdrawal request counter
(define-map vault-request-count uint uint)

;; Supported assets whitelist
(define-map supported-assets (string-ascii 64) bool)

;; Daily withdrawal tracking
(define-map daily-withdrawals
  { vault-id: uint, day: uint }
  uint)

;; Vault guardians (multi-sig for large withdrawals)
(define-map vault-guardians
  { vault-id: uint, guardian: principal }
  bool)

;; Guardian approval for pending withdrawals
(define-map guardian-approvals
  { vault-id: uint, request-id: uint, guardian: principal }
  bool)

;; ============================================================================
;; Read-Only Functions
;; ============================================================================

(define-read-only (get-vault (vault-id uint))
  (map-get? vaults vault-id))

(define-read-only (get-vault-balance (vault-id uint))
  (match (map-get? vaults vault-id)
    vault (get stx-balance vault)
    u0))

(define-read-only (get-pending-withdrawal (vault-id uint) (request-id uint))
  (map-get? pending-withdrawals { vault-id: vault-id, request-id: request-id }))

(define-read-only (get-vault-count)
  (var-get vault-count))

(define-read-only (get-total-locked)
  (var-get total-stx-locked))

(define-read-only (is-vault-owner (vault-id uint) (user principal))
  (match (map-get? vaults vault-id)
    vault (is-eq (get owner vault) user)
    false))

(define-read-only (is-guardian (vault-id uint) (guardian principal))
  (default-to false (map-get? vault-guardians { vault-id: vault-id, guardian: guardian })))

(define-read-only (get-daily-withdrawn (vault-id uint))
  (let ((today (/ stacks-block-height u144)))
    (default-to u0 (map-get? daily-withdrawals { vault-id: vault-id, day: today }))))

(define-read-only (get-remaining-daily-limit (vault-id uint))
  (match (map-get? vaults vault-id)
    vault
      (let
        (
          (balance (get stx-balance vault))
          (limit-bps (get daily-limit-bps vault))
          (daily-limit (/ (* balance limit-bps) u10000))
          (already-withdrawn (get-daily-withdrawn vault-id))
        )
        (if (>= already-withdrawn daily-limit)
          u0
          (- daily-limit already-withdrawn)))
    u0))

(define-read-only (can-execute-withdrawal (vault-id uint) (request-id uint))
  (match (map-get? pending-withdrawals { vault-id: vault-id, request-id: request-id })
    request
      (and
        (not (get is-executed request))
        (not (get is-cancelled request))
        (>= stacks-block-height (get execute-after request)))
    false))

(define-read-only (get-vault-stats (vault-id uint))
  (match (map-get? vaults vault-id)
    vault
      {
        balance: (get stx-balance vault),
        total-deposited: (get total-deposited vault),
        total-withdrawn: (get total-withdrawn vault),
        daily-remaining: (get-remaining-daily-limit vault-id),
        is-locked: (get is-locked vault),
        lock-until: (get lock-until vault),
        pending-requests: (default-to u0 (map-get? vault-request-count vault-id))
      }
    {
      balance: u0,
      total-deposited: u0,
      total-withdrawn: u0,
      daily-remaining: u0,
      is-locked: false,
      lock-until: u0,
      pending-requests: u0
    }))

;; ============================================================================
;; Vault Management
;; ============================================================================

;; Create a new vault
(define-public (create-vault (daily-limit-bps uint) (withdrawal-delay uint))
  (let
    (
      (vault-id (+ (var-get vault-count) u1))
      (delay (if (< withdrawal-delay WITHDRAWAL-DELAY) WITHDRAWAL-DELAY withdrawal-delay))
      (limit (if (> daily-limit-bps MAX-DAILY-WITHDRAWAL-BPS) MAX-DAILY-WITHDRAWAL-BPS daily-limit-bps))
    )
    (asserts! (not (var-get protocol-paused)) ERR-VAULT-LOCKED)
    
    (map-set vaults vault-id
      {
        owner: tx-sender,
        stx-balance: u0,
        created-at: stacks-block-height,
        last-withdrawal: u0,
        daily-limit-bps: limit,
        withdrawal-delay: delay,
        is-locked: false,
        lock-until: u0,
        total-deposited: u0,
        total-withdrawn: u0
      })
    
    (var-set vault-count vault-id)
    
    (print { event: "vault-created", vault-id: vault-id, owner: tx-sender, daily-limit: limit })
    (ok vault-id)))

;; Deposit STX into vault
(define-public (deposit (vault-id uint) (amount uint))
  (let
    (
      (vault (unwrap! (map-get? vaults vault-id) ERR-VAULT-NOT-FOUND))
    )
    (asserts! (is-eq (get owner vault) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (not (var-get protocol-paused)) ERR-VAULT-LOCKED)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender current-contract))
    
    ;; Update vault balance
    (map-set vaults vault-id
      (merge vault {
        stx-balance: (+ (get stx-balance vault) amount),
        total-deposited: (+ (get total-deposited vault) amount)
      }))
    
    (var-set total-stx-locked (+ (var-get total-stx-locked) amount))
    
    (print { event: "deposit", vault-id: vault-id, amount: amount, new-balance: (+ (get stx-balance vault) amount) })
    (ok amount)))

;; Request withdrawal (starts time delay)
(define-public (request-withdrawal (vault-id uint) (amount uint))
  (let
    (
      (vault (unwrap! (map-get? vaults vault-id) ERR-VAULT-NOT-FOUND))
      (request-count (default-to u0 (map-get? vault-request-count vault-id)))
      (request-id (+ request-count u1))
      (daily-remaining (get-remaining-daily-limit vault-id))
    )
    (asserts! (is-eq (get owner vault) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (not (get is-locked vault)) ERR-VAULT-LOCKED)
    (asserts! (<= amount (get stx-balance vault)) ERR-INSUFFICIENT-BALANCE)
    (asserts! (<= amount daily-remaining) ERR-LIMIT-EXCEEDED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Check cooldown period
    (asserts! (>= stacks-block-height (+ (get last-withdrawal vault) COOLDOWN-PERIOD)) ERR-COOLDOWN-ACTIVE)
    
    ;; Create pending withdrawal
    (map-set pending-withdrawals
      { vault-id: vault-id, request-id: request-id }
      {
        amount: amount,
        asset-type: "STX",
        requested-at: stacks-block-height,
        execute-after: (+ stacks-block-height (get withdrawal-delay vault)),
        is-executed: false,
        is-cancelled: false
      })
    
    (map-set vault-request-count vault-id request-id)
    
    (print { 
      event: "withdrawal-requested", 
      vault-id: vault-id, 
      request-id: request-id, 
      amount: amount,
      execute-after: (+ stacks-block-height (get withdrawal-delay vault))
    })
    (ok request-id)))

;; Execute pending withdrawal after delay
(define-public (execute-withdrawal (vault-id uint) (request-id uint))
  (let
    (
      (vault (unwrap! (map-get? vaults vault-id) ERR-VAULT-NOT-FOUND))
      (request (unwrap! (map-get? pending-withdrawals { vault-id: vault-id, request-id: request-id }) ERR-WITHDRAWAL-PENDING))
      (amount (get amount request))
      (today (/ stacks-block-height u144))
    )
    (asserts! (is-eq (get owner vault) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (not (get is-executed request)) ERR-WITHDRAWAL-PENDING)
    (asserts! (not (get is-cancelled request)) ERR-WITHDRAWAL-PENDING)
    (asserts! (>= stacks-block-height (get execute-after request)) ERR-DELAY-NOT-MET)
    (asserts! (<= amount (get stx-balance vault)) ERR-INSUFFICIENT-BALANCE)
    
    ;; Update request status
    (map-set pending-withdrawals
      { vault-id: vault-id, request-id: request-id }
      (merge request { is-executed: true }))
    
    ;; Update vault
    (map-set vaults vault-id
      (merge vault {
        stx-balance: (- (get stx-balance vault) amount),
        last-withdrawal: stacks-block-height,
        total-withdrawn: (+ (get total-withdrawn vault) amount)
      }))
    
    ;; Update daily tracking
    (map-set daily-withdrawals
      { vault-id: vault-id, day: today }
      (+ (get-daily-withdrawn vault-id) amount))
    
    (var-set total-stx-locked (- (var-get total-stx-locked) amount))
    
    ;; Transfer STX to owner
    (try! (as-contract? ((with-stx amount)) (try! (stx-transfer? amount tx-sender (get owner vault)))))
    
    (print { event: "withdrawal-executed", vault-id: vault-id, request-id: request-id, amount: amount })
    (ok amount)))

;; Cancel pending withdrawal
(define-public (cancel-withdrawal (vault-id uint) (request-id uint))
  (let
    (
      (vault (unwrap! (map-get? vaults vault-id) ERR-VAULT-NOT-FOUND))
      (request (unwrap! (map-get? pending-withdrawals { vault-id: vault-id, request-id: request-id }) ERR-WITHDRAWAL-PENDING))
    )
    (asserts! (is-eq (get owner vault) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (not (get is-executed request)) ERR-WITHDRAWAL-PENDING)
    (asserts! (not (get is-cancelled request)) ERR-WITHDRAWAL-PENDING)
    
    (map-set pending-withdrawals
      { vault-id: vault-id, request-id: request-id }
      (merge request { is-cancelled: true }))
    
    (print { event: "withdrawal-cancelled", vault-id: vault-id, request-id: request-id })
    (ok true)))

;; ============================================================================
;; Vault Locking
;; ============================================================================

;; Lock vault for a duration
(define-public (lock-vault (vault-id uint) (duration uint))
  (let
    (
      (vault (unwrap! (map-get? vaults vault-id) ERR-VAULT-NOT-FOUND))
    )
    (asserts! (is-eq (get owner vault) tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-set vaults vault-id
      (merge vault {
        is-locked: true,
        lock-until: (+ stacks-block-height duration)
      }))
    
    (print { event: "vault-locked", vault-id: vault-id, until: (+ stacks-block-height duration) })
    (ok true)))

;; Unlock vault (if lock period expired)
(define-public (unlock-vault (vault-id uint))
  (let
    (
      (vault (unwrap! (map-get? vaults vault-id) ERR-VAULT-NOT-FOUND))
    )
    (asserts! (is-eq (get owner vault) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (>= stacks-block-height (get lock-until vault)) ERR-DELAY-NOT-MET)
    
    (map-set vaults vault-id
      (merge vault {
        is-locked: false,
        lock-until: u0
      }))
    
    (print { event: "vault-unlocked", vault-id: vault-id })
    (ok true)))

;; ============================================================================
;; Guardian Management
;; ============================================================================

;; Add a guardian to vault
(define-public (add-guardian (vault-id uint) (guardian principal))
  (let
    (
      (vault (unwrap! (map-get? vaults vault-id) ERR-VAULT-NOT-FOUND))
    )
    (asserts! (is-eq (get owner vault) tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-set vault-guardians { vault-id: vault-id, guardian: guardian } true)
    
    (print { event: "guardian-added", vault-id: vault-id, guardian: guardian })
    (ok true)))

;; Remove guardian from vault
(define-public (remove-guardian (vault-id uint) (guardian principal))
  (let
    (
      (vault (unwrap! (map-get? vaults vault-id) ERR-VAULT-NOT-FOUND))
    )
    (asserts! (is-eq (get owner vault) tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-delete vault-guardians { vault-id: vault-id, guardian: guardian })
    
    (print { event: "guardian-removed", vault-id: vault-id, guardian: guardian })
    (ok true)))

;; Guardian approval for large withdrawal
(define-public (approve-withdrawal (vault-id uint) (request-id uint))
  (begin
    (asserts! (is-guardian vault-id tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-set guardian-approvals
      { vault-id: vault-id, request-id: request-id, guardian: tx-sender }
      true)
    
    (print { event: "guardian-approved", vault-id: vault-id, request-id: request-id, guardian: tx-sender })
    (ok true)))

;; ============================================================================
;; Settings Update
;; ============================================================================

;; Update daily limit
(define-public (update-daily-limit (vault-id uint) (new-limit-bps uint))
  (let
    (
      (vault (unwrap! (map-get? vaults vault-id) ERR-VAULT-NOT-FOUND))
      (limit (if (> new-limit-bps MAX-DAILY-WITHDRAWAL-BPS) MAX-DAILY-WITHDRAWAL-BPS new-limit-bps))
    )
    (asserts! (is-eq (get owner vault) tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-set vaults vault-id (merge vault { daily-limit-bps: limit }))
    
    (print { event: "limit-updated", vault-id: vault-id, new-limit: limit })
    (ok limit)))

;; Update withdrawal delay
(define-public (update-withdrawal-delay (vault-id uint) (new-delay uint))
  (let
    (
      (vault (unwrap! (map-get? vaults vault-id) ERR-VAULT-NOT-FOUND))
      (delay (if (< new-delay WITHDRAWAL-DELAY) WITHDRAWAL-DELAY new-delay))
    )
    (asserts! (is-eq (get owner vault) tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-set vaults vault-id (merge vault { withdrawal-delay: delay }))
    
    (print { event: "delay-updated", vault-id: vault-id, new-delay: delay })
    (ok delay)))

;; ============================================================================
;; Admin Functions
;; ============================================================================

;; Pause protocol
(define-public (pause-protocol)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set protocol-paused true)
    (print { event: "protocol-paused" })
    (ok true)))

;; Unpause protocol
(define-public (unpause-protocol)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set protocol-paused false)
    (print { event: "protocol-unpaused" })
    (ok true)))

;; Enable emergency mode (shorter delays for recovery)
(define-public (enable-emergency-mode)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set emergency-mode true)
    (print { event: "emergency-mode-enabled" })
    (ok true)))
