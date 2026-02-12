;; Contract: Bike Registry
;; Description: Stores bike details and status.

(define-map bikes uint { owner: principal, is-rented: bool })
(define-data-var bike-count uint u0)

(define-read-only (get-bike (id uint))
    (map-get? bikes id)
)

(define-public (add-bike)
    (let
        (
            (new-id (+ (var-get bike-count) u1))
        )
        (map-set bikes new-id { owner: tx-sender, is-rented: false })
        (var-set bike-count new-id)
        (ok new-id)
    )
)

;; Only the Rental Contract should call this (simplified for demo)
(define-public (set-status (id uint) (rented bool))
    (let
        (
            (bike (unwrap! (map-get? bikes id) (err u404)))
        )
        (map-set bikes id (merge bike { is-rented: rented }))
        (ok "Status Updated")
    )
)