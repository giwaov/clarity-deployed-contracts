;; rewards-distributor.clar
;; Advanced rewards distribution system with merkle proofs and batch claims
;; Supports multiple reward epochs and token types

;; ============================================================================
;; Constants
;; ============================================================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-EPOCH-NOT-FOUND (err u402))
(define-constant ERR-ALREADY-CLAIMED (err u403))
(define-constant ERR-INVALID-PROOF (err u404))
(define-constant ERR-EPOCH-NOT-ACTIVE (err u405))
(define-constant ERR-INSUFFICIENT-BALANCE (err u406))
(define-constant ERR-INVALID-AMOUNT (err u407))
(define-constant ERR-EPOCH-EXPIRED (err u408))
(define-constant ERR-MAX-EPOCHS-REACHED (err u409))
(define-constant ERR-INVALID-ROOT (err u410))

;; Configuration
(define-constant MAX-EPOCHS u1000)
(define-constant EPOCH-DURATION u4320)  ;; ~30 days in blocks
(define-constant CLAIM-WINDOW u8640)    ;; ~60 days to claim

;; ============================================================================
;; Data Variables
;; ============================================================================

(define-data-var current-epoch uint u0)
(define-data-var total-distributed uint u0)
(define-data-var treasury-balance uint u0)
(define-data-var distribution-paused bool false)

;; ============================================================================
;; Data Maps
;; ============================================================================

;; Epoch information
(define-map epochs uint
  {
    merkle-root: (buff 32),
    total-amount: uint,
    claimed-amount: uint,
    start-height: uint,
    end-height: uint,
    claim-deadline: uint,
    token-type: (string-ascii 32),
    is-active: bool,
    created-by: principal
  })

;; User claims per epoch
(define-map user-claims
  { epoch-id: uint, user: principal }
  { claimed: bool, amount: uint, claim-height: uint })

;; Aggregated user stats
(define-map user-stats principal
  {
    total-claimed: uint,
    epochs-claimed: uint,
    last-claim-height: uint,
    first-claim-height: uint
  })

;; Whitelist for reward distributors
(define-map distributors principal bool)

;; ============================================================================
;; Read-Only Functions
;; ============================================================================

(define-read-only (get-epoch (epoch-id uint))
  (map-get? epochs epoch-id))

(define-read-only (get-current-epoch)
  (var-get current-epoch))

(define-read-only (get-user-claim (epoch-id uint) (user principal))
  (map-get? user-claims { epoch-id: epoch-id, user: user }))

(define-read-only (has-claimed (epoch-id uint) (user principal))
  (match (map-get? user-claims { epoch-id: epoch-id, user: user })
    claim (get claimed claim)
    false))

(define-read-only (get-user-stats (user principal))
  (default-to
    { total-claimed: u0, epochs-claimed: u0, last-claim-height: u0, first-claim-height: u0 }
    (map-get? user-stats user)))

(define-read-only (is-distributor (account principal))
  (default-to false (map-get? distributors account)))

(define-read-only (get-epoch-status (epoch-id uint))
  (match (map-get? epochs epoch-id)
    epoch
      {
        exists: true,
        is-active: (get is-active epoch),
        is-expired: (> stacks-block-height (get claim-deadline epoch)),
        remaining-amount: (- (get total-amount epoch) (get claimed-amount epoch)),
        claim-rate: (if (is-eq (get total-amount epoch) u0)
                       u0
                       (/ (* (get claimed-amount epoch) u10000) (get total-amount epoch)))
      }
    { exists: false, is-active: false, is-expired: false, remaining-amount: u0, claim-rate: u0 }))

(define-read-only (get-claimable-epochs (user principal))
  ;; Returns list of epoch IDs user can claim from
  ;; Note: This is a simplified version - full implementation would iterate through epochs
  (list (var-get current-epoch)))

(define-read-only (get-treasury-info)
  {
    balance: (var-get treasury-balance),
    total-distributed: (var-get total-distributed),
    active-epochs: (var-get current-epoch),
    is-paused: (var-get distribution-paused)
  })

;; ============================================================================
;; Merkle Proof Verification
;; ============================================================================

;; Verify merkle proof for a claim
(define-read-only (verify-merkle-proof 
    (leaf (buff 32))
    (proof (list 20 (buff 32)))
    (root (buff 32)))
  (is-eq root (fold hash-pair proof leaf)))

;; Hash pair helper for merkle tree - compare buffers by first byte for ordering
(define-private (hash-pair (proof-element (buff 32)) (current-hash (buff 32)))
  (let (
    (current-first (element-at? current-hash u0))
    (proof-first (element-at? proof-element u0))
  )
    (if (is-some current-first)
      (if (is-some proof-first)
        (if (< (buff-to-uint-be (unwrap-panic current-first)) (buff-to-uint-be (unwrap-panic proof-first)))
          (keccak256 (concat current-hash proof-element))
          (keccak256 (concat proof-element current-hash)))
        (keccak256 (concat current-hash proof-element)))
      (keccak256 (concat current-hash proof-element)))))

;; Create leaf hash from claim data
(define-read-only (create-claim-leaf (user principal) (amount uint) (epoch-id uint))
  (keccak256 (concat 
    (concat (unwrap-panic (to-consensus-buff? user)) (unwrap-panic (to-consensus-buff? amount)))
    (unwrap-panic (to-consensus-buff? epoch-id)))))

;; ============================================================================
;; Distributor Management (Owner Only)
;; ============================================================================

(define-public (add-distributor (distributor principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set distributors distributor true)
    (ok true)))

(define-public (remove-distributor (distributor principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-delete distributors distributor)
    (ok true)))

;; ============================================================================
;; Epoch Management
;; ============================================================================

;; Create new reward epoch
(define-public (create-epoch 
    (merkle-root (buff 32))
    (total-amount uint)
    (token-type (string-ascii 32)))
  (let
    (
      (epoch-id (+ (var-get current-epoch) u1))
      (start-height stacks-block-height)
      (end-height (+ stacks-block-height EPOCH-DURATION))
      (claim-deadline (+ stacks-block-height CLAIM-WINDOW))
    )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-distributor tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (< epoch-id MAX-EPOCHS) ERR-MAX-EPOCHS-REACHED)
    (asserts! (> total-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> (len merkle-root) u0) ERR-INVALID-ROOT)
    
    ;; Create epoch
    (map-set epochs epoch-id
      {
        merkle-root: merkle-root,
        total-amount: total-amount,
        claimed-amount: u0,
        start-height: start-height,
        end-height: end-height,
        claim-deadline: claim-deadline,
        token-type: token-type,
        is-active: true,
        created-by: tx-sender
      })
    
    (var-set current-epoch epoch-id)
    
    (print {
      event: "epoch-created",
      epoch-id: epoch-id,
      total-amount: total-amount,
      merkle-root: merkle-root,
      start-height: start-height,
      claim-deadline: claim-deadline
    })
    
    (ok epoch-id)))

;; Deactivate epoch (stops new claims)
(define-public (deactivate-epoch (epoch-id uint))
  (let
    (
      (epoch (unwrap! (map-get? epochs epoch-id) ERR-EPOCH-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-eq tx-sender (get created-by epoch))) ERR-NOT-AUTHORIZED)
    
    (map-set epochs epoch-id (merge epoch { is-active: false }))
    
    (print { event: "epoch-deactivated", epoch-id: epoch-id })
    (ok true)))

;; ============================================================================
;; Claim Functions
;; ============================================================================

;; Claim rewards with merkle proof
(define-public (claim-rewards 
    (epoch-id uint)
    (amount uint)
    (proof (list 20 (buff 32))))
  (let
    (
      (epoch (unwrap! (map-get? epochs epoch-id) ERR-EPOCH-NOT-FOUND))
      (leaf (create-claim-leaf tx-sender amount epoch-id))
      (user-current-stats (get-user-stats tx-sender))
    )
    ;; Validations
    (asserts! (get is-active epoch) ERR-EPOCH-NOT-ACTIVE)
    (asserts! (<= stacks-block-height (get claim-deadline epoch)) ERR-EPOCH-EXPIRED)
    (asserts! (not (has-claimed epoch-id tx-sender)) ERR-ALREADY-CLAIMED)
    (asserts! (verify-merkle-proof leaf proof (get merkle-root epoch)) ERR-INVALID-PROOF)
    (asserts! (>= (- (get total-amount epoch) (get claimed-amount epoch)) amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Record claim
    (map-set user-claims
      { epoch-id: epoch-id, user: tx-sender }
      { claimed: true, amount: amount, claim-height: stacks-block-height })
    
    ;; Update epoch claimed amount
    (map-set epochs epoch-id 
      (merge epoch { claimed-amount: (+ (get claimed-amount epoch) amount) }))
    
    ;; Update user stats
    (map-set user-stats tx-sender
      {
        total-claimed: (+ (get total-claimed user-current-stats) amount),
        epochs-claimed: (+ (get epochs-claimed user-current-stats) u1),
        last-claim-height: stacks-block-height,
        first-claim-height: (if (is-eq (get first-claim-height user-current-stats) u0)
                               stacks-block-height
                               (get first-claim-height user-current-stats))
      })
    
    ;; Update totals
    (var-set total-distributed (+ (var-get total-distributed) amount))
    
    (print {
      event: "rewards-claimed",
      epoch-id: epoch-id,
      user: tx-sender,
      amount: amount,
      block: stacks-block-height
    })
    
    ;; Transfer rewards (in production, this would call stx-transfer? or token transfer)
    (ok amount)))

;; Batch claim from multiple epochs
(define-public (batch-claim 
    (claims (list 10 { epoch-id: uint, amount: uint, proof: (list 20 (buff 32)) })))
  (begin
    (asserts! (not (var-get distribution-paused)) ERR-NOT-AUTHORIZED)
    (ok (fold batch-claim-helper claims u0))))

(define-private (batch-claim-helper 
    (claim { epoch-id: uint, amount: uint, proof: (list 20 (buff 32)) })
    (total-claimed uint))
  (match (claim-single-reward (get epoch-id claim) (get amount claim) (get proof claim))
    amount (+ total-claimed amount)
    err total-claimed))

(define-private (claim-single-reward (epoch-id uint) (amount uint) (proof (list 20 (buff 32))))
  (let
    (
      (epoch (unwrap! (map-get? epochs epoch-id) (err u0)))
      (leaf (create-claim-leaf tx-sender amount epoch-id))
    )
    (if (and 
          (get is-active epoch)
          (<= stacks-block-height (get claim-deadline epoch))
          (not (has-claimed epoch-id tx-sender))
          (verify-merkle-proof leaf proof (get merkle-root epoch)))
      (begin
        (map-set user-claims
          { epoch-id: epoch-id, user: tx-sender }
          { claimed: true, amount: amount, claim-height: stacks-block-height })
        (map-set epochs epoch-id 
          (merge epoch { claimed-amount: (+ (get claimed-amount epoch) amount) }))
        (ok amount))
      (err u0))))

;; ============================================================================
;; Treasury Management
;; ============================================================================

;; Deposit to treasury
(define-public (deposit-to-treasury (amount uint))
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    ;; In production: (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set treasury-balance (+ (var-get treasury-balance) amount))
    (print { event: "treasury-deposit", amount: amount, depositor: tx-sender })
    (ok (var-get treasury-balance))))

;; Withdraw unclaimed rewards after epoch expiry
(define-public (withdraw-expired-rewards (epoch-id uint))
  (let
    (
      (epoch (unwrap! (map-get? epochs epoch-id) ERR-EPOCH-NOT-FOUND))
      (unclaimed (- (get total-amount epoch) (get claimed-amount epoch)))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> stacks-block-height (get claim-deadline epoch)) ERR-EPOCH-NOT-ACTIVE)
    (asserts! (> unclaimed u0) ERR-INVALID-AMOUNT)
    
    ;; Mark epoch as fully claimed/expired
    (map-set epochs epoch-id 
      (merge epoch { 
        is-active: false,
        claimed-amount: (get total-amount epoch)
      }))
    
    (print { 
      event: "expired-rewards-withdrawn",
      epoch-id: epoch-id,
      amount: unclaimed 
    })
    
    (ok unclaimed)))

;; ============================================================================
;; Admin Functions
;; ============================================================================

;; Pause/unpause distribution
(define-public (set-distribution-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set distribution-paused paused)
    (print { event: "distribution-paused", paused: paused })
    (ok paused)))

;; Emergency withdraw (owner only)
(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= amount (var-get treasury-balance)) ERR-INSUFFICIENT-BALANCE)
    (var-set treasury-balance (- (var-get treasury-balance) amount))
    ;; In production: (try! (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER)))
    (print { event: "emergency-withdrawal", amount: amount })
    (ok amount)))
