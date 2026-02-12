---
title: "Trait math-helpers-v1"
draft: true
---
```
;; title: math-helpers
;; summary: Small reusable math helpers for other contracts
;; version: 1

;; constants
(define-constant err-underflow (err u100))

;; read only functions

;; add two uints
(define-read-only (u-add (a uint) (b uint))
  (ok (+ a b)))

;; subtract two uints with underflow protection
(define-read-only (u-sub (a uint) (b uint))
  (if (>= a b)
      (ok (- a b))
      err-underflow))

;; return the smaller of two uints
(define-read-only (u-min (a uint) (b uint))
  (ok (if (< a b) a b)))

;; return the larger of two uints
(define-read-only (u-max (a uint) (b uint))
  (ok (if (> a b) a b)))

```
