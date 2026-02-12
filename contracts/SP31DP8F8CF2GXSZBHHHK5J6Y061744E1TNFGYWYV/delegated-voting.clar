;; delegated-voting.clar
;; Allows token holders to delegate voting power to representatives.
;; CLARITY VERSION: 4

(use-trait governance-token-trait .governance-token-trait.governance-token-trait)

(define-map delegations
    principal
    principal
)

(define-map delegated-power
    principal
    uint
)

(define-public (delegate
        (to principal)
        (token-trait <governance-token-trait>)
    )
    (let (
            (sender tx-sender)
            (balance (unwrap-panic (contract-call? token-trait get-balance sender)))
            (current-delegate (map-get? delegations sender))
        )
        (asserts! (not (is-eq sender to)) (err u100))
        ;; Cannot delegate to self explicitly, just undelegate

        ;; If already delegated, remove power from old delegate
        (match current-delegate
            old-delegate (map-set delegated-power old-delegate
                (- (default-to u0 (map-get? delegated-power old-delegate))
                    balance
                ))
            true
        )

        (map-set delegations sender to)
        (map-set delegated-power to
            (+ (default-to u0 (map-get? delegated-power to)) balance)
        )

        (ok true)
    )
)

(define-public (undelegate (token-trait <governance-token-trait>))
    (let (
            (sender tx-sender)
            (current-delegate (unwrap! (map-get? delegations sender) (err u101)))
            (balance (unwrap-panic (contract-call? token-trait get-balance sender)))
        )
        (map-set delegated-power current-delegate
            (- (default-to u0 (map-get? delegated-power current-delegate))
                balance
            ))

        (map-delete delegations sender)
        (ok true)
    )
)

(define-public (get-voting-power
        (voter principal)
        (token-trait <governance-token-trait>)
    )
    (let (
            (balance (unwrap-panic (contract-call? token-trait get-balance voter)))
            (delegated (default-to u0 (map-get? delegated-power voter)))
        )
        (ok (+ balance delegated))
    )
)
