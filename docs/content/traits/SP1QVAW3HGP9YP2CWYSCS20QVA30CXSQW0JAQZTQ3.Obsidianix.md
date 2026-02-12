---
title: "Trait Obsidianix"
draft: true
---
```
;; title: Obsidianix
;; version:
;; summary:
;; description:

;; traits
;;

;; Global Counters
(define-data-var total-members uint u0)
(define-data-var total-orders uint u0)
(define-data-var total-revenue uint u0)
(define-public (update-counters (members uint) (orders uint) (revenue uint))
  (begin
    (var-set total-members members)
    (var-set total-orders orders)
    (var-set total-revenue revenue)
    (ok true)))
(define-read-only (get-counters)
  (ok {members: (var-get total-members), orders: (var-get total-orders), revenue: (var-get total-revenue)}))
```
