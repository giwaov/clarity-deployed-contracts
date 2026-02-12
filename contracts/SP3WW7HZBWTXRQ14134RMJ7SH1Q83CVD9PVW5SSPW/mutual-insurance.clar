;; Mutual Insurance Pool

(define-data-var total-pool uint u0)
(define-map member-contributions principal uint)
(define-map claims uint { member: principal, amount: uint, approved: bool })
(define-data-var next-claim-id uint u1)

(define-public (join-pool (contribution uint))
  (begin
    (try! (stx-transfer? contribution tx-sender (as-contract tx-sender)))
    (map-set member-contributions tx-sender (+ (default-to u0 (map-get? member-contributions tx-sender)) contribution))
    (var-set total-pool (+ (var-get total-pool) contribution))
    (ok true)
  )
)

(define-public (file-claim (amount uint))
  (let ((claim-id (var-get next-claim-id)))
    (map-set claims claim-id { member: tx-sender, amount: amount, approved: false })
    (var-set next-claim-id (+ claim-id u1))
    (ok claim-id)
  )
)