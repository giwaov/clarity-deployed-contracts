;; ---------------------------------------------------------
;; User Registry
;; Registers users into the protocol
;; ---------------------------------------------------------

(define-map users principal uint)


;; Registers the sender with block height as join time
(define-public (register)
    (begin
        (map-set users tx-sender stacks-block-height)
        (ok stacks-block-height)
    )
)


;; Checks if a user is registered
(define-read-only (is-registered (user principal))
    (is-some (map-get? users user))
)