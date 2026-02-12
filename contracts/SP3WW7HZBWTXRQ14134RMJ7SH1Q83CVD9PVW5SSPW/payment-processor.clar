;; Storage Payment Processor

(define-map storage-payments principal uint)

(define-public (pay-for-storage (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set storage-payments tx-sender (+ (default-to u0 (map-get? storage-payments tx-sender)) amount))
    (ok amount)
  )
)
