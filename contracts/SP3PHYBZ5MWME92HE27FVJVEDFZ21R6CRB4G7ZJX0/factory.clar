;; Contract: Certified Factory
;; Description: Manages authorized manufacturers.

(define-data-var authorized-factory principal tx-sender)

(define-read-only (is-authorized (user principal))
    (ok (is-eq user (var-get authorized-factory)))
)

(define-public (change-factory (new-factory principal))
    (begin
        ;; Only the current factory can hand over control
        (asserts! (is-eq tx-sender (var-get authorized-factory)) (err u403))
        (var-set authorized-factory new-factory)
        (ok "Factory Authority Transferred")
    )
)