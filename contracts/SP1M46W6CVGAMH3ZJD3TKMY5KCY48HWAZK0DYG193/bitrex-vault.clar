(define-constant CONTRACT-VERSION u1)

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))
(define-constant ERR-ZERO-AMOUNT (err u102))
(define-constant ERR-INVALID-SHARES (err u103))
(define-constant ERR-VAULT-PAUSED (err u104))
(define-constant ERR-TRANSFER-FAILED (err u105))
(define-constant ERR-SHARE-CALCULATION-FAILED (err u106))

(define-data-var contract-owner principal tx-sender)
(define-data-var total-shares uint u0)
(define-data-var total-assets uint u0)
(define-data-var vault-paused bool false)

(define-map user-shares principal uint)
(define-map vault-config {key: (string-ascii 32)} {value: uint})

(map-set vault-config {key: "min-deposit"} {value: u100000})
(map-set vault-config {key: "reserve-ratio"} {value: u500})

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-read-only (get-share-price)
  (let
    (
      (total-supply (var-get total-shares))
      (total-value (var-get total-assets))
    )
    (if (is-eq total-supply u0)
      (ok u100000000)
      (ok (/ (* total-value u100000000) total-supply))
    )
  )
)

(define-read-only (shares-to-assets (shares uint))
  (let
    (
      (share-price (unwrap! (get-share-price) ERR-SHARE-CALCULATION-FAILED))
    )
    (ok (/ (* shares share-price) u100000000))
  )
)

(define-read-only (assets-to-shares (assets uint))
  (let
    (
      (share-price (unwrap! (get-share-price) ERR-SHARE-CALCULATION-FAILED))
    )
    (ok (/ (* assets u100000000) share-price))
  )
)

(define-read-only (get-user-shares (user principal))
  (ok (default-to u0 (map-get? user-shares user)))
)

(define-read-only (get-user-value (user principal))
  (let
    (
      (user-share-balance (default-to u0 (map-get? user-shares user)))
    )
    (shares-to-assets user-share-balance)
  )
)

(define-read-only (get-total-shares)
  (ok (var-get total-shares))
)

(define-read-only (get-total-assets)
  (ok (var-get total-assets))
)

(define-read-only (is-paused)
  (ok (var-get vault-paused))
)

(define-public (deposit (amount uint))
  (let
    (
      (depositor tx-sender)
      (min-deposit (get value (map-get? vault-config {key: "min-deposit"})))
      (shares-to-mint (unwrap! (assets-to-shares amount) ERR-SHARE-CALCULATION-FAILED))
      (current-shares (default-to u0 (map-get? user-shares depositor)))
    )
    (asserts! (not (var-get vault-paused)) ERR-VAULT-PAUSED)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (>= amount (default-to u0 min-deposit)) ERR-INSUFFICIENT-BALANCE)
    (map-set user-shares depositor (+ current-shares shares-to-mint))
    (var-set total-shares (+ (var-get total-shares) shares-to-mint))
    (var-set total-assets (+ (var-get total-assets) amount))
    (ok shares-to-mint)
  )
)

(define-public (withdraw (shares uint))
  (let
    (
      (withdrawer tx-sender)
      (current-shares (default-to u0 (map-get? user-shares withdrawer)))
      (assets-to-return (unwrap! (shares-to-assets shares) ERR-SHARE-CALCULATION-FAILED))
    )
    (asserts! (not (var-get vault-paused)) ERR-VAULT-PAUSED)
    (asserts! (> shares u0) ERR-ZERO-AMOUNT)
    (asserts! (>= current-shares shares) ERR-INSUFFICIENT-BALANCE)
    (map-set user-shares withdrawer (- current-shares shares))
    (var-set total-shares (- (var-get total-shares) shares))
    (var-set total-assets (- (var-get total-assets) assets-to-return))
    (ok assets-to-return)
  )
)

(define-public (toggle-pause)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set vault-paused (not (var-get vault-paused)))
    (ok (var-get vault-paused))
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok new-owner)
  )
)

(define-public (update-config (key (string-ascii 32)) (value uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (map-set vault-config {key: key} {value: value})
    (ok value)
  )
)

(define-read-only (get-vault-info)
  (ok {
    total-shares: (var-get total-shares),
    total-assets: (var-get total-assets),
    share-price: (unwrap-panic (get-share-price)),
    paused: (var-get vault-paused),
    contract-version: CONTRACT-VERSION
  })
)
