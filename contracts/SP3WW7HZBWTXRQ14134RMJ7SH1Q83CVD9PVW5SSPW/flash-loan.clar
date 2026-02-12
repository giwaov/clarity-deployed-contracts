;; Flash Loan Provider
;; Uncollateralized loans that must be repaid in same transaction

(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-insufficient-liquidity (err u101))
(define-constant err-loan-not-repaid (err u102))

(define-data-var total-liquidity uint u0)
(define-data-var flash-loan-fee uint u9) ;; 0.09% fee

(define-map active-loans uint { borrower: principal, amount: uint, fee: uint })
(define-data-var next-loan-id uint u1)

(define-read-only (get-available-liquidity)
  (var-get total-liquidity)
)

(define-read-only (calculate-fee (amount uint))
  (/ (* amount (var-get flash-loan-fee)) u10000)
)

(define-public (provide-liquidity (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set total-liquidity (+ (var-get total-liquidity) amount))
    (ok amount)
  )
)

(define-public (flash-loan (amount uint))
  (let (
    (loan-id (var-get next-loan-id))
    (fee (calculate-fee amount))
  )
    (asserts! (>= (var-get total-liquidity) amount) err-insufficient-liquidity)
    (map-set active-loans loan-id { borrower: tx-sender, amount: amount, fee: fee })
    (var-set next-loan-id (+ loan-id u1))
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (ok loan-id)
  )
)

(define-public (repay-flash-loan (loan-id uint))
  (let (
    (loan (unwrap! (map-get? active-loans loan-id) (err u103)))
    (total-repay (+ (get amount loan) (get fee loan)))
  )
    (asserts! (is-eq tx-sender (get borrower loan)) err-unauthorized)
    (try! (stx-transfer? total-repay tx-sender (as-contract tx-sender)))
    (map-delete active-loans loan-id)
    (ok true)
  )
)
