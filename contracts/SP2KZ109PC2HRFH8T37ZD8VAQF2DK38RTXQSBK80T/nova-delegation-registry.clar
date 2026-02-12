
;; nova-delegation-registry.clar
;; Advanced delegation logic
;; CLARITY VERSION: 2

(define-map delegations
    principal
    principal
)

(define-public (delegate-to (delegatee principal))
    (begin
        (map-set delegations tx-sender delegatee)
        (ok true)
    )
)

(define-public (revoke-delegation)
    (begin
        (map-delete delegations tx-sender)
        (ok true)
    )
)

(define-read-only (get-delegate (user principal))
    (map-get? delegations user)
)
