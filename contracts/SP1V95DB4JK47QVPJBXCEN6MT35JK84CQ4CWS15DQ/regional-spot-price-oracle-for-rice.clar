(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))

(define-map price-feeds
  {region: (string-ascii 128), variety: (string-ascii 64)}
  {
    price: uint,
    last-updated: uint,
    oracle: principal,
    num-updates: uint
  }
)

(define-map authorized-oracles
  {oracle: principal}
  {authorized: bool, region: (string-ascii 128)}
)

(define-map price-history
  {region: (string-ascii 128), variety: (string-ascii 64), height: uint}
  {price: uint, timestamp: uint}
)

(define-read-only (get-price (region (string-ascii 128)) (variety (string-ascii 64)))
  (map-get? price-feeds {region: region, variety: variety})
)

(define-read-only (get-historical-price 
  (region (string-ascii 128)) 
  (variety (string-ascii 64)) 
  (height uint)
)
  (map-get? price-history {region: region, variety: variety, height: height})
)

(define-read-only (is-oracle-authorized (oracle principal))
  (match (map-get? authorized-oracles {oracle: oracle})
    oracle-data (get authorized oracle-data)
    false
  )
)

(define-public (authorize-oracle (oracle principal) (region (string-ascii 128)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set authorized-oracles {oracle: oracle}
      {authorized: true, region: region}
    ))
  )
)

(define-public (revoke-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set authorized-oracles {oracle: oracle}
      {authorized: false, region: ""}
    ))
  )
)

(define-public (update-price
  (region (string-ascii 128))
  (variety (string-ascii 64))
  (price uint)
)
  (let (
    (oracle-data (unwrap! (map-get? authorized-oracles {oracle: tx-sender}) err-unauthorized))
    (current-feed (map-get? price-feeds {region: region, variety: variety}))
    (prev-updates (match current-feed feed (get num-updates feed) u0))
  )
    (asserts! (get authorized oracle-data) err-unauthorized)
    (asserts! (is-eq (get region oracle-data) region) err-unauthorized)
    (asserts! (> price u0) err-invalid-params)
    (map-set price-history 
      {region: region, variety: variety, height: stacks-block-height}
      {price: price, timestamp: stacks-block-height}
    )
    (ok (map-set price-feeds {region: region, variety: variety}
      {
        price: price,
        last-updated: stacks-block-height,
        oracle: tx-sender,
        num-updates: (+ u1 prev-updates)
      }
    ))
  )
)

(define-public (batch-update-prices
  (region (string-ascii 128))
  (varieties (list 10 (string-ascii 64)))
  (prices (list 10 uint))
)
  (let ((oracle-data (unwrap! (map-get? authorized-oracles {oracle: tx-sender}) err-unauthorized)))
    (asserts! (get authorized oracle-data) err-unauthorized)
    (asserts! (is-eq (get region oracle-data) region) err-unauthorized)
    (ok true)
  )
)
