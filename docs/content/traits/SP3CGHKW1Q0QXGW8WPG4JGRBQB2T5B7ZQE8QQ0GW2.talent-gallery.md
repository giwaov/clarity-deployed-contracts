---
title: "Trait talent-gallery"
draft: true
---
```
;; Portfolio Showcase - Showcase work
(define-map portfolio-items {owner: principal, item-id: uint} {title: (string-ascii 100), url: (string-ascii 200)})

(define-public (add-item (item-id uint) (title (string-ascii 100)) (url (string-ascii 200)))
  (begin
    (map-set portfolio-items {owner: tx-sender, item-id: item-id} {title: title, url: url})
    (ok true)))

(define-read-only (get-item (owner principal) (item-id uint))
  (map-get? portfolio-items {owner: owner, item-id: item-id}))

```
