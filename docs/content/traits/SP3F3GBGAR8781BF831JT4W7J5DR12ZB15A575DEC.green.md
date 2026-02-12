---
title: "Trait green"
draft: true
---
```
(use-trait ft-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)
(use-trait xyk-pool-trait-v1-2 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)
(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))
(define-public (lantern
    (a1 (optional <ft-trait>))
    (a2 (optional <ft-trait>))
    (a3 (optional uint))
    (a4 (optional uint))
    (p1 (optional principal))
    (a5 (optional uint))
    (a6 (optional principal))
    (xt2 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (xp2 (optional (tuple (a <xyk-pool-trait-v1-2>))))
  )
  (let (
    (r1 
      (if (and 
            (is-some a1)
            (is-some a2)
            (is-some a3)
            (is-some a4))
        (some (unwrap! (element-at (try! (call-a
          (unwrap! a1 e5)
          (unwrap! a2 e5)
          (unwrap! a3 e5)
          (unwrap! a4 e5)
          p1)) u0) e2))
        none))
    (a-for-r2 
      (if (is-some r1)
        (unwrap! r1 e3)
        (unwrap! a3 e5)))
    (r2
      (if (and
            (is-some a5)
            (is-some xt2)
            (is-some xp2))
        (some (try! (call-b
          a-for-r2
          (unwrap! a5 e5)
          a6
          (unwrap! xt2 e5)
          (unwrap! xp2 e5))))
        none))
  )
    (begin
      (asserts! (or (is-some r1) (is-some r2)) e5)
      (ok {
        r1: r1,
        r2: r2
      })
    )
  )
)

(define-private (call-a
    (tx <ft-trait>)
    (ty <ft-trait>)
    (dy uint)
    (min-dx uint)
    (p (optional principal))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.wrapper-arkadiko-v-1-2
    swap-y-for-x
    tx
    ty
    dy
    min-dx
    p)
)

(define-private (call-b
    (a uint)
    (m uint)
    (p (optional principal))
    (xt (tuple (a <ft-trait>) (b <ft-trait>)))
    (xp (tuple (a <xyk-pool-trait-v1-2>)))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-swap-helper-v-1-3
    swap-helper-a
    a
    m
    p
    xt
    xp)
)
```
