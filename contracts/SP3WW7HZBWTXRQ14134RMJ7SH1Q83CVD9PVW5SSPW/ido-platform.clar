;; IDO Platform

(define-data-var next-ido-id uint u1)

(define-map idos uint { project: principal, target: uint, raised: uint, active: bool })

(define-public (create-ido (target uint))
  (let ((ido-id (var-get next-ido-id)))
    (map-set idos ido-id { project: tx-sender, target: target, raised: u0, active: true })
    (var-set next-ido-id (+ ido-id u1))
    (ok ido-id)
  )
)

(define-public (participate (ido-id uint) (amount uint))
  (let ((ido (unwrap! (map-get? idos ido-id) (err u100))))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set idos ido-id (merge ido { raised: (+ (get raised ido) amount) }))
    (ok amount)
  )
)
