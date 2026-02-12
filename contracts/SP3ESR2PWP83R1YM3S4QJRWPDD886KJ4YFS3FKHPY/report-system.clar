;; Report System

(define-map reports
  uint
  { reporter: principal, target: principal, reason: (string-ascii 100), resolved: bool }
)

(define-data-var counter uint u0)

(define-public (submit-report (target principal) (reason (string-ascii 100)))
  (let ((id (var-get counter)))
    (map-set reports id { reporter: tx-sender, target: target, reason: reason, resolved: false })
    (var-set counter (+ id u1))
    (ok id)
  )
)

(define-public (resolve-report (id uint))
  (let ((report (unwrap! (map-get? reports id) (err u404))))
    (map-set reports id (merge report { resolved: true }))
    (ok true)
  )
)

(define-read-only (get-report (id uint))
  (map-get? reports id)
)
