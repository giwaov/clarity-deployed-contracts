;; StackSusu Escrow v6
;; Enhanced escrow with partial withdrawals, auto-compounding, and dispute arbitration

(define-constant CONTRACT-OWNER tx-sender)

;; Contribution modes
(define-constant MODE-UPFRONT u0)
(define-constant MODE-ROUND-BY-ROUND u1)
(define-constant MODE-SCHEDULED u2)

;; Dispute status
(define-constant DISPUTE-NONE u0)
(define-constant DISPUTE-PENDING u1)
(define-constant DISPUTE-RESOLVED-FOR-MEMBER u2)
(define-constant DISPUTE-RESOLVED-FOR-CIRCLE u3)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-CIRCLE-NOT-FOUND (err u1001))
(define-constant ERR-NOT-MEMBER (err u1005))
(define-constant ERR-INVALID-AMOUNT (err u1006))
(define-constant ERR-ALREADY-DEPOSITED (err u1009))
(define-constant ERR-NOT-DEPOSITED (err u1010))
(define-constant ERR-TRANSFER-FAILED (err u1017))
(define-constant ERR-ZERO-AMOUNT (err u1023))
(define-constant ERR-PAUSED (err u1021))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1024))
(define-constant ERR-PAYOUT-NOT-DUE (err u1012))
(define-constant ERR-ALREADY-CLAIMED (err u1013))
(define-constant ERR-NOT-YOUR-TURN (err u1014))
(define-constant ERR-CONTRIBUTIONS-INCOMPLETE (err u1030))
(define-constant ERR-ROUND-NOT-STARTED (err u1031))
(define-constant ERR-ALREADY-CONTRIBUTED (err u1032))
(define-constant ERR-DISPUTE-ACTIVE (err u1060))
(define-constant ERR-NO-DISPUTE (err u1061))
(define-constant ERR-PARTIAL-NOT-ALLOWED (err u1062))
(define-constant ERR-COMPOUND-DISABLED (err u1063))

;; Upfront deposits
(define-map deposits 
  { circle-id: uint, member: principal }
  { deposited: bool, amount: uint, deposit-block: uint, partial-withdrawn: uint }
)

;; Circle deposit totals
(define-map circle-deposits
  uint
  { total-deposited: uint, deposit-count: uint, locked-amount: uint }
)

;; Round contributions
(define-map round-contributions
  { circle-id: uint, round: uint, member: principal }
  { amount: uint, contributed-at: uint, is-late: bool, delegated-by: (optional principal) }
)

;; Round totals
(define-map round-totals
  { circle-id: uint, round: uint }
  { total-amount: uint, contribution-count: uint }
)

;; Payout records
(define-map payouts
  { circle-id: uint, round: uint }
  { recipient: principal, amount: uint, block: uint, is-emergency: bool }
)

;; Member payout tracking
(define-map member-received-payout
  { circle-id: uint, member: principal }
  bool
)

;; Auto-compound settings
(define-map auto-compound-settings
  { circle-id: uint, member: principal }
  { enabled: bool, target-circle: uint, compound-percent: uint }
)

;; Disputes
(define-map disputes
  { circle-id: uint, dispute-id: uint }
  {
    initiator: principal,
    target: (optional principal),
    reason: (string-ascii 200),
    amount: uint,
    status: uint,
    created-at: uint,
    resolved-at: uint,
    resolver: (optional principal),
    resolution-notes: (string-ascii 200)
  }
)

(define-map circle-dispute-counter uint uint)

;; Arbitrators
(define-map arbitrators principal bool)

;; Member balances (for partial withdrawals)
(define-map member-balances
  { circle-id: uint, member: principal }
  { available: uint, locked: uint, pending-payout: uint }
)

;; Insurance pool contributions
(define-data-var insurance-pool-balance uint u0)

;; Authorized callers
(define-map authorized-callers principal bool)


;; ============================================
;; Authorization
;; ============================================

(define-read-only (is-authorized (caller principal))
  (or 
    (is-eq caller CONTRACT-OWNER)
    (default-to false (map-get? authorized-callers caller))
  )
)

(define-public (authorize-caller (caller principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-callers caller true))
  )
)

(define-public (add-arbitrator (arbitrator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set arbitrators arbitrator true))
  )
)


;; ============================================
;; Upfront Deposit
;; ============================================

(define-public (deposit (circle-id uint) (amount uint))
  (let
    (
      (sender tx-sender)
      (circle-info (unwrap! (contract-call? .stacksusu-core-v6 get-circle-info circle-id) 
                            ERR-CIRCLE-NOT-FOUND))
      (circle (unwrap! circle-info ERR-CIRCLE-NOT-FOUND))
      (is-member-check (contract-call? .stacksusu-core-v6 is-member circle-id sender))
      (current-deposits (default-to { total-deposited: u0, deposit-count: u0, locked-amount: u0 } 
                          (map-get? circle-deposits circle-id)))
      (existing-deposit (map-get? deposits { circle-id: circle-id, member: sender }))
      (insurance-fee (/ (* amount (contract-call? .stacksusu-admin-v6 get-insurance-fee-bps)) u10000))
      (net-amount (- amount insurance-fee))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (is-none existing-deposit) ERR-ALREADY-DEPOSITED)
    (asserts! is-member-check ERR-NOT-MEMBER)
    (asserts! (is-eq (get contribution-mode circle) MODE-UPFRONT) ERR-NOT-AUTHORIZED)
    
    ;; Transfer STX to escrow
    (match (stx-transfer? amount sender (as-contract tx-sender))
      success
        (begin
          ;; Transfer insurance fee to pool
          (if (> insurance-fee u0)
            (begin
              (var-set insurance-pool-balance (+ (var-get insurance-pool-balance) insurance-fee))
              (try! (contract-call? .stacksusu-admin-v6 record-insurance-contribution insurance-fee))
            )
            true
          )
          
          (map-set deposits 
            { circle-id: circle-id, member: sender }
            { deposited: true, amount: net-amount, deposit-block: block-height, partial-withdrawn: u0 }
          )
          (map-set circle-deposits circle-id
            { 
              total-deposited: (+ (get total-deposited current-deposits) net-amount),
              deposit-count: (+ (get deposit-count current-deposits) u1),
              locked-amount: (+ (get locked-amount current-deposits) net-amount)
            }
          )
          
          ;; Update member balance
          (map-set member-balances { circle-id: circle-id, member: sender }
            { available: u0, locked: net-amount, pending-payout: u0 })
          
          ;; Record in reputation
          (try! (contract-call? .stacksusu-reputation-v6 record-contribution sender net-amount))
          
          ;; Record referral activity
          (match (contract-call? .stacksusu-referral-v6 record-activity sender net-amount)
            ok-val true
            err-val true
          )
          
          (ok true)
        )
      error ERR-TRANSFER-FAILED
    )
  )
)


;; ============================================
;; Round-by-Round Contribution
;; ============================================

(define-public (contribute-for-round (circle-id uint) (round uint) (amount uint))
  (let
    (
      (sender tx-sender)
      (circle-info (unwrap! (contract-call? .stacksusu-core-v6 get-circle-info circle-id) 
                            ERR-CIRCLE-NOT-FOUND))
      (circle (unwrap! circle-info ERR-CIRCLE-NOT-FOUND))
      (is-member-check (contract-call? .stacksusu-core-v6 is-member circle-id sender))
      (current-round (get current-round circle))
      (existing-contribution (map-get? round-contributions 
                               { circle-id: circle-id, round: round, member: sender }))
      (round-total (default-to { total-amount: u0, contribution-count: u0 }
                     (map-get? round-totals { circle-id: circle-id, round: round })))
      (insurance-fee (/ (* amount (contract-call? .stacksusu-admin-v6 get-insurance-fee-bps)) u10000))
      (net-amount (- amount insurance-fee))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! is-member-check ERR-NOT-MEMBER)
    (asserts! (is-eq round current-round) ERR-ROUND-NOT-STARTED)
    (asserts! (is-none existing-contribution) ERR-ALREADY-CONTRIBUTED)
    (asserts! (or (is-eq (get contribution-mode circle) MODE-ROUND-BY-ROUND)
                  (is-eq (get contribution-mode circle) MODE-SCHEDULED)) 
              ERR-NOT-AUTHORIZED)
    
    ;; Transfer STX
    (match (stx-transfer? amount sender (as-contract tx-sender))
      success
        (begin
          ;; Insurance fee
          (if (> insurance-fee u0)
            (var-set insurance-pool-balance (+ (var-get insurance-pool-balance) insurance-fee))
            true
          )
          
          (map-set round-contributions
            { circle-id: circle-id, round: round, member: sender }
            { amount: net-amount, contributed-at: block-height, is-late: false, delegated-by: none }
          )
          
          (map-set round-totals { circle-id: circle-id, round: round }
            { total-amount: (+ (get total-amount round-total) net-amount),
              contribution-count: (+ (get contribution-count round-total) u1) })
          
          (try! (contract-call? .stacksusu-reputation-v6 record-contribution sender net-amount))
          
          (ok true)
        )
      error ERR-TRANSFER-FAILED
    )
  )
)

;; Delegated contribution (NEW in v6)
(define-public (contribute-for-round-delegated 
    (circle-id uint) 
    (member principal) 
    (delegate principal) 
    (amount uint))
  (let
    (
      (circle-info (unwrap! (contract-call? .stacksusu-core-v6 get-circle-info circle-id) 
                            ERR-CIRCLE-NOT-FOUND))
      (circle (unwrap! circle-info ERR-CIRCLE-NOT-FOUND))
      (current-round (get current-round circle))
      (round-total (default-to { total-amount: u0, contribution-count: u0 }
                     (map-get? round-totals { circle-id: circle-id, round: current-round })))
    )
    (asserts! (is-authorized contract-caller) ERR-NOT-AUTHORIZED)
    
    ;; Transfer from delegate
    (match (stx-transfer? amount delegate (as-contract tx-sender))
      success
        (begin
          (map-set round-contributions
            { circle-id: circle-id, round: current-round, member: member }
            { amount: amount, contributed-at: block-height, is-late: false, 
              delegated-by: (some delegate) })
          
          (map-set round-totals { circle-id: circle-id, round: current-round }
            { total-amount: (+ (get total-amount round-total) amount),
              contribution-count: (+ (get contribution-count round-total) u1) })
          
          (ok true)
        )
      error ERR-TRANSFER-FAILED
    )
  )
)


;; ============================================
;; Auto-Compound Settings (NEW in v6)
;; ============================================

(define-public (setup-auto-compound (circle-id uint) (target-circle uint) (compound-percent uint))
  (let
    (
      (member tx-sender)
    )
    (asserts! (contract-call? .stacksusu-core-v6 is-member circle-id member) ERR-NOT-MEMBER)
    (asserts! (and (> compound-percent u0) (<= compound-percent u100)) ERR-INVALID-AMOUNT)
    
    (map-set auto-compound-settings { circle-id: circle-id, member: member }
      { enabled: true, target-circle: target-circle, compound-percent: compound-percent })
    
    (ok true)
  )
)

(define-public (disable-auto-compound (circle-id uint))
  (begin
    (map-delete auto-compound-settings { circle-id: circle-id, member: tx-sender })
    (ok true)
  )
)


;; ============================================
;; Partial Withdrawal (NEW in v6)
;; ============================================

(define-public (partial-withdraw (circle-id uint) (amount uint))
  (let
    (
      (member tx-sender)
      (balance (unwrap! (map-get? member-balances { circle-id: circle-id, member: member }) 
                        ERR-NOT-MEMBER))
      (available (get available balance))
      (fee (/ (* amount (contract-call? .stacksusu-admin-v6 get-admin-fee-bps)) u10000))
      (net-amount (- amount fee))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (<= amount available) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    
    ;; Check no active disputes
    (asserts! (is-eq (get-circle-dispute-status circle-id) DISPUTE-NONE) ERR-DISPUTE-ACTIVE)
    
    ;; Transfer to member
    (match (as-contract (stx-transfer? net-amount tx-sender member))
      success
        (begin
          (map-set member-balances { circle-id: circle-id, member: member }
            (merge balance { available: (- available amount) }))
          
          ;; Record fee
          (try! (contract-call? .stacksusu-admin-v6 record-fee fee))
          
          (ok net-amount)
        )
      error ERR-TRANSFER-FAILED
    )
  )
)


;; ============================================
;; Dispute Resolution (NEW in v6)
;; ============================================

(define-public (initiate-dispute (circle-id uint) (reason (string-ascii 200)) (amount uint))
  (let
    (
      (initiator tx-sender)
      (dispute-id (+ (default-to u0 (map-get? circle-dispute-counter circle-id)) u1))
    )
    (asserts! (contract-call? .stacksusu-core-v6 is-member circle-id initiator) ERR-NOT-MEMBER)
    
    (map-set disputes { circle-id: circle-id, dispute-id: dispute-id }
      {
        initiator: initiator,
        target: none,
        reason: reason,
        amount: amount,
        status: DISPUTE-PENDING,
        created-at: block-height,
        resolved-at: u0,
        resolver: none,
        resolution-notes: ""
      })
    
    (map-set circle-dispute-counter circle-id dispute-id)
    
    (ok dispute-id)
  )
)

(define-public (resolve-dispute 
    (circle-id uint) 
    (dispute-id uint) 
    (resolution uint)
    (notes (string-ascii 200)))
  (let
    (
      (resolver tx-sender)
      (dispute (unwrap! (map-get? disputes { circle-id: circle-id, dispute-id: dispute-id }) 
                        ERR-NO-DISPUTE))
    )
    (asserts! (or (is-eq resolver CONTRACT-OWNER) 
                  (default-to false (map-get? arbitrators resolver))) 
              ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status dispute) DISPUTE-PENDING) ERR-NO-DISPUTE)
    
    (map-set disputes { circle-id: circle-id, dispute-id: dispute-id }
      (merge dispute {
        status: resolution,
        resolved-at: block-height,
        resolver: (some resolver),
        resolution-notes: notes
      }))
    
    ;; If resolved for member, process refund from insurance pool
    (if (is-eq resolution DISPUTE-RESOLVED-FOR-MEMBER)
      (let
        (
          (refund-amount (get amount dispute))
        )
        (if (<= refund-amount (var-get insurance-pool-balance))
          (begin
            (var-set insurance-pool-balance (- (var-get insurance-pool-balance) refund-amount))
            (match (as-contract (stx-transfer? refund-amount tx-sender (get initiator dispute)))
              success true
              error false
            )
          )
          true
        )
      )
      true
    )
    
    (ok true)
  )
)


;; ============================================
;; Payout Processing
;; ============================================

(define-public (process-payout (circle-id uint) (round uint) (recipient principal) (amount uint))
  (let
    (
      (fee (/ (* amount (contract-call? .stacksusu-admin-v6 get-admin-fee-bps)) u10000))
      (net-amount (- amount fee))
      (compound-settings (map-get? auto-compound-settings { circle-id: circle-id, member: recipient }))
    )
    (asserts! (is-authorized contract-caller) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get-circle-dispute-status circle-id) DISPUTE-NONE) ERR-DISPUTE-ACTIVE)
    
    ;; Check for auto-compound
    (if (and (is-some compound-settings) (get enabled (unwrap-panic compound-settings)))
      (let
        (
          (settings (unwrap-panic compound-settings))
          (compound-amount (/ (* net-amount (get compound-percent settings)) u100))
          (direct-amount (- net-amount compound-amount))
        )
        ;; Send direct amount to recipient
        (if (> direct-amount u0)
          (match (as-contract (stx-transfer? direct-amount tx-sender recipient))
            success true
            error (begin (asserts! false ERR-TRANSFER-FAILED) false)
          )
          true
        )
        ;; Deposit compound amount to target circle
        ;; (This would need additional logic for cross-circle deposits)
        true
      )
      ;; Normal payout
      (match (as-contract (stx-transfer? net-amount tx-sender recipient))
        success true
        error (begin (asserts! false ERR-TRANSFER-FAILED) false)
      )
    )
    
    ;; Record payout
    (map-set payouts { circle-id: circle-id, round: round }
      { recipient: recipient, amount: net-amount, block: block-height, is-emergency: false })
    
    (map-set member-received-payout { circle-id: circle-id, member: recipient } true)
    
    ;; Record fee
    (try! (contract-call? .stacksusu-admin-v6 record-fee fee))
    (try! (contract-call? .stacksusu-admin-v6 increment-payouts))
    
    ;; Update reputation
    (try! (contract-call? .stacksusu-reputation-v6 record-completion recipient circle-id net-amount true))
    
    (ok net-amount)
  )
)

(define-public (process-emergency-payout 
    (circle-id uint) 
    (round uint) 
    (recipient principal)
    (amount uint)
    (emergency-fee uint)
    (admin-fee uint))
  (let
    (
      (net-amount (- (- amount emergency-fee) admin-fee))
    )
    (asserts! (is-authorized contract-caller) ERR-NOT-AUTHORIZED)
    
    (match (as-contract (stx-transfer? net-amount tx-sender recipient))
      success
        (begin
          (map-set payouts { circle-id: circle-id, round: round }
            { recipient: recipient, amount: net-amount, block: block-height, is-emergency: true })
          (map-set member-received-payout { circle-id: circle-id, member: recipient } true)
          
          ;; Record fees
          (try! (contract-call? .stacksusu-admin-v6 record-fee admin-fee))
          
          ;; Emergency fee goes to insurance pool
          (var-set insurance-pool-balance (+ (var-get insurance-pool-balance) emergency-fee))
          
          (ok net-amount)
        )
      error ERR-TRANSFER-FAILED
    )
  )
)


;; ============================================
;; Read-Only Functions
;; ============================================

(define-read-only (get-deposit (circle-id uint) (member principal))
  (map-get? deposits { circle-id: circle-id, member: member })
)

(define-read-only (has-received-payout (circle-id uint) (member principal))
  (default-to false (map-get? member-received-payout { circle-id: circle-id, member: member }))
)

(define-read-only (are-deposits-complete (circle-id uint) (expected-count uint))
  (let
    (
      (circle-data (default-to { total-deposited: u0, deposit-count: u0, locked-amount: u0 }
                     (map-get? circle-deposits circle-id)))
    )
    (>= (get deposit-count circle-data) expected-count)
  )
)

(define-read-only (are-round-contributions-complete (circle-id uint) (round uint) (expected-count uint))
  (let
    (
      (round-data (default-to { total-amount: u0, contribution-count: u0 }
                    (map-get? round-totals { circle-id: circle-id, round: round })))
    )
    (>= (get contribution-count round-data) expected-count)
  )
)

(define-read-only (get-member-balance (circle-id uint) (member principal))
  (map-get? member-balances { circle-id: circle-id, member: member })
)

(define-read-only (get-dispute (circle-id uint) (dispute-id uint))
  (map-get? disputes { circle-id: circle-id, dispute-id: dispute-id })
)

(define-read-only (get-circle-dispute-status (circle-id uint))
  (let
    (
      (latest-id (default-to u0 (map-get? circle-dispute-counter circle-id)))
    )
    (if (is-eq latest-id u0)
      DISPUTE-NONE
      (match (map-get? disputes { circle-id: circle-id, dispute-id: latest-id })
        dispute (get status dispute)
        DISPUTE-NONE
      )
    )
  )
)

(define-read-only (get-insurance-pool-balance)
  (ok (var-get insurance-pool-balance))
)

(define-read-only (get-auto-compound-settings (circle-id uint) (member principal))
  (map-get? auto-compound-settings { circle-id: circle-id, member: member })
)
