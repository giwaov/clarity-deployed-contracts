---
title: "Trait page-views"
draft: true
---
```
;; Page Views
(define-map views {page: (string-ascii 100), user: principal} {count: uint})
(define-public (track-view (page (string-ascii 100)))
  (let ((current (default-to u0 (get count (map-get? views {page: page, user: tx-sender})))))
    (map-set views {page: page, user: tx-sender} {count: (+ current u1)})
    (ok true)))
(define-read-only (get-views (page (string-ascii 100)) (user principal))
  (default-to u0 (get count (map-get? views {page: page, user: user}))))

```
