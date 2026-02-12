---
title: "Trait ju"
draft: true
---
```
(use-trait ft-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)
(use-trait xyk-pool-trait-v1-2 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)
(use-trait share-fee-to-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)
(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))
(define-public (hu
    (a1 (optional uint))
    (a2 (optional uint))
    (a3 (optional principal))
    (a4 (optional bool))
    (xt1 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (xp1 (optional (tuple (a <xyk-pool-trait-v1-2>))))
    (vt1 (optional (tuple (a <ft-trait>) (b <ft-trait>) (c <ft-trait>) (d <ft-trait>))))
    (sft1 (optional <share-fee-to-trait>))
    (a5 (optional <ft-trait>))
    (a6 (optional <ft-trait>))
    (a7 (optional uint))
    (a8 (optional uint))
    (p2 (optional principal))
  )
  (let (
    (r1 
      (if (and 
            (is-some a1)
            (is-some a2)
            (is-some a4)
            (is-some xt1)
            (is-some xp1)
            (is-some vt1)
            (is-some sft1))
        (some (try! (call-a
          (unwrap! a1 e5)
          (unwrap! a2 e5)
          a3
          (unwrap! a4 e5)
          (unwrap! xt1 e5)
          (unwrap! xp1 e5)
          (unwrap! vt1 e5)
          (unwrap! sft1 e5))))
        none))
    (a-for-r2 
      (if (is-some r1)
        (unwrap! r1 e3)
        (unwrap! a1 e5)))
    (r2
      (if (and
            (is-some a5)
            (is-some a6)
            (is-some a7)
            (is-some a8))
        (some (unwrap! (element-at (try! (call-b
          (unwrap! a5 e5)
          (unwrap! a6 e5)
          a-for-r2
          (unwrap! a7 e5)
          (unwrap! a8 e5)
          p2)) u1) e2))
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
    (a uint)
    (m uint)
    (p (optional principal))
    (sr bool)
    (xt (tuple (a <ft-trait>) (b <ft-trait>)))
    (xp (tuple (a <xyk-pool-trait-v1-2>)))
    (vt (tuple (a <ft-trait>) (b <ft-trait>) (c <ft-trait>) (d <ft-trait>)))
    (sft <share-fee-to-trait>)
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-xyk-velar-v-1-4
    swap-helper-c
    a
    m
    p
    sr
    xt
    xp
    vt
    sft)
)
(define-private (call-b
    (tx <ft-trait>)
    (ty <ft-trait>)
    (dx uint)
    (min-dy uint)
    (dy-check uint)
    (p (optional principal))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.wrapper-arkadiko-v-1-2
    swap-x-for-y
    tx
    ty
    dx
    min-dy
    p)
)
```
