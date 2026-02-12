;; Refund Handler

(define-map contributions { campaign-id: uint, contributor: principal } uint)

(define-public (request-refund (campaign-id uint))
  (let ((amount (default-to u0 (map-get? contributions { campaign-id: campaign-id, contributor: tx-sender }))))
    (asserts! (> amount u0) (err u100))
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (map-delete contributions { campaign-id: campaign-id, contributor: tx-sender })
    (ok amount)
  )
)
