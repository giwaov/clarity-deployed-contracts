
;; nova-dynamic-pricing.clar
;; Dynamic pricing model based on supply/demand
;; CLARITY VERSION: 2

(define-data-var base-price uint u100)
(define-data-var demand-factor uint u1)

(define-read-only (get-price)
    (ok (* (var-get base-price) (var-get demand-factor)))
)

(define-public (update-demand (new-factor uint))
    (begin
        (var-set demand-factor new-factor)
        (ok true)
    )
)
