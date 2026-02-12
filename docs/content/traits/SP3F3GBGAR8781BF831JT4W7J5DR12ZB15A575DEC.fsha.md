---
title: "Trait fsha"
draft: true
---
```
(use-trait ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait sft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait sp-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-4.stableswap-pool-trait)
(use-trait xp-trait-v11 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-1.xyk-pool-trait)
(use-trait xp-trait-v12 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)

(define-constant e1 (err u7001))
(define-constant e2 (err u7002))
(define-constant e3 (err u7003))

(define-public (udhn
    (a1 (optional uint))
    (a2 (optional uint))
    (a3 (optional principal))
    (a4 (optional bool))
    (st1 (optional (tuple (a <sft-trait>) (b <sft-trait>))))
    (sp1 (optional (tuple (a <sp-trait>))))
    (xt1 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (xp1 (optional (tuple (a <xp-trait-v11>))))
    (a5 (optional uint))
    (a6 (optional uint))
    (a7 (optional principal))
    (a8 (optional bool))
    (st2 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (sp2 (optional (tuple (a <sp-trait>))))
    (xt2 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (xp2 (optional (tuple (a <xp-trait-v12>))))
  )
  (let (
    (r1 
      (if (and (is-some a1) (is-some a2) (is-some a4) (is-some st1) (is-some sp1) (is-some xt1) (is-some xp1))
        (some (try! (call-a
          (unwrap! a1 e3)
          (unwrap! a2 e3)
          a3
          (unwrap! a4 e3)
          (unwrap! st1 e3)
          (unwrap! sp1 e3)
          (unwrap! xt1 e3)
          (unwrap! xp1 e3))))
        none))
    (v (if (is-some r1) (unwrap! r1 e3) (unwrap! a5 e3)))
    (r2 
      (if (and (is-some a5) (is-some a6) (is-some a8) (is-some st2) (is-some sp2) (is-some xt2) (is-some xp2))
        (some (try! (call-b
          v
          (unwrap! a6 e3)
          a7
          (unwrap! a8 e3)
          (unwrap! st2 e3)
          (unwrap! sp2 e3)
          (unwrap! xt2 e3)
          (unwrap! xp2 e3))))
        none))
  )
    (begin
      (asserts! (or (is-some r1) (is-some r2)) e3)
      (ok (unwrap! r2 e3))
    )
  )
)

(define-private (call-a
    (amt uint)
    (min uint)
    (p (optional principal))
    (r bool)
    (st (tuple (a <sft-trait>) (b <sft-trait>)))
    (sp (tuple (a <sp-trait>)))
    (xt (tuple (a <ft-trait>) (b <ft-trait>)))
    (xp (tuple (a <xp-trait-v11>)))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-v-1-5
    swap-helper-a
    amt min p r st sp xt xp)
)

(define-private (call-b
    (amt uint)
    (min uint)
    (p (optional principal))
    (r bool)
    (st (tuple (a <ft-trait>) (b <ft-trait>)))
    (sp (tuple (a <sp-trait>)))
    (xt (tuple (a <ft-trait>) (b <ft-trait>)))
    (xp (tuple (a <xp-trait-v12>)))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2
    swap-helper-a
    amt min p r st sp xt xp)
)
```
