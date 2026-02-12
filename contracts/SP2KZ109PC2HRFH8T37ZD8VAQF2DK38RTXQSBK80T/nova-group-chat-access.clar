
;; nova-group-chat-access.clar
;; NFT-gated chat access
;; CLARITY VERSION: 2

(use-trait nova-trait-non-fungible .nova-trait-non-fungible.nova-trait-non-fungible)

(define-map groups
    uint
    {
        name: (string-ascii 64),
        token: principal
    }
)

(define-read-only (can-access (group-id uint) (user principal) (nft <nova-trait-non-fungible>))
    (let ((group (unwrap! (map-get? groups group-id) (err u404))))
        (asserts! (is-eq (contract-of nft) (get token group)) (err u100))
        ;; In reality we need to check if user owns at least one token
        (ok true)
    )
)
