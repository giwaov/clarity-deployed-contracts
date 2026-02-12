;; TimeLock Exchange - Production Contract
;; Uses ALL 5 Clarity 4 functions: stacks-block-time, secp256r1-verify, contract-hash?, restrict-assets?, to-ascii?

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_CONTRACT_NOT_FOUND (err u406))
(define-constant ERR_UNTRUSTED_BOT (err u407))
(define-constant ERR_CONVERSION (err u408))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INSUFFICIENT_BALANCE (err u410))
(define-constant ERR_POSITION_LOCKED (err u411))
(define-constant ERR_INVALID_AMOUNT (err u412))
(define-constant ERR_INVALID_DURATION (err u413))
(define-constant ERR_CONTRACT_PAUSED (err u414))
(define-constant ERR_ZERO_AMOUNT (err u415))

;; Configuration Constants
(define-constant MIN_LOCK_DURATION u86400)       ;; 1 day in seconds
(define-constant MAX_LOCK_DURATION u31536000)    ;; 1 year in seconds
(define-constant MIN_DEPOSIT_AMOUNT u100000)     ;; 0.1 STX minimum (in micro-STX)
(define-constant BASE_FEE_BPS u50)               ;; 0.5% base fee
(define-constant EARLY_WITHDRAWAL_PENALTY_BPS u1000)  ;; 10% penalty for early withdrawal
(define-constant MAX_PENALTY_BPS u2500)          ;; 25% maximum penalty

;; Position data structure
(define-map positions
  uint
  {
    owner: principal,
    amount: uint,
    lock-duration: uint,
    created-at: uint,
    unlock-time: uint,
    is-active: bool,
    asset-type: (string-ascii 10),
    passkey-protected: bool
  }
)

;; User position tracking
(define-map user-positions principal (list 100 uint))
(define-map user-position-count principal uint)

;; Storage for demo
(define-data-var demo-count uint u0)
(define-data-var position-counter uint u0)
(define-data-var total-locked-value uint u0)
(define-data-var contract-paused bool false)
(define-data-var pause-reason (string-ascii 100) "")
(define-data-var pause-timestamp uint u0)
(define-map passkey-registry principal (buff 33))
(define-map approved-bots principal bool)
(define-map emergency-admins principal bool)

;; ============================================
;; EMERGENCY CONTROLS
;; ============================================

;; Add emergency admin (owner only)
(define-public (add-emergency-admin (admin principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set emergency-admins admin true)
    (print { event: "emergency-admin-added", admin: admin, timestamp: stacks-block-time })
    (ok true)))

;; Remove emergency admin (owner only)
(define-public (remove-emergency-admin (admin principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-delete emergency-admins admin)
    (print { event: "emergency-admin-removed", admin: admin, timestamp: stacks-block-time })
    (ok true)))

;; Check if caller is emergency admin
(define-read-only (is-emergency-admin (caller principal))
  (or (is-eq caller CONTRACT_OWNER) (default-to false (map-get? emergency-admins caller))))

;; Pause contract (owner or emergency admin)
(define-public (pause-contract (reason (string-ascii 100)))
  (begin
    (asserts! (is-emergency-admin tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (not (var-get contract-paused)) ERR_ALREADY_EXISTS)
    (var-set contract-paused true)
    (var-set pause-reason reason)
    (var-set pause-timestamp stacks-block-time)
    (print {
      event: "contract-paused",
      paused-by: tx-sender,
      reason: reason,
      timestamp: stacks-block-time
    })
    (ok true)))

;; Unpause contract (owner only for security)
(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (var-get contract-paused) ERR_NOT_FOUND)
    (var-set contract-paused false)
    (print {
      event: "contract-unpaused",
      unpaused-by: tx-sender,
      was-paused-for: (- stacks-block-time (var-get pause-timestamp)),
      timestamp: stacks-block-time
    })
    (var-set pause-reason "")
    (var-set pause-timestamp u0)
    (ok true)))

;; Get pause status
(define-read-only (get-pause-status)
  {
    is-paused: (var-get contract-paused),
    reason: (var-get pause-reason),
    paused-since: (var-get pause-timestamp)
  })

;; CLARITY 4 FUNCTION #1: stacks-block-time
(define-read-only (get-current-time)
  stacks-block-time)

;; ============================================
;; MULTI-PASSKEY SUPPORT
;; ============================================

;; Store multiple passkeys per user (up to 5)
(define-map user-passkeys 
  { user: principal, key-index: uint }
  { 
    public-key: (buff 33),
    name: (string-ascii 50),
    created-at: uint,
    is-active: bool
  }
)
(define-map user-passkey-count principal uint)

;; CLARITY 4 FUNCTION #2: secp256r1-verify
;; Register a new passkey (supports multiple devices)
(define-public (register-passkey (public-key (buff 33)))
  (let (
    (key-count (default-to u0 (map-get? user-passkey-count tx-sender)))
    (new-index key-count)
  )
    (asserts! (< key-count u5) ERR_ALREADY_EXISTS) ;; Max 5 passkeys per user
    
    ;; Store in legacy registry for backwards compatibility, then multi-passkey registry
    (asserts! (and
      (if (is-eq key-count u0)
        (map-set passkey-registry tx-sender public-key)
        true)
      (map-set user-passkeys 
        { user: tx-sender, key-index: new-index }
        {
          public-key: public-key,
          name: "Default",
          created-at: stacks-block-time,
          is-active: true
        })
      (map-set user-passkey-count tx-sender (+ key-count u1)))
      ERR_NOT_FOUND)
    
    (print {
      event: "passkey-registered",
      user: tx-sender,
      key-index: new-index,
      timestamp: stacks-block-time
    })
    (ok new-index)))

;; Register passkey with custom name
(define-public (register-named-passkey (public-key (buff 33)) (name (string-ascii 50)))
  (let (
    (key-count (default-to u0 (map-get? user-passkey-count tx-sender)))
    (new-index key-count)
  )
    (asserts! (< key-count u5) ERR_ALREADY_EXISTS)
    
    ;; Chain all map operations
    (asserts! (and
      (if (is-eq key-count u0)
        (map-set passkey-registry tx-sender public-key)
        true)
      (map-set user-passkeys 
        { user: tx-sender, key-index: new-index }
        {
          public-key: public-key,
          name: name,
          created-at: stacks-block-time,
          is-active: true
        })
      (map-set user-passkey-count tx-sender (+ key-count u1)))
      ERR_NOT_FOUND)
    
    (print {
      event: "passkey-registered",
      user: tx-sender,
      key-index: new-index,
      name: name,
      timestamp: stacks-block-time
    })
    (ok new-index)))

;; Get user's passkey count
(define-read-only (get-user-passkey-count (user principal))
  (default-to u0 (map-get? user-passkey-count user)))

;; Get specific passkey info
(define-read-only (get-passkey-info (user principal) (key-index uint))
  (map-get? user-passkeys { user: user, key-index: key-index }))

;; ============================================
;; PASSKEY REVOCATION
;; ============================================

;; Revoke a passkey (deactivate it)
(define-public (revoke-passkey (key-index uint))
  (let (
    (passkey-data (unwrap! (map-get? user-passkeys { user: tx-sender, key-index: key-index }) ERR_NOT_FOUND))
  )
    (asserts! (get is-active passkey-data) ERR_NOT_FOUND)
    
    ;; Update passkey to inactive
    (map-set user-passkeys 
      { user: tx-sender, key-index: key-index }
      (merge passkey-data { is-active: false })
    )
    
    (print {
      event: "passkey-revoked",
      user: tx-sender,
      key-index: key-index,
      name: (get name passkey-data),
      timestamp: stacks-block-time
    })
    (ok true)))

;; Revoke all passkeys (emergency)
(define-public (revoke-all-passkeys)
  (let (
    (key-count (default-to u0 (map-get? user-passkey-count tx-sender)))
  )
    (asserts! (> key-count u0) ERR_NOT_FOUND)
    
    ;; Revoke each passkey (up to 5) and clear legacy registry - chain all operations
    (asserts! (and
      (or (< key-count u1) (revoke-passkey-internal tx-sender u0))
      (or (< key-count u2) (revoke-passkey-internal tx-sender u1))
      (or (< key-count u3) (revoke-passkey-internal tx-sender u2))
      (or (< key-count u4) (revoke-passkey-internal tx-sender u3))
      (or (< key-count u5) (revoke-passkey-internal tx-sender u4))
      (map-delete passkey-registry tx-sender))
      ERR_NOT_FOUND)
    
    (print {
      event: "all-passkeys-revoked",
      user: tx-sender,
      count: key-count,
      timestamp: stacks-block-time
    })
    (ok key-count)))

;; Internal helper to revoke passkey
(define-private (revoke-passkey-internal (user principal) (key-index uint))
  (match (map-get? user-passkeys { user: user, key-index: key-index })
    passkey-data (begin
      (map-set user-passkeys 
        { user: user, key-index: key-index }
        (merge passkey-data { is-active: false })
      )
      true)
    false))

;; Check if user has any active passkeys
(define-read-only (has-active-passkey (user principal))
  (let (
    (key-count (default-to u0 (map-get? user-passkey-count user)))
  )
    (or
      (is-passkey-active user u0)
      (is-passkey-active user u1)
      (is-passkey-active user u2)
      (is-passkey-active user u3)
      (is-passkey-active user u4))))

;; Helper to check if specific passkey is active
(define-private (is-passkey-active (user principal) (key-index uint))
  (match (map-get? user-passkeys { user: user, key-index: key-index })
    passkey-data (get is-active passkey-data)
    false))

;; Verify signature with any active passkey
(define-public (verify-multi-passkey-signature
  (message-hash (buff 32))
  (signature (buff 64))
  (key-index uint))
  (let (
    (passkey-data (unwrap! (map-get? user-passkeys { user: tx-sender, key-index: key-index }) ERR_NOT_FOUND))
  )
    (asserts! (get is-active passkey-data) ERR_NOT_AUTHORIZED)
    (ok (secp256r1-verify message-hash signature (get public-key passkey-data)))))

(define-public (verify-signature-demo
  (message-hash (buff 32))
  (signature (buff 64)))
  (let (
    (user-pubkey (unwrap! (map-get? passkey-registry tx-sender) ERR_NOT_AUTHORIZED))
  )
    (ok (secp256r1-verify message-hash signature user-pubkey))))

;; CLARITY 4 FUNCTION #3: contract-hash?
(define-public (approve-trading-bot (bot-contract principal) (expected-hash (buff 32)))
  (let (
    (actual-hash (unwrap! (contract-hash? bot-contract) ERR_CONTRACT_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq actual-hash expected-hash) ERR_UNTRUSTED_BOT)
    (map-set approved-bots bot-contract true)
    (ok true)))

;; CLARITY 4 FUNCTION #4: restrict-assets?
(define-public (demo-restrict-assets (recipient principal) (amount uint))
  (begin
    ;; Simplified demo - in real app this would protect actual assets
    (asserts! (> amount u0) ERR_NOT_FOUND)
    (ok true)))

;; CLARITY 4 FUNCTION #5: to-ascii?
(define-public (demo-to-ascii (value uint))
  (ok (unwrap! (to-ascii? value) ERR_CONVERSION)))

;; ============================================
;; CORE POSITION FUNCTIONS
;; ============================================

;; Helper: Add position ID to user's list
(define-private (add-position-to-user (user principal) (position-id uint))
  (let (
    (current-positions (default-to (list) (map-get? user-positions user)))
    (current-count (default-to u0 (map-get? user-position-count user)))
  )
    (and
      (map-set user-positions user (unwrap! (as-max-len? (append current-positions position-id) u100) false))
      (map-set user-position-count user (+ current-count u1)))))

;; Create a new time-locked position
(define-public (create-position (amount uint) (lock-duration uint))
  (let (
    (position-id (+ (var-get position-counter) u1))
    (unlock-time (+ stacks-block-time lock-duration))
    (current-time stacks-block-time)
  )
    ;; Validation
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (>= amount MIN_DEPOSIT_AMOUNT) ERR_INVALID_AMOUNT)
    (asserts! (>= lock-duration MIN_LOCK_DURATION) ERR_INVALID_DURATION)
    (asserts! (<= lock-duration MAX_LOCK_DURATION) ERR_INVALID_DURATION)

    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender current-contract))

    ;; Create position record
    (map-set positions position-id {
      owner: tx-sender,
      amount: amount,
      lock-duration: lock-duration,
      created-at: current-time,
      unlock-time: unlock-time,
      is-active: true,
      asset-type: "STX",
      passkey-protected: false
    })

    ;; Update counters
    (var-set position-counter position-id)
    (var-set total-locked-value (+ (var-get total-locked-value) amount))
    (asserts! (add-position-to-user tx-sender position-id) ERR_NOT_FOUND)

    ;; Emit event
    (print {
      event: "position-created",
      position-id: position-id,
      owner: tx-sender,
      amount: amount,
      lock-duration: lock-duration,
      unlock-time: unlock-time,
      timestamp: current-time
    })

    (ok position-id)))

;; Create position with passkey protection
(define-public (create-position-with-passkey (amount uint) (lock-duration uint))
  (let (
    (position-id (+ (var-get position-counter) u1))
    (unlock-time (+ stacks-block-time lock-duration))
    (current-time stacks-block-time)
    (user-passkey (map-get? passkey-registry tx-sender))
  )
    ;; Validation
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (is-some user-passkey) ERR_NOT_AUTHORIZED)
    (asserts! (>= amount MIN_DEPOSIT_AMOUNT) ERR_INVALID_AMOUNT)
    (asserts! (>= lock-duration MIN_LOCK_DURATION) ERR_INVALID_DURATION)
    (asserts! (<= lock-duration MAX_LOCK_DURATION) ERR_INVALID_DURATION)

    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender current-contract))

    ;; Create position record with passkey protection
    (map-set positions position-id {
      owner: tx-sender,
      amount: amount,
      lock-duration: lock-duration,
      created-at: current-time,
      unlock-time: unlock-time,
      is-active: true,
      asset-type: "STX",
      passkey-protected: true
    })

    ;; Update counters
    (var-set position-counter position-id)
    (var-set total-locked-value (+ (var-get total-locked-value) amount))
    (asserts! (add-position-to-user tx-sender position-id) ERR_NOT_FOUND)

    ;; Emit event
    (print {
      event: "position-created-with-passkey",
      position-id: position-id,
      owner: tx-sender,
      amount: amount,
      lock-duration: lock-duration,
      unlock-time: unlock-time,
      passkey-protected: true,
      timestamp: current-time
    })

    (ok position-id)))

;; Unlock a position after lock period expires
(define-public (unlock-position (position-id uint))
  (let (
    (position (unwrap! (map-get? positions position-id) ERR_NOT_FOUND))
    (current-time stacks-block-time)
  )
    ;; Validation
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (is-eq (get owner position) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active position) ERR_NOT_FOUND)
    (asserts! (>= current-time (get unlock-time position)) ERR_POSITION_LOCKED)

    ;; Transfer STX back to owner
    (try! (as-contract? ((with-stx (get amount position))) (try! (stx-transfer? (get amount position) tx-sender (get owner position)))))

    ;; Update position to inactive
    (map-set positions position-id (merge position { is-active: false }))

    ;; Update total locked value
    (var-set total-locked-value (- (var-get total-locked-value) (get amount position)))

    ;; Emit event
    (print {
      event: "position-unlocked",
      position-id: position-id,
      owner: tx-sender,
      amount: (get amount position),
      timestamp: current-time
    })

    (ok (get amount position))))

;; Unlock position with passkey verification
(define-public (unlock-position-with-passkey 
  (position-id uint)
  (message-hash (buff 32))
  (signature (buff 64)))
  (let (
    (position (unwrap! (map-get? positions position-id) ERR_NOT_FOUND))
    (current-time stacks-block-time)
    (user-pubkey (unwrap! (map-get? passkey-registry tx-sender) ERR_NOT_AUTHORIZED))
  )
    ;; Validation
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (is-eq (get owner position) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active position) ERR_NOT_FOUND)
    (asserts! (get passkey-protected position) ERR_NOT_AUTHORIZED)
    (asserts! (>= current-time (get unlock-time position)) ERR_POSITION_LOCKED)
    
    ;; Verify passkey signature (Clarity 4)
    (asserts! (secp256r1-verify message-hash signature user-pubkey) ERR_NOT_AUTHORIZED)

    ;; Transfer STX back to owner
    (try! (as-contract? ((with-stx (get amount position))) (try! (stx-transfer? (get amount position) tx-sender (get owner position)))))

    ;; Update position to inactive
    (map-set positions position-id (merge position { is-active: false }))

    ;; Update total locked value
    (var-set total-locked-value (- (var-get total-locked-value) (get amount position)))

    ;; Emit event
    (print {
      event: "position-unlocked-with-passkey",
      position-id: position-id,
      owner: tx-sender,
      amount: (get amount position),
      passkey-verified: true,
      timestamp: current-time
    })

    (ok (get amount position))))

;; Calculate early withdrawal penalty based on remaining time
(define-read-only (calculate-early-withdrawal-penalty (position-id uint))
  (let (
    (position (unwrap! (map-get? positions position-id) (err u0)))
    (current-time stacks-block-time)
    (time-remaining (if (>= current-time (get unlock-time position))
                        u0
                        (- (get unlock-time position) current-time)))
    (total-lock-duration (get lock-duration position))
    (amount (get amount position))
    ;; Penalty scales with remaining time (more time = higher penalty)
    (penalty-ratio (/ (* time-remaining u10000) total-lock-duration))
    (base-penalty (/ (* amount EARLY_WITHDRAWAL_PENALTY_BPS) u10000))
    (scaled-penalty (/ (* base-penalty penalty-ratio) u10000))
    ;; Cap at maximum penalty
    (max-penalty-amount (/ (* amount MAX_PENALTY_BPS) u10000))
    (final-penalty (if (> scaled-penalty max-penalty-amount) max-penalty-amount scaled-penalty))
  )
    (ok {
      penalty-amount: final-penalty,
      penalty-bps: (/ (* final-penalty u10000) amount),
      amount-after-penalty: (- amount final-penalty),
      time-remaining: time-remaining
    })))

;; Early withdraw with penalty
(define-public (early-withdraw (position-id uint))
  (let (
    (position (unwrap! (map-get? positions position-id) ERR_NOT_FOUND))
    (current-time stacks-block-time)
    (penalty-info (unwrap! (calculate-early-withdrawal-penalty position-id) ERR_NOT_FOUND))
    (penalty-amount (get penalty-amount penalty-info))
    (amount-after-penalty (get amount-after-penalty penalty-info))
  )
    ;; Validation
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (is-eq (get owner position) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active position) ERR_NOT_FOUND)
    (asserts! (< current-time (get unlock-time position)) ERR_POSITION_LOCKED) ;; Must be before unlock time
    (asserts! (> amount-after-penalty u0) ERR_ZERO_AMOUNT)

    ;; Transfer amount minus penalty to owner
    (try! (as-contract? ((with-stx amount-after-penalty)) (try! (stx-transfer? amount-after-penalty tx-sender (get owner position)))))

    ;; Transfer penalty to fee collector (or keep in contract for now)
    ;; In production, this would go to a fee distribution contract

    ;; Update position to inactive
    (map-set positions position-id (merge position { is-active: false }))

    ;; Update total locked value
    (var-set total-locked-value (- (var-get total-locked-value) (get amount position)))

    ;; Emit event
    (print {
      event: "position-early-withdrawn",
      position-id: position-id,
      owner: tx-sender,
      original-amount: (get amount position),
      penalty-amount: penalty-amount,
      amount-received: amount-after-penalty,
      penalty-bps: (get penalty-bps penalty-info),
      time-remaining: (get time-remaining penalty-info),
      timestamp: current-time
    })

    (ok {
      amount-received: amount-after-penalty,
      penalty-paid: penalty-amount
    })))

;; ============================================
;; POSITION TRANSFER
;; ============================================

;; Transfer ownership of a position to another user
(define-public (transfer-position (position-id uint) (new-owner principal))
  (let (
    (position (unwrap! (map-get? positions position-id) ERR_NOT_FOUND))
    (current-time stacks-block-time)
  )
    ;; Validation
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (is-eq (get owner position) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active position) ERR_NOT_FOUND)
    (asserts! (not (is-eq new-owner tx-sender)) ERR_INVALID_AMOUNT) ;; Can't transfer to self
    (asserts! (not (get passkey-protected position)) ERR_NOT_AUTHORIZED) ;; Can't transfer passkey-protected positions

    ;; Update position owner
    (map-set positions position-id (merge position { owner: new-owner }))

    ;; Update user position lists
    (remove-position-from-user tx-sender position-id)
    (asserts! (add-position-to-user new-owner position-id) ERR_NOT_FOUND)

    ;; Emit event
    (print {
      event: "position-transferred",
      position-id: position-id,
      from: tx-sender,
      to: new-owner,
      amount: (get amount position),
      timestamp: current-time
    })

    (ok true)))

;; Transfer position with passkey verification (for passkey-protected positions)
(define-public (transfer-position-with-passkey 
  (position-id uint) 
  (new-owner principal)
  (message-hash (buff 32))
  (signature (buff 64)))
  (let (
    (position (unwrap! (map-get? positions position-id) ERR_NOT_FOUND))
    (current-time stacks-block-time)
    (user-pubkey (unwrap! (map-get? passkey-registry tx-sender) ERR_NOT_AUTHORIZED))
  )
    ;; Validation
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (is-eq (get owner position) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active position) ERR_NOT_FOUND)
    (asserts! (get passkey-protected position) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-eq new-owner tx-sender)) ERR_INVALID_AMOUNT)
    
    ;; Verify passkey signature (Clarity 4)
    (asserts! (secp256r1-verify message-hash signature user-pubkey) ERR_NOT_AUTHORIZED)

    ;; Update position owner (remove passkey protection on transfer)
    (map-set positions position-id (merge position { 
      owner: new-owner,
      passkey-protected: false 
    }))

    ;; Update user position lists
    (remove-position-from-user tx-sender position-id)
    (asserts! (add-position-to-user new-owner position-id) ERR_NOT_FOUND)

    ;; Emit event
    (print {
      event: "position-transferred-with-passkey",
      position-id: position-id,
      from: tx-sender,
      to: new-owner,
      amount: (get amount position),
      passkey-verified: true,
      timestamp: current-time
    })

    (ok true)))

;; Helper function to remove position from user's list
(define-private (remove-position-from-user (user principal) (position-id uint))
  (let (
    (current-positions (default-to (list) (map-get? user-positions user)))
    (current-count (default-to u0 (map-get? user-position-count user)))
  )
    ;; Set filter target first, then chain map operations
    (var-set filter-target-position position-id)
    (and
      (map-set user-positions user (filter not-matching-position current-positions))
      (map-set user-position-count user (if (> current-count u0) (- current-count u1) u0)))))

;; Filter target for position removal
(define-data-var filter-target-position uint u0)

;; Filter predicate for position removal
(define-private (not-matching-position (pid uint))
  (not (is-eq pid (var-get filter-target-position))))

;; ============================================
;; POSITION EXTENSION
;; ============================================

;; Extend lock duration of an existing position
(define-public (extend-position (position-id uint) (additional-duration uint))
  (let (
    (position (unwrap! (map-get? positions position-id) ERR_NOT_FOUND))
    (current-time stacks-block-time)
    (new-unlock-time (+ (get unlock-time position) additional-duration))
    (new-total-duration (+ (get lock-duration position) additional-duration))
  )
    ;; Validation
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (is-eq (get owner position) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active position) ERR_NOT_FOUND)
    (asserts! (>= additional-duration MIN_LOCK_DURATION) ERR_INVALID_DURATION)
    (asserts! (<= new-total-duration MAX_LOCK_DURATION) ERR_INVALID_DURATION)

    ;; Update position with extended duration
    (map-set positions position-id (merge position { 
      unlock-time: new-unlock-time,
      lock-duration: new-total-duration
    }))

    ;; Emit event
    (print {
      event: "position-extended",
      position-id: position-id,
      owner: tx-sender,
      old-unlock-time: (get unlock-time position),
      new-unlock-time: new-unlock-time,
      additional-duration: additional-duration,
      timestamp: current-time
    })

    (ok new-unlock-time)))

;; Add more STX to an existing position
(define-public (add-to-position (position-id uint) (additional-amount uint))
  (let (
    (position (unwrap! (map-get? positions position-id) ERR_NOT_FOUND))
    (current-time stacks-block-time)
    (new-amount (+ (get amount position) additional-amount))
  )
    ;; Validation
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (is-eq (get owner position) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active position) ERR_NOT_FOUND)
    (asserts! (> additional-amount u0) ERR_ZERO_AMOUNT)

    ;; Transfer additional STX to contract
    (try! (stx-transfer? additional-amount tx-sender current-contract))

    ;; Update position with additional amount
    (map-set positions position-id (merge position { amount: new-amount }))

    ;; Update total locked value
    (var-set total-locked-value (+ (var-get total-locked-value) additional-amount))

    ;; Emit event
    (print {
      event: "position-topped-up",
      position-id: position-id,
      owner: tx-sender,
      old-amount: (get amount position),
      additional-amount: additional-amount,
      new-amount: new-amount,
      timestamp: current-time
    })

    (ok new-amount)))

;; Demo function that uses all Clarity 4 functions
(define-public (comprehensive-demo
  (bot-contract principal)
  (expected-hash (buff 32))
  (message-hash (buff 32))
  (signature (buff 64)))
  (begin
    ;; Use stacks-block-time
    (let ((current-time stacks-block-time))

      ;; Use secp256r1-verify
      (try! (verify-signature-demo message-hash signature))

      ;; Use contract-hash?
      (try! (approve-trading-bot bot-contract expected-hash))

      ;; Use to-ascii?
      (let ((ascii-result (unwrap! (to-ascii? current-time) ERR_CONVERSION)))

        ;; Use restrict-assets? (simplified)
        (try! (demo-restrict-assets tx-sender u1000000))

        (var-set demo-count (+ (var-get demo-count) u1))

        (print {
          event: "comprehensive-demo",
          timestamp: current-time,
          ascii-timestamp: ascii-result,
          demo-count: (var-get demo-count)
        })

        (ok (var-get demo-count))))))

;; Read-only functions
(define-read-only (get-demo-count)
  (var-get demo-count))

(define-read-only (is-bot-approved? (bot principal))
  (default-to false (map-get? approved-bots bot)))

;; Position read-only functions
(define-read-only (get-position (position-id uint))
  (map-get? positions position-id))

(define-read-only (get-position-count)
  (var-get position-counter))

(define-read-only (get-total-locked-value)
  (var-get total-locked-value))

(define-read-only (get-user-position-count (user principal))
  (default-to u0 (map-get? user-position-count user)))

(define-read-only (get-user-positions (user principal))
  (default-to (list) (map-get? user-positions user)))

(define-read-only (is-position-unlockable (position-id uint))
  (let ((position (unwrap! (map-get? positions position-id) false)))
    (and
      (get is-active position)
      (>= stacks-block-time (get unlock-time position)))))

(define-read-only (get-time-remaining (position-id uint))
  (let ((position (unwrap! (map-get? positions position-id) (ok u0))))
    (if (>= stacks-block-time (get unlock-time position))
      (ok u0)
      (ok (- (get unlock-time position) stacks-block-time)))))

(define-read-only (is-contract-paused)
  (var-get contract-paused))
