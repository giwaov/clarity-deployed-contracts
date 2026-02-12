
;; nova-carbon-credit-registry.clar
;; Track carbon credits
;; CLARITY VERSION: 2

(define-map credits
    principal
    uint
)

(define-public (issue-credits (user principal) (amount uint))
    (let (
        (current (default-to u0 (map-get? credits user)))
    )
    (map-set credits user (+ current amount))
    (ok true)
    )
)

(define-public (retire-credits (amount uint))
    (let (
        (current (default-to u0 (map-get? credits tx-sender)))
    )
    (asserts! (>= current amount) (err u100))
    (map-set credits tx-sender (- current amount))
    (ok true)
    )
)
