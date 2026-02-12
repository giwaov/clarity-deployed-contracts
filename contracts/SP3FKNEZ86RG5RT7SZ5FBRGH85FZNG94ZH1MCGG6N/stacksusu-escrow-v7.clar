;; StackSusu Escrow v7
;; Simplified escrow for holding circle funds

(define-constant CONTRACT-OWNER tx-sender)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u3000))
(define-constant ERR-INSUFFICIENT-BALANCE (err u3001))
(define-constant ERR-TRANSFER-FAILED (err u3002))
(define-constant ERR-INVALID-AMOUNT (err u3003))
(define-constant ERR-CIRCLE-NOT-FOUND (err u3004))

;; Helper function for min
(define-private (get-min (a uint) (b uint))
  (if (<= a b) a b)
)

;; Circle escrow balances
(define-map circle-escrow
  uint  ;; circle-id
  {
    total-balance: uint,
    total-deposits: uint,
    total-withdrawals: uint
  }
)

;; Member balances within circles
(define-map member-escrow
  { circle-id: uint, member: principal }
  uint
)


;; ============================================
;; Core Functions
;; ============================================

(define-public (deposit (circle-id uint) (amount uint))
  (let
    (
      (sender tx-sender)
      (current-escrow (default-to { total-balance: u0, total-deposits: u0, total-withdrawals: u0 }
        (map-get? circle-escrow circle-id)))
      (current-member-balance (default-to u0 (map-get? member-escrow { circle-id: circle-id, member: sender })))
    )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Transfer STX to this contract
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    
    ;; Update circle escrow
    (map-set circle-escrow circle-id {
      total-balance: (+ (get total-balance current-escrow) amount),
      total-deposits: (+ (get total-deposits current-escrow) amount),
      total-withdrawals: (get total-withdrawals current-escrow)
    })
    
    ;; Update member balance
    (map-set member-escrow { circle-id: circle-id, member: sender }
      (+ current-member-balance amount))
    
    (ok true)
  )
)

(define-public (process-payout (circle-id uint) (recipient principal) (amount uint))
  (let
    (
      (current-escrow (unwrap! (map-get? circle-escrow circle-id) ERR-CIRCLE-NOT-FOUND))
    )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= (get total-balance current-escrow) amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Transfer STX to recipient
    (try! (as-contract (stx-transfer? amount tx-sender recipient)))
    
    ;; Update escrow
    (map-set circle-escrow circle-id {
      total-balance: (- (get total-balance current-escrow) amount),
      total-deposits: (get total-deposits current-escrow),
      total-withdrawals: (+ (get total-withdrawals current-escrow) amount)
    })
    
    (ok true)
  )
)

(define-public (emergency-withdraw (circle-id uint) (amount uint))
  (let
    (
      (member tx-sender)
      (member-balance (default-to u0 (map-get? member-escrow { circle-id: circle-id, member: member })))
      (current-escrow (unwrap! (map-get? circle-escrow circle-id) ERR-CIRCLE-NOT-FOUND))
      (withdraw-amount (get-min amount member-balance))
      (fee-bps (contract-call? .stacksusu-admin-v7 get-emergency-fee-bps))
      (fee (/ (* withdraw-amount fee-bps) u10000))
      (net-amount (- withdraw-amount fee))
    )
    (asserts! (> withdraw-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= (get total-balance current-escrow) withdraw-amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Transfer to member (minus fee)
    (try! (as-contract (stx-transfer? net-amount tx-sender member)))
    
    ;; Transfer fee to treasury
    (if (> fee u0)
      (try! (as-contract (stx-transfer? fee tx-sender (contract-call? .stacksusu-admin-v7 get-treasury))))
      true
    )
    
    ;; Update balances
    (map-set member-escrow { circle-id: circle-id, member: member }
      (- member-balance withdraw-amount))
    
    (map-set circle-escrow circle-id {
      total-balance: (- (get total-balance current-escrow) withdraw-amount),
      total-deposits: (get total-deposits current-escrow),
      total-withdrawals: (+ (get total-withdrawals current-escrow) withdraw-amount)
    })
    
    (ok net-amount)
  )
)


;; ============================================
;; Read Functions
;; ============================================

(define-read-only (get-circle-balance (circle-id uint))
  (ok (get total-balance (default-to { total-balance: u0, total-deposits: u0, total-withdrawals: u0 }
    (map-get? circle-escrow circle-id))))
)

(define-read-only (get-member-balance (circle-id uint) (member principal))
  (ok (default-to u0 (map-get? member-escrow { circle-id: circle-id, member: member })))
)

(define-read-only (get-escrow-stats (circle-id uint))
  (ok (default-to { total-balance: u0, total-deposits: u0, total-withdrawals: u0 }
    (map-get? circle-escrow circle-id)))
)
