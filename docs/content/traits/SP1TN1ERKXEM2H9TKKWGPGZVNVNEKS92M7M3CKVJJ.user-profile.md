---
title: "Trait user-profile"
draft: true
---
```
;; title: user-profile
;; summary: A metadata registry for Stacks BNS identities.
;; description: Allows users to attach a bio, website, and avatar to their STX address.

;; data maps
;;
(define-map profiles
    principal
    {
        bio: (string-utf8 140),
        website: (string-ascii 256),
        avatar-url: (string-ascii 256)
    }
)

;; public functions
;;

;; @desc Update or create the profile for the tx-sender.
;; @param bio A short bio (max 140 utf8 chars).
;; @param website An optional website URL.
;; @param avatar-url An optional avatar image URL.
(define-public (update-profile (bio (string-utf8 140)) (website (string-ascii 256)) (avatar-url (string-ascii 256)))
    (begin
        (map-set profiles tx-sender {
            bio: bio,
            website: website,
            avatar-url: avatar-url
        })
        (ok true)
    )
)

;; read only functions
;;

;; @desc Get the profile for a specific principal.
;; @param user The principal to query.
(define-read-only (get-profile (user principal))
    (map-get? profiles user)
)

```
