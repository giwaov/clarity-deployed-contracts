(define-non-fungible-token drn-nft uint)

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-LISTING-EXISTS (err u102))
(define-constant ERR-NOT-LISTED (err u103))
(define-constant ERR-EXPIRED (err u104))
(define-constant ERR-PRICE-MISMATCH (err u105))
(define-constant ERR-TOKEN-MISMATCH (err u106))
(define-constant ERR-INVALID-PAYMENT (err u107))

(define-data-var token-id-nonce uint u0)
(define-data-var royalty-address principal tx-sender)
(define-data-var royalty-percent uint u250)

(define-map token-uri uint (string-ascii 256))
(define-map listings uint {
  price: uint,
  expires: uint,
  token: (optional principal),
  benchmark: uint
})
(define-map historical-price uint uint)

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce))
)

(define-read-only (get-token-uri (token uint))
  (ok (map-get? token-uri token))
)

(define-read-only (get-owner (token uint))
  (ok (nft-get-owner? drn-nft token))
)

(define-read-only (get-listing (token uint))
  (ok (map-get? listings token))
)

(define-read-only (get-royalty-info (token uint) (sale-price uint))
  (let (
    (hist-price (default-to u0 (map-get? historical-price token)))
    (taxable (if (> sale-price hist-price) (- sale-price hist-price) u0))
    (royalty (/ (* taxable (var-get royalty-percent)) u10000))
  )
    (ok {recipient: (var-get royalty-address), amount: royalty})
  )
)

(define-public (mint (recipient principal) (uri (string-ascii 256)))
  (let ((new-id (+ (var-get token-id-nonce) u1)))
    (try! (nft-mint? drn-nft new-id recipient))
    (map-set token-uri new-id uri)
    (var-set token-id-nonce new-id)
    (ok new-id)
  )
)

(define-public (transfer (token uint) (sender principal) (recipient principal))
  (let ((owner (unwrap! (nft-get-owner? drn-nft token) ERR-NOT-FOUND)))
    (asserts! (or (is-eq tx-sender owner) (is-eq tx-sender sender)) ERR-NOT-AUTHORIZED)
    (try! (nft-transfer? drn-nft token sender recipient))
    (ok true)
  )
)

(define-public (list-item (token uint) (price uint) (expires uint) (payment-token (optional principal)))
  (let ((owner (unwrap! (nft-get-owner? drn-nft token) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
    (asserts! (> price u0) ERR-INVALID-PAYMENT)
    (asserts! (> expires stacks-block-time) ERR-EXPIRED)
    (map-set listings token {
      price: price,
      expires: expires,
      token: payment-token,
      benchmark: (default-to u0 (map-get? historical-price token))
    })
    (ok true)
  )
)

(define-public (delist-item (token uint))
  (let ((owner (unwrap! (nft-get-owner? drn-nft token) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? listings token)) ERR-NOT-LISTED)
    (map-delete listings token)
    (ok true)
  )
)

(define-public (buy-item (token uint) (price uint) (payment-token (optional principal)))
  (let (
    (listing (unwrap! (map-get? listings token) ERR-NOT-LISTED))
    (seller (unwrap! (nft-get-owner? drn-nft token) ERR-NOT-FOUND))
    (royalty-info (unwrap! (get-royalty-info token price) ERR-NOT-FOUND))
  )
    (asserts! (is-eq price (get price listing)) ERR-PRICE-MISMATCH)
    (asserts! (is-eq payment-token (get token listing)) ERR-TOKEN-MISMATCH)
    (asserts! (< stacks-block-time (get expires listing)) ERR-EXPIRED)
    (if (is-some payment-token)
      (begin
        (try! (stx-transfer? (get amount royalty-info) tx-sender (get recipient royalty-info)))
        (try! (stx-transfer? (- price (get amount royalty-info)) tx-sender seller))
      )
      (begin
        (try! (stx-transfer? (get amount royalty-info) tx-sender (get recipient royalty-info)))
        (try! (stx-transfer? (- price (get amount royalty-info)) tx-sender seller))
      )
    )
    (try! (nft-transfer? drn-nft token seller tx-sender))
    (map-set historical-price token price)
    (map-delete listings token)
    (ok true)
  )
)

(define-public (set-royalty (recipient principal) (percent uint))
  (begin
    (asserts! (is-eq tx-sender (var-get royalty-address)) ERR-NOT-AUTHORIZED)
    (var-set royalty-address recipient)
    (var-set royalty-percent percent)
    (ok true)
  )
)
