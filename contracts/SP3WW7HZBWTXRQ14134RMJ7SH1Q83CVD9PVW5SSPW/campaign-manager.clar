;; Campaign Manager

(define-data-var next-campaign-id uint u1)

(define-map campaigns uint { creator: principal, goal: uint, raised: uint, deadline: uint, active: bool })

(define-public (create-campaign (goal uint) (deadline uint))
  (let ((campaign-id (var-get next-campaign-id)))
    (map-set campaigns campaign-id { creator: tx-sender, goal: goal, raised: u0, deadline: deadline, active: true })
    (var-set next-campaign-id (+ campaign-id u1))
    (ok campaign-id)
  )
)

(define-public (contribute-to-campaign (campaign-id uint) (amount uint))
  (let ((campaign (unwrap! (map-get? campaigns campaign-id) (err u100))))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set campaigns campaign-id (merge campaign { raised: (+ (get raised campaign) amount) }))
    (ok amount)
  )
)
