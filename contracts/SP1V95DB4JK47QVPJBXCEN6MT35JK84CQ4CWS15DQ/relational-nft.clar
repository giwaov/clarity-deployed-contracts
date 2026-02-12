(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u400))
(define-constant ERR_NFT_NOT_FOUND (err u401))
(define-constant ERR_INVALID_PARAMS (err u402))

(define-data-var next-nft-id uint u1)

(define-map nft-ownership
  uint
  principal
)

(define-map nft-relationships
  {original-id: uint, derivative-id: uint}
  uint
)

(define-map nft-attributes
  {nft-id: uint, attribute-name: (buff 32)}
  (buff 32)
)

(define-map nft-attribute-list
  uint
  (list 20 (buff 32))
)

(define-read-only (get-contract-hash)
  (contract-hash? .relational-nft)
)

(define-read-only (get-owner (nft-id uint))
  (ok (unwrap! (map-get? nft-ownership nft-id) ERR_NFT_NOT_FOUND))
)

(define-read-only (get-relationship (original-id uint) (derivative-id uint))
  (ok (default-to u0 (map-get? nft-relationships {original-id: original-id, derivative-id: derivative-id})))
)

(define-read-only (get-attribute (nft-id uint) (attribute-name (buff 32)))
  (ok (default-to 0x (map-get? nft-attributes {nft-id: nft-id, attribute-name: attribute-name})))
)

(define-read-only (get-attribute-names (nft-id uint))
  (ok (default-to (list) (map-get? nft-attribute-list nft-id)))
)

(define-public (mint-nft (to principal))
  (let
    (
      (nft-id (var-get next-nft-id))
    )
    (map-set nft-ownership nft-id to)
    (var-set next-nft-id (+ nft-id u1))
    (ok nft-id)
  )
)

(define-public (set-relationship (original-id uint) (derivative-id uint) (attribute uint))
  (let
    (
      (original-owner (unwrap! (map-get? nft-ownership original-id) ERR_NFT_NOT_FOUND))
      (derivative-owner (unwrap! (map-get? nft-ownership derivative-id) ERR_NFT_NOT_FOUND))
    )
    (asserts! (not (is-eq original-id derivative-id)) ERR_INVALID_PARAMS)
    (map-set nft-relationships 
      {original-id: original-id, derivative-id: derivative-id}
      attribute
    )
    (ok true)
  )
)

(define-public (set-attribute (nft-id uint) (attribute-name (buff 32)) (attribute-value (buff 32)))
  (let
    (
      (owner (unwrap! (map-get? nft-ownership nft-id) ERR_NFT_NOT_FOUND))
      (existing-attributes (default-to (list) (map-get? nft-attribute-list nft-id)))
    )
    (asserts! (is-eq owner tx-sender) ERR_NOT_AUTHORIZED)
    (map-set nft-attributes 
      {nft-id: nft-id, attribute-name: attribute-name}
      attribute-value
    )
    (if (is-none (index-of existing-attributes attribute-name))
      (map-set nft-attribute-list nft-id 
        (unwrap-panic (as-max-len? (append existing-attributes attribute-name) u20))
      )
      true
    )
    (ok true)
  )
)

(define-public (transfer-nft (nft-id uint) (from principal) (to principal))
  (let
    (
      (owner (unwrap! (map-get? nft-ownership nft-id) ERR_NFT_NOT_FOUND))
    )
    (asserts! (is-eq owner from) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq tx-sender from) ERR_NOT_AUTHORIZED)
    (map-set nft-ownership nft-id to)
    (ok true)
  )
)

(define-read-only (verify-signature-r1 (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (ok (secp256r1-verify message signature public-key))
)

(define-read-only (get-block-time)
  stacks-block-time
)

(define-read-only (check-asset-restriction)
  (ok (is-ok (contract-hash? .relational-nft)))
)
