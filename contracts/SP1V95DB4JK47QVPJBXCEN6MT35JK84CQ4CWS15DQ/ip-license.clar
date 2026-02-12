(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u800))
(define-constant ERR_NFT_NOT_FOUND (err u801))
(define-constant ERR_LICENSE_NOT_FOUND (err u802))

(define-non-fungible-token ip-nft uint)

(define-data-var next-nft-id uint u1)
(define-data-var next-license-id uint u1)

(define-map nft-metadata
  uint
  {
    creator: principal,
    parent-id: (optional uint),
    remix-allowed: bool,
    created-at: uint
  }
)

(define-map licenses
  uint
  {
    nft-id: uint,
    license-type: (string-ascii 50),
    royalty-percentage: uint,
    terms: (string-ascii 512),
    active: bool
  }
)

(define-map nft-relationships
  {parent: uint, child: uint}
  {relationship-type: (string-ascii 20), royalty-share: uint}
)

(define-read-only (get-contract-hash)
  (contract-hash? .ip-license)
)

(define-read-only (get-nft-metadata (nft-id uint))
  (ok (unwrap! (map-get? nft-metadata nft-id) ERR_NFT_NOT_FOUND))
)

(define-read-only (get-license (license-id uint))
  (ok (unwrap! (map-get? licenses license-id) ERR_LICENSE_NOT_FOUND))
)

(define-public (mint-original-nft (to principal) (remix-allowed bool))
  (let
    (
      (nft-id (var-get next-nft-id))
    )
    (try! (nft-mint? ip-nft nft-id to))
    (map-set nft-metadata nft-id {
      creator: to,
      parent-id: none,
      remix-allowed: remix-allowed,
      created-at: stacks-block-time
    })
    (var-set next-nft-id (+ nft-id u1))
    (ok nft-id)
  )
)

(define-public (mint-remix-nft (to principal) (parent-id uint) (remix-allowed bool))
  (let
    (
      (nft-id (var-get next-nft-id))
      (parent-data (unwrap! (map-get? nft-metadata parent-id) ERR_NFT_NOT_FOUND))
    )
    (asserts! (get remix-allowed parent-data) ERR_NOT_AUTHORIZED)
    (try! (nft-mint? ip-nft nft-id to))
    (map-set nft-metadata nft-id {
      creator: to,
      parent-id: (some parent-id),
      remix-allowed: remix-allowed,
      created-at: stacks-block-time
    })
    (map-set nft-relationships 
      {parent: parent-id, child: nft-id}
      {relationship-type: "Remix", royalty-share: u10}
    )
    (var-set next-nft-id (+ nft-id u1))
    (ok nft-id)
  )
)

(define-public (create-license 
  (nft-id uint)
  (license-type (string-ascii 50))
  (royalty-percentage uint)
  (terms (string-ascii 512))
)
  (let
    (
      (license-id (var-get next-license-id))
      (nft-data (unwrap! (map-get? nft-metadata nft-id) ERR_NFT_NOT_FOUND))
    )
    (asserts! (is-eq (get creator nft-data) tx-sender) ERR_NOT_AUTHORIZED)
    (map-set licenses license-id {
      nft-id: nft-id,
      license-type: license-type,
      royalty-percentage: royalty-percentage,
      terms: terms,
      active: true
    })
    (var-set next-license-id (+ license-id u1))
    (ok license-id)
  )
)

(define-public (revoke-license (license-id uint))
  (let
    (
      (license-data (unwrap! (map-get? licenses license-id) ERR_LICENSE_NOT_FOUND))
      (nft-data (unwrap! (map-get? nft-metadata (get nft-id license-data)) ERR_NFT_NOT_FOUND))
    )
    (asserts! (is-eq (get creator nft-data) tx-sender) ERR_NOT_AUTHORIZED)
    (map-set licenses license-id (merge license-data {active: false}))
    (ok true)
  )
)

(define-public (transfer (nft-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    (nft-transfer? ip-nft nft-id sender recipient)
  )
)

(define-read-only (get-relationship (parent uint) (child uint))
  (ok (map-get? nft-relationships {parent: parent, child: child}))
)

(define-read-only (verify-license-signature (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (ok (secp256r1-verify message signature public-key))
)

(define-read-only (get-block-timestamp)
  stacks-block-time
)
