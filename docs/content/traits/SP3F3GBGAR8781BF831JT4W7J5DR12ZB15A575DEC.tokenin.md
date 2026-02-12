---
title: "Trait tokenin"
draft: true
---
```
(use-trait ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-1.xyk-pool-trait)
(use-trait share-fee-to-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)

(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))

(define-public (tokenout
    (a1 (optional uint))
    (a2 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (a3 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (a4 (optional (tuple (a <share-fee-to-trait>))))
    (a5 (optional uint))
    (a6 (optional principal))
    (a7 (optional (tuple (a <xyk-pool-trait>))))
    (a8 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (a9 (optional uint))
  )
  (let (
    (r1 
      (if (and 
            (is-some a1)
            (is-some a2)
            (is-some a3)
            (is-some a4)
            (is-some a5))
        (some (try! (call-a
          (unwrap! a1 e5)
          (unwrap! a2 e5)
          (unwrap! a3 e5)
          (unwrap! a4 e5)
          (unwrap! a5 e5)
          a6)))
        none))
    (a-for-r2 
      (if (is-some r1)
        (get amt-in (unwrap! r1 e3))
        (unwrap! a1 e5)))
    (r2
      (if (and
            (is-some a7)
            (is-some a8)
            (is-some a9))
        (some (try! (call-b
          (unwrap! a7 e5)
          (unwrap! a8 e5)
          a-for-r2
          (unwrap! a9 e5))))
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
    (vid uint)
    (vt (tuple (a <ft-trait>) (b <ft-trait>)))
    (vio (tuple (a <ft-trait>) (b <ft-trait>)))
    (sft (tuple (a <share-fee-to-trait>)))
    (am uint)
    (p (optional principal))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.wrapper-velar-v-1-2
    swap-helper-b
    vid
    (get a vt)
    (get b vt)
    (get a vio)
    (get b vio)
    (get a sft)
    am
    u1
    p)
)

(define-private (call-b
    (pt (tuple (a <xyk-pool-trait>)))
    (xt (tuple (a <ft-trait>) (b <ft-trait>)))
    (a uint)
    (m uint)
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-1
    swap-y-for-x
    (get a pt)
    (get a xt)
    (get b xt)
    a
    m)
)
```
