(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))

(define-map inventory-items
  {item-id: uint}
  {
    product-type: (string-ascii 64),
    owner: principal,
    quantity: uint,
    location: (string-ascii 128),
    quality-grade: (string-ascii 16),
    batch-number: (string-ascii 64),
    registered-at: uint,
    status: (string-ascii 32)
  }
)

(define-map certifications
  {cert-id: uint}
  {
    item-id: uint,
    cert-type: (string-ascii 64),
    issuer: principal,
    issued-at: uint,
    expires-at: uint,
    valid: bool
  }
)

(define-data-var item-nonce uint u0)
(define-data-var cert-nonce uint u0)

(define-read-only (get-inventory-item (item-id uint))
  (map-get? inventory-items {item-id: item-id})
)

(define-read-only (get-certification (cert-id uint))
  (map-get? certifications {cert-id: cert-id})
)

(define-public (register-inventory
  (product-type (string-ascii 64))
  (quantity uint)
  (location (string-ascii 128))
  (quality-grade (string-ascii 16))
  (batch-number (string-ascii 64))
)
  (let ((item-id (var-get item-nonce)))
    (asserts! (> quantity u0) err-invalid-params)
    (map-set inventory-items {item-id: item-id}
      {
        product-type: product-type,
        owner: tx-sender,
        quantity: quantity,
        location: location,
        quality-grade: quality-grade,
        batch-number: batch-number,
        registered-at: stacks-block-height,
        status: "active"
      }
    )
    (var-set item-nonce (+ item-id u1))
    (ok item-id)
  )
)

(define-public (issue-certification
  (item-id uint)
  (cert-type (string-ascii 64))
  (duration uint)
)
  (let (
    (item (unwrap! (map-get? inventory-items {item-id: item-id}) err-not-found))
    (cert-id (var-get cert-nonce))
  )
    (map-set certifications {cert-id: cert-id}
      {
        item-id: item-id,
        cert-type: cert-type,
        issuer: tx-sender,
        issued-at: stacks-block-height,
        expires-at: (+ stacks-block-height duration),
        valid: true
      }
    )
    (var-set cert-nonce (+ cert-id u1))
    (ok cert-id)
  )
)

(define-public (transfer-inventory (item-id uint) (new-owner principal))
  (let ((item (unwrap! (map-get? inventory-items {item-id: item-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get owner item)) err-unauthorized)
    (ok (map-set inventory-items {item-id: item-id}
      (merge item {owner: new-owner})
    ))
  )
)

(define-public (update-inventory-status (item-id uint) (new-status (string-ascii 32)))
  (let ((item (unwrap! (map-get? inventory-items {item-id: item-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get owner item)) err-unauthorized)
    (ok (map-set inventory-items {item-id: item-id}
      (merge item {status: new-status})
    ))
  )
)
