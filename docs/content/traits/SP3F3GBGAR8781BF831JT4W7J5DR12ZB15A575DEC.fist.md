---
title: "Trait fist"
draft: true
---
```
(use-trait ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait xyk-pool-trait-v1-2 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)
(use-trait share-fee-to-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)

(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))

(define-public (bump
    (a1 (optional uint))
    (a2 (optional uint))
    (a3 (optional principal))
    (a4 (optional bool))
    (a5 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (a6 (optional (tuple (a <xyk-pool-trait-v1-2>))))
    (a7 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (a8 (optional (tuple (a <share-fee-to-trait>))))
    (a9 (optional uint))
    (a10 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (a11 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (a12 (optional (tuple (a <share-fee-to-trait>))))
    (a13 (optional uint))
  )
  (let (
    (r1 
      (if (and 
            (is-some a1)
            (is-some a2)
            (is-some a4)
            (is-some a5)
            (is-some a6)
            (is-some a7)
            (is-some a8))
        (some (try! (call-a
          (unwrap! a1 e5)
          (unwrap! a2 e5)
          a3
          (unwrap! a4 e5)
          (unwrap! a5 e5)
          (unwrap! a6 e5)
          (unwrap! a7 e5)
          (unwrap! a8 e5))))
        none))
    (a-for-r2 
      (if (is-some r1)
        (unwrap! r1 e3)
        (unwrap! a1 e5)))
    (r2
      (if (and
            (is-some a9)
            (is-some a10)
            (is-some a11)
            (is-some a12)
            (is-some a13))
        (some (try! (call-b
          (unwrap! a9 e5)
          (unwrap! a10 e5)
          (unwrap! a11 e5)
          (unwrap! a12 e5)
          a-for-r2
          (unwrap! a13 e5)
          a3)))
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
    (vt (tuple (a <ft-trait>) (b <ft-trait>)))
    (sft (tuple (a <share-fee-to-trait>)))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-xyk-velar-v-1-4
    swap-helper-a
    a
    m
    p
    sr
    xt
    xp
    vt
    (get a sft))
)

(define-private (call-b
    (vid uint)
    (vt (tuple (a <ft-trait>) (b <ft-trait>)))
    (vio (tuple (a <ft-trait>) (b <ft-trait>)))
    (sft (tuple (a <share-fee-to-trait>)))
    (a uint)
    (m uint)
    (p (optional principal))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.wrapper-velar-v-1-2
    swap-helper-a
    vid
    (get a vt)
    (get b vt)
    (get a vio)
    (get b vio)
    (get a sft)
    a
    m
    p)
)
```
