(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ASSET-NOT-FOUND (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))

(define-map custodied-assets
  { asset-id: (string-ascii 50), owner: principal }
  {
    quantity: uint,
    asset-type: (string-ascii 30),
    cusip: (string-ascii 20),
    isin: (string-ascii 20),
    tokenized: bool,
    custodian: principal,
    registered-at: uint
  }
)

(define-map asset-balances
  { asset-id: (string-ascii 50), holder: principal }
  uint
)

(define-data-var dtcc-operator principal tx-sender)

(define-public (register-asset
  (asset-id (string-ascii 50))
  (owner principal)
  (quantity uint)
  (asset-type (string-ascii 30))
  (cusip (string-ascii 20))
  (isin (string-ascii 20))
)
  (begin
    (asserts! (is-eq tx-sender (var-get dtcc-operator)) ERR-NOT-AUTHORIZED)
    (map-set custodied-assets
      { asset-id: asset-id, owner: owner }
      {
        quantity: quantity,
        asset-type: asset-type,
        cusip: cusip,
        isin: isin,
        tokenized: false,
        custodian: tx-sender,
        registered-at: stacks-block-height
      }
    )
    (ok (map-set asset-balances { asset-id: asset-id, holder: owner } quantity))
  )
)

(define-public (tokenize-asset (asset-id (string-ascii 50)) (owner principal))
  (let (
    (asset (unwrap! (map-get? custodied-assets { asset-id: asset-id, owner: owner }) ERR-ASSET-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (var-get dtcc-operator)) ERR-NOT-AUTHORIZED)
    (ok (map-set custodied-assets
      { asset-id: asset-id, owner: owner }
      (merge asset { tokenized: true })
    ))
  )
)

(define-public (transfer-asset (asset-id (string-ascii 50)) (amount uint) (recipient principal))
  (let (
    (sender-balance (default-to u0 (map-get? asset-balances { asset-id: asset-id, holder: tx-sender })))
    (recipient-balance (default-to u0 (map-get? asset-balances { asset-id: asset-id, holder: recipient })))
  )
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
    (map-set asset-balances { asset-id: asset-id, holder: tx-sender } (- sender-balance amount))
    (ok (map-set asset-balances { asset-id: asset-id, holder: recipient } (+ recipient-balance amount)))
  )
)

(define-read-only (get-asset-info (asset-id (string-ascii 50)) (owner principal))
  (map-get? custodied-assets { asset-id: asset-id, owner: owner })
)

(define-read-only (get-balance (asset-id (string-ascii 50)) (holder principal))
  (ok (default-to u0 (map-get? asset-balances { asset-id: asset-id, holder: holder })))
)

(define-public (update-quantity (asset-id (string-ascii 50)) (owner principal) (new-quantity uint))
  (let (
    (asset (unwrap! (map-get? custodied-assets { asset-id: asset-id, owner: owner }) ERR-ASSET-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (var-get dtcc-operator)) ERR-NOT-AUTHORIZED)
    (ok (map-set custodied-assets
      { asset-id: asset-id, owner: owner }
      (merge asset { quantity: new-quantity })
    ))
  )
)
