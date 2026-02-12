(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))

(define-map registry-entries
  (string-ascii 64)
  {
    owner: principal,
    value: (string-utf8 256),
    created-at: uint,
  }
)

(define-public (register-entry
    (key (string-ascii 64))
    (value (string-utf8 256))
  )
  (begin
    (asserts! (> (len key) u0) (err u1))
    (asserts! (> (len value) u0) (err u2))
    (map-set registry-entries key {
      owner: tx-sender,
      value: value,
      created-at: stacks-block-height,
    })
    (ok true)
  )
)

(define-public (update-entry
    (key (string-ascii 64))
    (new-value (string-utf8 256))
  )
  (let ((entry (unwrap! (map-get? registry-entries key) (err u404))))
    (asserts! (is-eq (get owner entry) tx-sender) err-owner-only)
    (asserts! (> (len new-value) u0) (err u3))
    (map-set registry-entries key (merge entry { value: new-value }))
    (ok true)
  )
)

(define-read-only (get-entry (key (string-ascii 64)))
  (ok (map-get? registry-entries key))
)
