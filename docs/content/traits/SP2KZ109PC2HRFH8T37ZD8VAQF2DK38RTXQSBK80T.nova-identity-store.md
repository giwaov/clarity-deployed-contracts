---
title: "Trait nova-identity-store"
draft: true
---
```

;; nova-identity-store.clar
;; Stores DID-like attributes or profile data on-chain.
;; CLARITY VERSION: 2

(define-constant ERR-NOT-AUTHORIZED (err u100))

(define-map identities
    principal
    {
        name: (string-utf8 64),
        bio: (string-utf8 256),
        avatar-url: (string-utf8 128),
        verified: bool
    }
)

(define-data-var admin principal tx-sender)

(define-public (set-profile (name (string-utf8 64)) (bio (string-utf8 256)) (avatar-url (string-utf8 128)))
    (let (
        (sender tx-sender)
        (current (default-to {verified: false} (get-profile-raw sender)))
    )
    (map-set identities sender {
        name: name,
        bio: bio,
        avatar-url: avatar-url,
        verified: (get verified current)
    })
    (ok true))
)

(define-read-only (get-profile (user principal))
    (map-get? identities user)
)

(define-private (get-profile-raw (user principal))
    (map-get? identities user)
)

(define-public (verify-user (user principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
        (match (map-get? identities user)
            profile (begin
                (map-set identities user (merge profile { verified: true }))
                (ok true)
            )
            (err u101) ;; Profile not found
        )
    )
)

```
