(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ARTWORK-NOT-FOUND (err u101))
(define-constant ERR-LISTING-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))

(define-map artworks
  { artwork-id: uint }
  {
    title: (string-ascii 100),
    artist: (string-ascii 100),
    creation-year: uint,
    medium: (string-ascii 50),
    total-shares: uint,
    owner: principal,
    verified: bool,
    listed: bool
  }
)

(define-map artwork-shares
  { artwork-id: uint, holder: principal }
  uint
)

(define-map listings
  { listing-id: uint }
  {
    artwork-id: uint,
    seller: principal,
    shares-amount: uint,
    price-per-share: uint,
    active: bool,
    created-at: uint
  }
)

(define-data-var artwork-nonce uint u0)
(define-data-var listing-nonce uint u0)

(define-public (tokenize-artwork
  (title (string-ascii 100))
  (artist (string-ascii 100))
  (creation-year uint)
  (medium (string-ascii 50))
  (total-shares uint)
)
  (let ((artwork-id (var-get artwork-nonce)))
    (map-set artworks
      { artwork-id: artwork-id }
      {
        title: title,
        artist: artist,
        creation-year: creation-year,
        medium: medium,
        total-shares: total-shares,
        owner: tx-sender,
        verified: false,
        listed: false
      }
    )
    (map-set artwork-shares { artwork-id: artwork-id, holder: tx-sender } total-shares)
    (var-set artwork-nonce (+ artwork-id u1))
    (ok artwork-id)
  )
)

(define-public (create-listing (artwork-id uint) (shares uint) (price uint))
  (let (
    (listing-id (var-get listing-nonce))
    (holder-shares (default-to u0 (map-get? artwork-shares { artwork-id: artwork-id, holder: tx-sender })))
  )
    (asserts! (>= holder-shares shares) ERR-INSUFFICIENT-FUNDS)
    (map-set listings
      { listing-id: listing-id }
      {
        artwork-id: artwork-id,
        seller: tx-sender,
        shares-amount: shares,
        price-per-share: price,
        active: true,
        created-at: stacks-block-height
      }
    )
    (var-set listing-nonce (+ listing-id u1))
    (ok listing-id)
  )
)

(define-public (purchase-shares (listing-id uint) (shares uint))
  (let (
    (listing (unwrap! (map-get? listings { listing-id: listing-id }) ERR-LISTING-NOT-FOUND))
    (seller-shares (default-to u0 (map-get? artwork-shares { artwork-id: (get artwork-id listing), holder: (get seller listing) })))
    (buyer-shares (default-to u0 (map-get? artwork-shares { artwork-id: (get artwork-id listing), holder: tx-sender })))
  )
    (asserts! (get active listing) ERR-LISTING-NOT-FOUND)
    (asserts! (>= (get shares-amount listing) shares) ERR-INSUFFICIENT-FUNDS)
    (map-set artwork-shares
      { artwork-id: (get artwork-id listing), holder: (get seller listing) }
      (- seller-shares shares)
    )
    (map-set artwork-shares
      { artwork-id: (get artwork-id listing), holder: tx-sender }
      (+ buyer-shares shares)
    )
    (ok true)
  )
)

(define-read-only (get-artwork-info (artwork-id uint))
  (map-get? artworks { artwork-id: artwork-id })
)

(define-read-only (get-shares (artwork-id uint) (holder principal))
  (ok (default-to u0 (map-get? artwork-shares { artwork-id: artwork-id, holder: holder })))
)

(define-read-only (get-listing-info (listing-id uint))
  (map-get? listings { listing-id: listing-id })
)

(define-public (verify-artwork (artwork-id uint))
  (let ((artwork (unwrap! (map-get? artworks { artwork-id: artwork-id }) ERR-ARTWORK-NOT-FOUND)))
    (ok (map-set artworks
      { artwork-id: artwork-id }
      (merge artwork { verified: true })
    ))
  )
)
