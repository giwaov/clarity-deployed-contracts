---
title: "Trait function-v1"
draft: true
---
```
;; SPDX-License-Identifier: MIT

(define-data-var fn-get uint u0)
(define-data-var fn-push uint u0)
(define-data-var fn-dep uint u0)
(define-data-var fn-mine uint u0)
(define-data-var fn-call uint u0)
(define-data-var fn-set uint u0)
(define-data-var fn-with uint u0)
(define-data-var fn-main uint u0)
(define-data-var fn-pull uint u0)
(define-data-var fn-count uint u0)
(define-data-var fn-pay uint u0)

(define-public (click-0)
  (ok (var-set fn-get (+ (var-get fn-get) u1))))

(define-public (click-1)
  (ok (var-set fn-push (+ (var-get fn-push) u1))))

(define-public (click-2)
  (ok (var-set fn-dep (+ (var-get fn-dep) u1))))

(define-public (click-3)
  (ok (var-set fn-mine (+ (var-get fn-mine) u1))))

(define-public (click-4)
  (ok (var-set fn-call (+ (var-get fn-call) u1))))

(define-public (click-5)
  (ok (var-set fn-set (+ (var-get fn-set) u1))))

(define-public (click-6)
  (ok (var-set fn-with (+ (var-get fn-with) u1))))

(define-public (click-7)
  (ok (var-set fn-main (+ (var-get fn-main) u1))))

(define-public (click-8)
  (ok (var-set fn-pull (+ (var-get fn-pull) u1))))

(define-public (click-9)
  (ok (var-set fn-count (+ (var-get fn-count) u1))))

(define-public (click-10)
  (ok (var-set fn-pay (+ (var-get fn-pay) u1))))

(define-read-only (get-counter-0)
  (ok (var-get fn-get)))

(define-read-only (get-counter-1)
  (ok (var-get fn-push)))

(define-read-only (get-counter-2)
  (ok (var-get fn-dep)))

(define-read-only (get-counter-3)
  (ok (var-get fn-mine)))

(define-read-only (get-counter-4)
  (ok (var-get fn-call)))

(define-read-only (get-counter-5)
  (ok (var-get fn-set)))

(define-read-only (get-counter-6)
  (ok (var-get fn-with)))

(define-read-only (get-counter-7)
  (ok (var-get fn-main)))

(define-read-only (get-counter-8)
  (ok (var-get fn-pull)))

(define-read-only (get-counter-9)
  (ok (var-get fn-count)))

(define-read-only (get-counter-10)
  (ok (var-get fn-pay)))

(define-read-only (get-all-counters)
  (ok {
    counter-0: (var-get fn-get),
    counter-1: (var-get fn-push),
    counter-2: (var-get fn-dep),
    counter-3: (var-get fn-mine),
    counter-4: (var-get fn-call),
    counter-5: (var-get fn-set),
    counter-6: (var-get fn-with),
    counter-7: (var-get fn-main),
    counter-8: (var-get fn-pull),
    counter-9: (var-get fn-count),
    counter-10: (var-get fn-pay)
  }))
```
