---
title: "Trait profile-manager"
draft: true
---
```
;; User Registry - Register users
(define-map users principal {username: (string-ascii 50), verified: bool})

(define-public (register-user (username (string-ascii 50)))
  (begin
    (map-set users tx-sender {username: username, verified: false})
    (ok true)))

(define-read-only (get-user (user principal))
  (map-get? users user))

```
