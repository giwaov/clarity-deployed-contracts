---
title: "Trait identity-registry"
draft: true
---
```
;; Identity Registry Contract

(define-constant err-already-registered (err u100))
(define-constant err-not-found (err u101))

(define-map identities
  principal
  {
    did: (string-ascii 256),
    registered-at: uint,
    active: bool
  }
)

(define-read-only (get-identity (user principal))
  (map-get? identities user)
)

(define-public (register-identity (did (string-ascii 256)))
  (begin
    (asserts! (is-none (map-get? identities tx-sender)) err-already-registered)
    (map-set identities tx-sender {
      did: did,
      registered-at: block-height,
      active: true
    })
    (ok true)
  )
)

(define-public (update-identity (new-did (string-ascii 256)))
  (let ((identity (unwrap! (map-get? identities tx-sender) err-not-found)))
    (map-set identities tx-sender (merge identity { did: new-did }))
    (ok true)
  )
)

```
