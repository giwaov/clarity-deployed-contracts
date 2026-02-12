---
title: "Trait permission-handler"
draft: true
---
```
;; Access Control - Manage access
(define-map access-list {resource: (string-ascii 50), user: principal} {granted: bool})

(define-public (grant-access (resource (string-ascii 50)) (user principal))
  (begin
    (map-set access-list {resource: resource, user: user} {granted: true})
    (ok true)))

(define-read-only (has-access (resource (string-ascii 50)) (user principal))
  (default-to false (get granted (map-get? access-list {resource: resource, user: user}))))

```
