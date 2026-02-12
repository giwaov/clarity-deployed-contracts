;; Claims Processor

(define-constant contract-owner tx-sender)
(define-data-var next-claim-id uint u1)

(define-map claims uint { policy-id: uint, amount: uint, approved: bool })

(define-public (file-claim (policy-id uint) (amount uint))
  (let ((claim-id (var-get next-claim-id)))
    (map-set claims claim-id { policy-id: policy-id, amount: amount, approved: false })
    (var-set next-claim-id (+ claim-id u1))
    (ok claim-id)
  )
)

(define-public (approve-claim (claim-id uint))
  (let ((claim (unwrap! (map-get? claims claim-id) (err u100))))
    (asserts! (is-eq tx-sender contract-owner) (err u101))
    (map-set claims claim-id (merge claim { approved: true }))
    (ok true)
  )
)
