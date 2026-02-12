;; Insurance Policy Manager

(define-constant contract-owner tx-sender)
(define-data-var next-policy-id uint u1)

(define-map policies uint { holder: principal, premium: uint, coverage: uint, active: bool })

(define-read-only (get-policy (policy-id uint))
  (map-get? policies policy-id)
)

(define-public (create-policy (premium uint) (coverage uint))
  (let ((policy-id (var-get next-policy-id)))
    (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
    (map-set policies policy-id { holder: tx-sender, premium: premium, coverage: coverage, active: true })
    (var-set next-policy-id (+ policy-id u1))
    (ok policy-id)
  )
)
