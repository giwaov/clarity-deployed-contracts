(define-constant ERR_NOT_AUTHORIZED (err u200))
(define-constant ERR_NOT_FOUND (err u201))
(define-constant ERR_ALREADY_REDEEMED (err u202))

(define-non-fungible-token multi-redemption-nft uint)

(define-data-var token-id-nonce uint u0)

(define-map redemptions 
  {operator: principal, token-id: uint, redemption-id: (buff 32)} 
  {redeemed: bool, memo: (string-utf8 256), timestamp: uint}
)

(define-map token-owners uint principal)
(define-map token-uris uint (string-ascii 256))

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce))
)

(define-read-only (get-token-uri (id uint))
  (ok (map-get? token-uris id))
)

(define-read-only (get-owner (id uint))
  (ok (nft-get-owner? multi-redemption-nft id))
)

(define-public (transfer (id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    (nft-transfer? multi-redemption-nft id sender recipient)
  )
)

(define-public (mint (recipient principal) (uri (string-ascii 256)))
  (let (
    (id (+ (var-get token-id-nonce) u1))
  )
    (try! (nft-mint? multi-redemption-nft id recipient))
    (map-set token-uris id uri)
    (var-set token-id-nonce id)
    (ok id)
  )
)

(define-public (redeem (redemption-id (buff 32)) (token-id uint) (memo (string-utf8 256)))
  (let (
    (owner (unwrap! (nft-get-owner? multi-redemption-nft token-id) ERR_NOT_FOUND))
    (key {operator: tx-sender, token-id: token-id, redemption-id: redemption-id})
  )
    (asserts! (is-eq owner tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-none (map-get? redemptions key)) ERR_ALREADY_REDEEMED)
    (map-set redemptions key {
      redeemed: true, 
      memo: memo, 
      timestamp: stacks-block-time
    })
    (print {event: "redeem", operator: tx-sender, token-id: token-id, redemption-id: redemption-id, memo: memo})
    (ok true)
  )
)

(define-public (cancel (redemption-id (buff 32)) (token-id uint) (memo (string-utf8 256)))
  (let (
    (key {operator: tx-sender, token-id: token-id, redemption-id: redemption-id})
    (redemption (unwrap! (map-get? redemptions key) ERR_NOT_FOUND))
  )
    (map-delete redemptions key)
    (print {event: "cancel", operator: tx-sender, token-id: token-id, redemption-id: redemption-id, memo: memo})
    (ok true)
  )
)

(define-read-only (is-redeemed (operator principal) (redemption-id (buff 32)) (token-id uint))
  (let (
    (key {operator: operator, token-id: token-id, redemption-id: redemption-id})
    (redemption (map-get? redemptions key))
  )
    (ok (if (is-some redemption)
      (get redeemed (unwrap-panic redemption))
      false
    ))
  )
)

(define-read-only (get-redemption-info (operator principal) (redemption-id (buff 32)) (token-id uint))
  (ok (map-get? redemptions {operator: operator, token-id: token-id, redemption-id: redemption-id}))
)
