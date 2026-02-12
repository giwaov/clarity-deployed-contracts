(define-non-fungible-token emoji-nft uint)

(define-map emotes
    { nft-contract: principal, token-id: uint, emoji: (string-utf8 10) }
    (list 100 principal)
)

(define-map emote-count
    { nft-contract: principal, token-id: uint, emoji: (string-utf8 10) }
    uint
)

(define-map user-emotes
    { user: principal, nft-contract: principal, token-id: uint }
    (list 20 (string-utf8 10))
)

(define-constant err-already-emoted (err u100))
(define-constant err-invalid-emoji (err u101))
(define-constant err-max-emotes (err u102))
(define-constant err-invalid-signature (err u103))

(define-read-only (get-emote-count (nft-contract principal) (token-id uint) (emoji (string-utf8 10)))
    (ok (default-to u0 (map-get? emote-count { nft-contract: nft-contract, token-id: token-id, emoji: emoji })))
)

(define-read-only (get-emotes (nft-contract principal) (token-id uint) (emoji (string-utf8 10)))
    (ok (map-get? emotes { nft-contract: nft-contract, token-id: token-id, emoji: emoji }))
)

(define-read-only (get-user-emotes (user principal) (nft-contract principal) (token-id uint))
    (ok (map-get? user-emotes { user: user, nft-contract: nft-contract, token-id: token-id }))
)

(define-read-only (has-emoted (user principal) (nft-contract principal) (token-id uint) (emoji (string-utf8 10)))
    (match (map-get? user-emotes { user: user, nft-contract: nft-contract, token-id: token-id })
        user-emoji-list (ok (is-some (index-of user-emoji-list emoji)))
        (ok false)
    )
)

(define-public (emote (nft-contract principal) (token-id uint) (emoji (string-utf8 10)))
    (let
        (
            (current-emotes (default-to (list) (map-get? emotes { nft-contract: nft-contract, token-id: token-id, emoji: emoji })))
            (current-count (default-to u0 (map-get? emote-count { nft-contract: nft-contract, token-id: token-id, emoji: emoji })))
            (user-emoji-list (default-to (list) (map-get? user-emotes { user: tx-sender, nft-contract: nft-contract, token-id: token-id })))
        )
        (asserts! (> (len emoji) u0) err-invalid-emoji)
        (asserts! (is-none (index-of user-emoji-list emoji)) err-already-emoted)
        (asserts! (< (len current-emotes) u100) err-max-emotes)
        (map-set emotes { nft-contract: nft-contract, token-id: token-id, emoji: emoji }
            (unwrap-panic (as-max-len? (append current-emotes tx-sender) u100))
        )
        (map-set emote-count { nft-contract: nft-contract, token-id: token-id, emoji: emoji }
            (+ current-count u1)
        )
        (map-set user-emotes { user: tx-sender, nft-contract: nft-contract, token-id: token-id }
            (unwrap-panic (as-max-len? (append user-emoji-list emoji) u20))
        )
        (ok true)
    )
)

(define-public (remove-emote (nft-contract principal) (token-id uint) (emoji (string-utf8 10)))
    (let
        (
            (current-count (default-to u0 (map-get? emote-count { nft-contract: nft-contract, token-id: token-id, emoji: emoji })))
            (user-emoji-list (default-to (list) (map-get? user-emotes { user: tx-sender, nft-contract: nft-contract, token-id: token-id })))
        )
        (asserts! (is-some (index-of user-emoji-list emoji)) err-already-emoted)
        (map-set emote-count { nft-contract: nft-contract, token-id: token-id, emoji: emoji }
            (if (> current-count u0) (- current-count u1) u0)
        )
        (ok true)
    )
)
