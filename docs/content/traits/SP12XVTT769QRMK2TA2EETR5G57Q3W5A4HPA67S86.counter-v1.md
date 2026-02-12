---
title: "Trait counter-v1"
draft: true
---
```
;; SPDX-License-Identifier: MIT

(define-data-var counter-0 uint u0)
(define-data-var counter-1 uint u0)
(define-data-var counter-2 uint u0)
(define-data-var counter-3 uint u0)
(define-data-var counter-4 uint u0)
(define-data-var counter-5 uint u0)
(define-data-var counter-6 uint u0)
(define-data-var counter-7 uint u0)
(define-data-var counter-8 uint u0)
(define-data-var counter-9 uint u0)
(define-data-var counter-10 uint u0)

(define-public (click-0)
  (ok (var-set counter-0 (+ (var-get counter-0) u1))))

(define-public (click-1)
  (ok (var-set counter-1 (+ (var-get counter-1) u1))))

(define-public (click-2)
  (ok (var-set counter-2 (+ (var-get counter-2) u1))))

(define-public (click-3)
  (ok (var-set counter-3 (+ (var-get counter-3) u1))))

(define-public (click-4)
  (ok (var-set counter-4 (+ (var-get counter-4) u1))))

(define-public (click-5)
  (ok (var-set counter-5 (+ (var-get counter-5) u1))))

(define-public (click-6)
  (ok (var-set counter-6 (+ (var-get counter-6) u1))))

(define-public (click-7)
  (ok (var-set counter-7 (+ (var-get counter-7) u1))))

(define-public (click-8)
  (ok (var-set counter-8 (+ (var-get counter-8) u1))))

(define-public (click-9)
  (ok (var-set counter-9 (+ (var-get counter-9) u1))))

(define-public (click-10)
  (ok (var-set counter-10 (+ (var-get counter-10) u1))))

(define-read-only (get-counter-0)
  (ok (var-get counter-0)))

(define-read-only (get-counter-1)
  (ok (var-get counter-1)))

(define-read-only (get-counter-2)
  (ok (var-get counter-2)))

(define-read-only (get-counter-3)
  (ok (var-get counter-3)))

(define-read-only (get-counter-4)
  (ok (var-get counter-4)))

(define-read-only (get-counter-5)
  (ok (var-get counter-5)))

(define-read-only (get-counter-6)
  (ok (var-get counter-6)))

(define-read-only (get-counter-7)
  (ok (var-get counter-7)))

(define-read-only (get-counter-8)
  (ok (var-get counter-8)))

(define-read-only (get-counter-9)
  (ok (var-get counter-9)))

(define-read-only (get-counter-10)
  (ok (var-get counter-10)))

(define-read-only (get-all-counters)
  (ok {
    counter-0: (var-get counter-0),
    counter-1: (var-get counter-1),
    counter-2: (var-get counter-2),
    counter-3: (var-get counter-3),
    counter-4: (var-get counter-4),
    counter-5: (var-get counter-5),
    counter-6: (var-get counter-6),
    counter-7: (var-get counter-7),
    counter-8: (var-get counter-8),
    counter-9: (var-get counter-9),
    counter-10: (var-get counter-10)
  }))
```
