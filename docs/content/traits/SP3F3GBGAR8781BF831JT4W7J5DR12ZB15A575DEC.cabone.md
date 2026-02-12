---
title: "Trait cabone"
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
(define-public (lale
    (v1 (optional uint))
    (t0 (optional <ft-trait>))
    (t1 (optional <ft-trait>))
    (ti (optional <ft-trait>))
    (to (optional <ft-trait>))
    (sf (optional <share-fee-to-trait>))
    (ai (optional uint))
    (ao (optional uint))
    (p1 (optional principal))
    (pt2 (optional <xyk-pool-trait>))
    (xt2 (optional <ft-trait>))
    (yt2 (optional <ft-trait>))
    (ya2 (optional uint))
    (md2 (optional uint))
  )
  (let (
    (r1 
      (if (and 
            (is-some v1)
            (is-some t0)
            (is-some t1)
            (is-some ti)
            (is-some to)
            (is-some sf)
            (is-some ai)
            (is-some ao))
        (some (try! (call-a
          (unwrap! v1 e5)
          (unwrap! t0 e5)
          (unwrap! t1 e5)
          (unwrap! ti e5)
          (unwrap! to e5)
          (unwrap! sf e5)
          (unwrap! ai e5)
          (unwrap! ao e5)
          p1)))
        none))
    (a-for-r2 
      (if (is-some r1)
        (unwrap! r1 e3)
        (unwrap! ai e5)))
    (r2
      (if (and
            (is-some pt2)
            (is-some xt2)
            (is-some yt2)
            (is-some md2))
        (some (try! (call-b
          (unwrap! pt2 e5)
          (unwrap! xt2 e5)
          (unwrap! yt2 e5)
          a-for-r2
          (unwrap! md2 e5))))
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
    (id uint)
    (token0 <ft-trait>)
    (token1 <ft-trait>)
    (token-in <ft-trait>)
    (token-out <ft-trait>)
    (share-fee-to <share-fee-to-trait>)
    (amt-in uint)
    (amt-out-min uint)
    (provider (optional principal))
  )
  (let (
    (outer-result (try! (contract-call?
      'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.wrapper-velar-v-1-2 swap-helper-a
      id
      token0
      token1
      token-in
      token-out
      share-fee-to
      amt-in
      amt-out-min
      provider)))
    (swap-tuple (try! outer-result))
    (amt-out-value (get amt-out swap-tuple))
  )
    (ok amt-out-value)
  )
)
(define-private (call-b
    (pool-trait <xyk-pool-trait>)
    (x-token-trait <ft-trait>)
    (y-token-trait <ft-trait>)
    (y-amount uint)
    (min-dx uint)
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-1 swap-y-for-x
    pool-trait
    x-token-trait
    y-token-trait
    y-amount
    min-dx)
)
```
