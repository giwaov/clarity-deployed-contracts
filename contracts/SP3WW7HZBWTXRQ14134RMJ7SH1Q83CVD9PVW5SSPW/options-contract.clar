;; Options Contract

(define-data-var next-option-id uint u1)

(define-map options uint { holder: principal, strike-price: uint, expiry: uint, exercised: bool })

(define-public (create-option (strike-price uint) (expiry uint))
  (let ((option-id (var-get next-option-id)))
    (map-set options option-id { holder: tx-sender, strike-price: strike-price, expiry: expiry, exercised: false })
    (var-set next-option-id (+ option-id u1))
    (ok option-id)
  )
)

(define-public (exercise-option (option-id uint))
  (let ((option (unwrap! (map-get? options option-id) (err u100))))
    (asserts! (is-eq tx-sender (get holder option)) (err u101))
    (asserts! (< block-height (get expiry option)) (err u102))
    (map-set options option-id (merge option { exercised: true }))
    (ok true)
  )
)
