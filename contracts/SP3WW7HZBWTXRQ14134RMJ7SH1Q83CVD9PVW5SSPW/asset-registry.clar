;; Asset Registry Contract

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))

(define-map assets
  (string-ascii 32)
  {
    name: (string-ascii 64),
    enabled: bool
  }
)

(define-read-only (get-asset-info (symbol (string-ascii 32)))
  (map-get? assets symbol)
)

(define-public (register-asset (symbol (string-ascii 32)) (name (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set assets symbol { name: name, enabled: true })
    (ok true)
  )
)
