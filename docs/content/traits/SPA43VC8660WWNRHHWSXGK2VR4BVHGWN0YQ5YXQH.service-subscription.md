---
title: "Trait service-subscription"
draft: true
---
```
;; service-subscription
;; Digital Identity & Verification

(define-map profiles
  { user: principal }
  { handle: (string-ascii 50), bio: (string-ascii 200), verified: bool }
)

(define-map credentials
  { id: uint }
  { issuer: principal, holder: principal, type: (string-ascii 32), valid-until: uint }
)

(define-public (register-profile (handle (string-ascii 50)) (bio (string-ascii 200)))
  (ok (map-set profiles { user: tx-sender } { handle: handle, bio: bio, verified: false }))
)

(define-public (verify-user (user principal))
  (begin
    ;; In real app, check authorization
    (let ((profile (unwrap! (map-get? profiles { user: user }) (err u404))))
      (ok (map-set profiles { user: user } (merge profile { verified: true })))
    )
  )
)
```
