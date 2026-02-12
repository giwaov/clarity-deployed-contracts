;; subscription.clar
;; Simple time-based subscription

(define-map subscriptions principal uint) ;; User -> Expiry Block Height
(define-constant DURATION u4320) ;; ~30 Days in blocks
(define-constant PRICE u100)

(define-public (subscribe)
    (let
        (
            (current-expiry (default-to stacks-block-height (map-get? subscriptions tx-sender)))
            (start-time (if (> current-expiry stacks-block-height) current-expiry stacks-block-height))
            (new-expiry (+ start-time DURATION))
        )
        (try! (stx-transfer? PRICE tx-sender (as-contract tx-sender)))
        (map-set subscriptions tx-sender new-expiry)
        (ok new-expiry)
    )
)

(define-read-only (is-subscribed (user principal))
    (let
        (
            (expiry (default-to u0 (map-get? subscriptions user)))
        )
        (> expiry stacks-block-height)
    )
)
