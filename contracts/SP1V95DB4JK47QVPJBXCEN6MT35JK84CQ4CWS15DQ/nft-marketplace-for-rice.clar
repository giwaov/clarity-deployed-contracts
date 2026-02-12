(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-not-for-sale (err u104))

(define-map rice-nfts
  {nft-id: uint}
  {
    variety: (string-ascii 64),
    origin: (string-ascii 128),
    harvest-date: uint,
    quantity: uint,
    quality-grade: (string-ascii 16),
    owner: principal,
    for-sale: bool,
    price: uint,
    metadata-uri: (string-ascii 256)
  }
)

(define-map offers
  {offer-id: uint}
  {
    nft-id: uint,
    buyer: principal,
    price: uint,
    status: (string-ascii 16),
    created-at: uint
  }
)

(define-data-var nft-nonce uint u0)
(define-data-var offer-nonce uint u0)

(define-read-only (get-rice-nft (nft-id uint))
  (map-get? rice-nfts {nft-id: nft-id})
)

(define-read-only (get-offer (offer-id uint))
  (map-get? offers {offer-id: offer-id})
)

(define-public (mint-rice-nft
  (variety (string-ascii 64))
  (origin (string-ascii 128))
  (harvest-date uint)
  (quantity uint)
  (quality-grade (string-ascii 16))
  (metadata-uri (string-ascii 256))
)
  (let ((nft-id (var-get nft-nonce)))
    (asserts! (> quantity u0) err-invalid-params)
    (map-set rice-nfts {nft-id: nft-id}
      {
        variety: variety,
        origin: origin,
        harvest-date: harvest-date,
        quantity: quantity,
        quality-grade: quality-grade,
        owner: tx-sender,
        for-sale: false,
        price: u0,
        metadata-uri: metadata-uri
      }
    )
    (var-set nft-nonce (+ nft-id u1))
    (ok nft-id)
  )
)

(define-public (list-for-sale (nft-id uint) (price uint))
  (let ((nft (unwrap! (map-get? rice-nfts {nft-id: nft-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get owner nft)) err-unauthorized)
    (ok (map-set rice-nfts {nft-id: nft-id}
      (merge nft {for-sale: true, price: price})
    ))
  )
)

(define-public (make-offer (nft-id uint) (price uint))
  (let (
    (nft (unwrap! (map-get? rice-nfts {nft-id: nft-id}) err-not-found))
    (offer-id (var-get offer-nonce))
  )
    (asserts! (get for-sale nft) err-not-for-sale)
    (map-set offers {offer-id: offer-id}
      {
        nft-id: nft-id,
        buyer: tx-sender,
        price: price,
        status: "pending",
        created-at: stacks-block-height
      }
    )
    (var-set offer-nonce (+ offer-id u1))
    (ok offer-id)
  )
)

(define-public (accept-offer (offer-id uint))
  (let (
    (offer (unwrap! (map-get? offers {offer-id: offer-id}) err-not-found))
    (nft (unwrap! (map-get? rice-nfts {nft-id: (get nft-id offer)}) err-not-found))
  )
    (asserts! (is-eq tx-sender (get owner nft)) err-unauthorized)
    (map-set rice-nfts {nft-id: (get nft-id offer)}
      (merge nft {owner: (get buyer offer), for-sale: false, price: u0})
    )
    (ok (map-set offers {offer-id: offer-id}
      (merge offer {status: "accepted"})
    ))
  )
)

(define-public (transfer-nft (nft-id uint) (recipient principal))
  (let ((nft (unwrap! (map-get? rice-nfts {nft-id: nft-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get owner nft)) err-unauthorized)
    (ok (map-set rice-nfts {nft-id: nft-id}
      (merge nft {owner: recipient, for-sale: false, price: u0})
    ))
  )
)
