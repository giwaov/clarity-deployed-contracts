---
title: "Trait whitelist-manager"
draft: true
---
```
;; Whitelist Manager - Manage access lists

(define-map whitelist { user: principal, list-name: (string-ascii 30) } { approved: bool })

(define-public (add-to-whitelist (user principal) (list-name (string-ascii 30)))
  (begin
    (map-set whitelist { user: user, list-name: list-name } { approved: true })
    (ok true)
  )
)

(define-public (remove-from-whitelist (user principal) (list-name (string-ascii 30)))
  (begin
    (map-delete whitelist { user: user, list-name: list-name })
    (ok true)
  )
)

(define-read-only (is-whitelisted (user principal) (list-name (string-ascii 30)))
  (default-to false (get approved (map-get? whitelist { user: user, list-name: list-name })))
)

```
