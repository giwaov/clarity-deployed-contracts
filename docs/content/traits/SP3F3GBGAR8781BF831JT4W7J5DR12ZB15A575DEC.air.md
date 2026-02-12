---
title: "Trait air"
draft: true
---
```
(use-trait ft-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)
(use-trait xyk-pool-trait-v1-2 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)
(use-trait stableswap-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-2.stableswap-pool-trait)

(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))

(define-public (force
    (a1 (optional uint))
    (a2 (optional uint))
    (a3 (optional principal))
    (xt1 (optional (tuple (a <ft-trait>) (b <ft-trait>) (c <ft-trait>) (d <ft-trait>) (e <ft-trait>) (f <ft-trait>))))
    (xp1 (optional (tuple (a <xyk-pool-trait-v1-2>) (b <xyk-pool-trait-v1-2>) (c <xyk-pool-trait-v1-2>))))
    (a4 (optional uint))
    (a5 (optional principal))
    (a6 (optional bool))
    (st2 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (sp2 (optional (tuple (a <stableswap-pool-trait>))))
    (xt2 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (xp2 (optional (tuple (a <xyk-pool-trait-v1-2>))))
  )
  (let (
    (r1 
      (if (and 
            (is-some a1)
            (is-some a2)
            (is-some xt1)
            (is-some xp1))
        (some (try! (call-a
          (unwrap! a1 e5)
          (unwrap! a2 e5)
          a3
          (unwrap! xt1 e5)
          (unwrap! xp1 e5))))
        none))
    (a-for-r2 
      (if (is-some r1)
        (unwrap! r1 e3)
        (unwrap! a1 e5)))
    (r2
      (if (and
            (is-some a4)
            (is-some a6)
            (is-some st2)
            (is-some sp2)
            (is-some xt2)
            (is-some xp2))
        (some (try! (call-b
          a-for-r2
          (unwrap! a4 e5)
          a5
          (unwrap! a6 e5)
          (unwrap! st2 e5)
          (unwrap! sp2 e5)
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
    (a uint)
    (m uint)
    (p (optional principal))
    (xt (tuple (a <ft-trait>) (b <ft-trait>) (c <ft-trait>) (d <ft-trait>) (e <ft-trait>) (f <ft-trait>)))
    (xp (tuple (a <xyk-pool-trait-v1-2>) (b <xyk-pool-trait-v1-2>) (c <xyk-pool-trait-v1-2>)))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-swap-helper-v-1-3
    swap-helper-c
    a
    m
    p
    xt
    xp)
)

(define-private (call-b
    (a uint)
    (m uint)
    (p (optional principal))
    (sr bool)
    (st (tuple (a <ft-trait>) (b <ft-trait>)))
    (sp (tuple (a <stableswap-pool-trait>)))
    (xt (tuple (a <ft-trait>) (b <ft-trait>)))
    (xp (tuple (a <xyk-pool-trait-v1-2>)))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-1
    swap-helper-a
    a
    m
    p
    sr
    st
    sp
    xt
    xp)
)
```
