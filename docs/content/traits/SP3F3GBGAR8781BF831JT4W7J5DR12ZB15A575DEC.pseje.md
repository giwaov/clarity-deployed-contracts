---
title: "Trait pseje"
draft: true
---
```
(use-trait ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait univ2v2-pool-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-pool-trait_v1_0_0.univ2-pool-trait)
(use-trait univ2v2-fees-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-fees-trait_v1_0_0.univ2-fees-trait)
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)

(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))

(define-public (rrk
    (ai1 (optional uint))
    (ti1 (optional <ft-trait>))
    (to1 (optional <ft-trait>))
    (up1 (optional <univ2v2-pool-trait>))
    (uf1 (optional <univ2v2-fees-trait>))
    (p1 (optional principal))
    (a2 (optional uint))
    (mr2 (optional uint))
    (p2 (optional principal))
    (xt2 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (xp2 (optional (tuple (a <xyk-pool-trait>))))
  )
  (let (
    (r1 
      (if (and 
            (is-some ai1)
            (is-some ti1)
            (is-some to1)
            (is-some up1)
            (is-some uf1)
            (is-some p1))
        (some (try! (call-a
          (unwrap! ai1 e5)
          (unwrap! ti1 e5)
          (unwrap! to1 e5)
          (unwrap! up1 e5)
          (unwrap! uf1 e5)
          (unwrap! p1 e5))))
        none))
    (a-for-r2 
      (if (is-some r1)
        (unwrap! r1 e3)
        (unwrap! a2 e5)))
    (r2
      (if (and
            (is-some mr2)
            (is-some xt2)
            (is-some xp2))
        (some (try! (call-b
          a-for-r2
          (unwrap! mr2 e5)
          p2
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
    (amt-in uint)
    (token-in <ft-trait>)
    (token-out <ft-trait>)
    (univ2v2-pool <univ2v2-pool-trait>)
    (univ2v2-fees <univ2v2-fees-trait>)
    (provider principal)
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.wrapper-velar-path-v-1-2
    swap-univ2v2
    amt-in
    token-in
    token-out
    univ2v2-pool
    univ2v2-fees
    (some provider))
)

(define-private (call-b
    (a uint)
    (mr uint)
    (p (optional principal))
    (xt (tuple (a <ft-trait>) (b <ft-trait>)))
    (xp (tuple (a <xyk-pool-trait>)))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-swap-helper-v-1-3
    swap-helper-a
    a
    mr
    p
    xt
    xp)
)
```
