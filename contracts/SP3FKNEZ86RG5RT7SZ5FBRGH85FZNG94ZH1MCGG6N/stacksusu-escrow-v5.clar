;; StackSusu Escrow v5
;; Enhanced escrow with round-by-round contributions

(define-constant CONTRACT-OWNER tx-sender)

;; Contribution modes
(define-constant MODE-UPFRONT u0)
(define-constant MODE-ROUND-BY-ROUND u1)

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

;; Upfront deposits (v4 compatibility)
(define-map deposits 
  { circle-id: uint, member: principal }
  { deposited: bool, amount: uint, deposit-block: uint }
)

;; Circle deposit totals (for upfront mode)
(define-map circle-deposits
  uint
  { total-deposited: uint, deposit-count: uint }
)

;; Round contributions (for round-by-round mode)
(define-map round-contributions
  { circle-id: uint, round: uint, member: principal }
  { amount: uint, contributed-at: uint, is-late: bool }
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

(define-public (revoke-caller (caller principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-callers caller))
  )
)


;; ============================================
;; Upfront Deposit (v4 compatible)
;; ============================================

(define-public (deposit (circle-id uint) (amount uint))
  (let
    (
      (sender tx-sender)
      (circle-info (unwrap! (contract-call? .stacksusu-core-v5 get-circle-info circle-id) 
                            ERR-CIRCLE-NOT-FOUND))
      (circle (unwrap! circle-info ERR-CIRCLE-NOT-FOUND))
      (is-member-check (contract-call? .stacksusu-core-v5 is-member circle-id sender))
      (current-deposits (default-to { total-deposited: u0, deposit-count: u0 } 
                          (map-get? circle-deposits circle-id)))
      (existing-deposit (map-get? deposits { circle-id: circle-id, member: sender }))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v5 is-paused)) ERR-PAUSED)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (is-none existing-deposit) ERR-ALREADY-DEPOSITED)
    (asserts! is-member-check ERR-NOT-MEMBER)
    (asserts! (is-eq (get contribution-mode circle) MODE-UPFRONT) ERR-NOT-AUTHORIZED)
    
    ;; Transfer STX to escrow
    (match (stx-transfer? amount sender (as-contract tx-sender))
      success
        (begin
          (map-set deposits 
            { circle-id: circle-id, member: sender }
            { deposited: true, amount: amount, deposit-block: block-height }
          )
          (map-set circle-deposits circle-id
            { 
              total-deposited: (+ (get total-deposited current-deposits) amount),
              deposit-count: (+ (get deposit-count current-deposits) u1)
            }
          )
          
          ;; Record in reputation
          (try! (contract-call? .stacksusu-reputation-v5 record-contribution sender amount))
          
          ;; Record referral activity
          (match (contract-call? .stacksusu-referral-v5 record-activity sender amount)
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

(define-public (contribute-to-round (circle-id uint))
  (let
    (
      (sender tx-sender)
      (circle-info (unwrap! (contract-call? .stacksusu-core-v5 get-circle-info circle-id) 
                            ERR-CIRCLE-NOT-FOUND))
      (circle (unwrap! circle-info ERR-CIRCLE-NOT-FOUND))
      (current-round (get current-round circle))
      (contribution-amount (get contribution circle))
      (is-member-check (contract-call? .stacksusu-core-v5 is-member circle-id sender))
      (existing-contribution (map-get? round-contributions 
                               { circle-id: circle-id, round: current-round, member: sender }))
      (round-total (default-to { total-amount: u0, contribution-count: u0 }
                     (map-get? round-totals { circle-id: circle-id, round: current-round })))
      (grace-period (contract-call? .stacksusu-admin-v5 get-grace-period))
      (round-start (get start-block circle))
      (payout-interval (get payout-interval circle))
      (round-deadline (+ round-start (* (+ current-round u1) payout-interval)))
      (is-late (> block-height round-deadline))
      (late-fee (if is-late 
                  (contract-call? .stacksusu-admin-v5 calculate-late-fee contribution-amount)
                  u0))
      (total-due (+ contribution-amount late-fee))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v5 is-paused)) ERR-PAUSED)
    (asserts! is-member-check ERR-NOT-MEMBER)
    (asserts! (is-eq (get contribution-mode circle) MODE-ROUND-BY-ROUND) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status circle) u1) ERR-CIRCLE-NOT-FOUND) ;; STATUS-ACTIVE = u1
    (asserts! (is-none existing-contribution) ERR-ALREADY-CONTRIBUTED)
    
    ;; Check grace period for late contributions
    (if is-late
      (asserts! (<= block-height (+ round-deadline grace-period)) ERR-PAYOUT-NOT-DUE)
      true
    )
    
    ;; Transfer contribution
    (match (stx-transfer? total-due sender (as-contract tx-sender))
      success
        (begin
          ;; Record contribution
          (map-set round-contributions
            { circle-id: circle-id, round: current-round, member: sender }
            { amount: contribution-amount, contributed-at: block-height, is-late: is-late }
          )
          
          ;; Update round totals
          (map-set round-totals 
            { circle-id: circle-id, round: current-round }
            {
              total-amount: (+ (get total-amount round-total) contribution-amount),
              contribution-count: (+ (get contribution-count round-total) u1)
            }
          )
          
          ;; Record late fee if applicable
          (if (> late-fee u0)
            (try! (contract-call? .stacksusu-admin-v5 record-fee late-fee))
            true
          )
          
          ;; Record in reputation
          (try! (contract-call? .stacksusu-reputation-v5 record-contribution sender contribution-amount))
          
          ;; Record referral activity
          (match (contract-call? .stacksusu-referral-v5 record-activity sender contribution-amount)
            ok-val true
            err-val true
          )
          
          ;; Update circle stats
          (try! (contract-call? .stacksusu-core-v5 update-circle-stats circle-id contribution-amount u0))
          
          (ok true)
        )
      error ERR-TRANSFER-FAILED
    )
  )
)


;; ============================================
;; Claim Payout
;; ============================================

(define-public (claim-payout (circle-id uint))
  (let
    (
      (caller tx-sender)
      (circle-info (unwrap! (contract-call? .stacksusu-core-v5 get-circle-info circle-id) 
                            ERR-CIRCLE-NOT-FOUND))
      (circle (unwrap! circle-info ERR-CIRCLE-NOT-FOUND))
      (member-info-result (unwrap! (contract-call? .stacksusu-core-v5 get-member-info circle-id caller)
                                    ERR-NOT-MEMBER))
      (member-info (unwrap! member-info-result ERR-NOT-MEMBER))
      (current-round (get current-round circle))
      (contribution (get contribution circle))
      (max-members (get max-members circle))
      (total-pot (* contribution max-members))
      (admin-fee (contract-call? .stacksusu-admin-v5 calculate-admin-fee total-pot))
      (payout-amount (- total-pot admin-fee))
      (contribution-mode (get contribution-mode circle))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v5 is-paused)) ERR-PAUSED)
    (asserts! (is-eq (get status circle) u1) ERR-CIRCLE-NOT-FOUND) ;; STATUS-ACTIVE
    (asserts! (is-eq (get slot member-info) current-round) ERR-NOT-YOUR-TURN)
    (asserts! (not (default-to false (map-get? member-received-payout { circle-id: circle-id, member: caller })))
              ERR-ALREADY-CLAIMED)
    
    ;; Check all contributions received for current round
    (if (is-eq contribution-mode MODE-ROUND-BY-ROUND)
      (let
        (
          (round-total (default-to { total-amount: u0, contribution-count: u0 }
                         (map-get? round-totals { circle-id: circle-id, round: current-round })))
        )
        (asserts! (is-eq (get contribution-count round-total) max-members) ERR-CONTRIBUTIONS-INCOMPLETE)
      )
      ;; Upfront mode - check deposits complete
      (asserts! (are-deposits-complete circle-id max-members) ERR-CONTRIBUTIONS-INCOMPLETE)
    )
    
    ;; Check timing
    (let 
      (
        (start-block (get start-block circle))
        (payout-interval (get payout-interval circle))
        (blocks-since-start (- block-height start-block))
      )
      (asserts! (>= blocks-since-start (* current-round payout-interval)) ERR-PAYOUT-NOT-DUE)
    )
    
    ;; Process payout
    (match (as-contract (stx-transfer? payout-amount tx-sender caller))
      success
        (begin
          ;; Transfer fee to treasury
          (if (> admin-fee u0)
            (match (as-contract (stx-transfer? admin-fee tx-sender (contract-call? .stacksusu-admin-v5 get-treasury)))
              fee-success (try! (contract-call? .stacksusu-admin-v5 record-fee admin-fee))
              fee-error true
            )
            true
          )
          
          ;; Record payout
          (map-set payouts 
            { circle-id: circle-id, round: current-round }
            { recipient: caller, amount: payout-amount, block: block-height, is-emergency: false }
          )
          (map-set member-received-payout { circle-id: circle-id, member: caller } true)
          
          ;; Record completion in reputation
          (try! (contract-call? .stacksusu-reputation-v5 record-completion caller circle-id payout-amount true))
          
          ;; Update stats
          (try! (contract-call? .stacksusu-admin-v5 increment-payouts-processed))
          (try! (contract-call? .stacksusu-core-v5 update-circle-stats circle-id u0 payout-amount))
          
          ;; Advance to next round
          (try! (contract-call? .stacksusu-core-v5 advance-round circle-id))
          
          (ok payout-amount)
        )
      error ERR-TRANSFER-FAILED
    )
  )
)


;; ============================================
;; Process Payout (for authorized callers)
;; ============================================

(define-public (process-payout 
    (circle-id uint) 
    (round uint) 
    (recipient principal) 
    (total-pot uint)
    (admin-fee uint))
  (let
    (
      (payout-amount (- total-pot admin-fee))
    )
    (asserts! (is-authorized contract-caller) ERR-NOT-AUTHORIZED)
    (asserts! (not (default-to false (map-get? member-received-payout { circle-id: circle-id, member: recipient })))
              ERR-ALREADY-CLAIMED)
    
    ;; Transfer payout
    (match (as-contract (stx-transfer? payout-amount tx-sender recipient))
      success
        (begin
          ;; Transfer fee to treasury
          (if (> admin-fee u0)
            (match (as-contract (stx-transfer? admin-fee tx-sender (contract-call? .stacksusu-admin-v5 get-treasury)))
              fee-success (try! (contract-call? .stacksusu-admin-v5 record-fee admin-fee))
              fee-error true
            )
            true
          )
          
          ;; Record payout
          (map-set payouts 
            { circle-id: circle-id, round: round }
            { recipient: recipient, amount: payout-amount, block: block-height, is-emergency: false }
          )
          (map-set member-received-payout { circle-id: circle-id, member: recipient } true)
          
          (ok true)
        )
      error ERR-TRANSFER-FAILED
    )
  )
)


;; ============================================
;; Emergency Payout Processing
;; ============================================

(define-public (process-emergency-payout
    (circle-id uint)
    (round uint)
    (recipient principal)
    (total-pot uint)
    (emergency-fee uint)
    (admin-fee uint))
  (let
    (
      (total-fees (+ emergency-fee admin-fee))
      (payout-amount (- total-pot total-fees))
    )
    (asserts! (is-authorized contract-caller) ERR-NOT-AUTHORIZED)
    (asserts! (not (default-to false (map-get? member-received-payout { circle-id: circle-id, member: recipient })))
              ERR-ALREADY-CLAIMED)
    
    ;; Transfer payout (minus fees)
    (match (as-contract (stx-transfer? payout-amount tx-sender recipient))
      success
        (begin
          ;; Transfer fees to treasury
          (if (> total-fees u0)
            (match (as-contract (stx-transfer? total-fees tx-sender (contract-call? .stacksusu-admin-v5 get-treasury)))
              fee-success (try! (contract-call? .stacksusu-admin-v5 record-fee total-fees))
              fee-error true
            )
            true
          )
          
          ;; Record emergency payout
          (map-set payouts 
            { circle-id: circle-id, round: round }
            { recipient: recipient, amount: payout-amount, block: block-height, is-emergency: true }
          )
          (map-set member-received-payout { circle-id: circle-id, member: recipient } true)
          
          (ok true)
        )
      error ERR-TRANSFER-FAILED
    )
  )
)


;; ============================================
;; Read-only Functions
;; ============================================

(define-read-only (get-deposit-info (circle-id uint) (member principal))
  (ok (map-get? deposits { circle-id: circle-id, member: member }))
)

(define-read-only (get-circle-deposit-status (circle-id uint))
  (ok (default-to { total-deposited: u0, deposit-count: u0 } 
        (map-get? circle-deposits circle-id)))
)

(define-read-only (get-round-contribution (circle-id uint) (round uint) (member principal))
  (ok (map-get? round-contributions { circle-id: circle-id, round: round, member: member }))
)

(define-read-only (get-round-totals (circle-id uint) (round uint))
  (ok (default-to { total-amount: u0, contribution-count: u0 }
        (map-get? round-totals { circle-id: circle-id, round: round })))
)

(define-read-only (get-payout-info (circle-id uint) (round uint))
  (ok (map-get? payouts { circle-id: circle-id, round: round }))
)

(define-read-only (has-received-payout (circle-id uint) (member principal))
  (default-to false (map-get? member-received-payout { circle-id: circle-id, member: member }))
)

(define-read-only (are-deposits-complete (circle-id uint) (expected-count uint))
  (let
    (
      (deposit-status (default-to { total-deposited: u0, deposit-count: u0 } 
                        (map-get? circle-deposits circle-id)))
    )
    (is-eq (get deposit-count deposit-status) expected-count)
  )
)

(define-read-only (are-round-contributions-complete (circle-id uint) (round uint) (expected-count uint))
  (let
    (
      (round-total (default-to { total-amount: u0, contribution-count: u0 }
                     (map-get? round-totals { circle-id: circle-id, round: round })))
    )
    (is-eq (get contribution-count round-total) expected-count)
  )
)

(define-read-only (has-contributed-to-round (circle-id uint) (round uint) (member principal))
  (is-some (map-get? round-contributions { circle-id: circle-id, round: round, member: member }))
)
