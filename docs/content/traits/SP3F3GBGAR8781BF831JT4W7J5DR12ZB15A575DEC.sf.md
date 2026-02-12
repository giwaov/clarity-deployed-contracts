---
title: "Trait sf"
draft: true
---
```
(use-trait sft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait sp-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-4.stableswap-pool-trait)
(use-trait vft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait vsft-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)

(define-constant e1 (err u7001))
(define-constant e2 (err u7002))
(define-constant e3 (err u7003))

(define-public (dj
    (a1 (optional uint))
    (a2 (optional uint))
    (a3 (optional principal))
    (a4 (optional bool))
    (st1 (optional (tuple (a <sft-trait>) (b <sft-trait>))))
    (sp1 (optional (tuple (a <sp-trait>))))
    (vt1 (optional (tuple (a <vft-trait>) (b <vft-trait>) (c <vft-trait>))))
    (vs1 (optional <vsft-trait>))
    (a5 (optional uint))
    (a6 (optional uint))
    (a7 (optional principal))
    (a8 (optional bool))
    (st2 (optional (tuple (a <sft-trait>) (b <sft-trait>))))
    (sp2 (optional (tuple (a <sp-trait>))))
    (vt2 (optional (tuple (a <vft-trait>) (b <vft-trait>))))
    (vs2 (optional <vsft-trait>))
  )
  (let (
    (r1 
      (if (and (is-some a1) (is-some a2) (is-some a4) (is-some st1) (is-some sp1) (is-some vt1) (is-some vs1))
        (some (try! (call-a
          (unwrap! a1 e3)
          (unwrap! a2 e3)
          a3
          (unwrap! a4 e3)
          (unwrap! st1 e3)
          (unwrap! sp1 e3)
          (unwrap! vt1 e3)
          (unwrap! vs1 e3))))
        none))
    (v (if (is-some r1) (unwrap! r1 e3) (unwrap! a2 e3)))
    (r2 
      (if (and (is-some a5) (is-some a6) (is-some a8) (is-some st2) (is-some sp2) (is-some vt2) (is-some vs2))
        (some (try! (call-b
          v
          (unwrap! a6 e3)
          a7
          (unwrap! a8 e3)
          (unwrap! st2 e3)
          (unwrap! sp2 e3)
          (unwrap! vt2 e3)
          (unwrap! vs2 e3))))
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
    (vt (tuple (a <vft-trait>) (b <vft-trait>) (c <vft-trait>)))
    (vs <vsft-trait>)
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-velar-v-1-5
    swap-helper-b
    amt min p r st sp vt vs)
)

(define-private (call-b
    (amt uint)
    (min uint)
    (p (optional principal))
    (r bool)
    (st (tuple (a <sft-trait>) (b <sft-trait>)))
    (sp (tuple (a <sp-trait>)))
    (vt (tuple (a <vft-trait>) (b <vft-trait>)))
    (vs <vsft-trait>)
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-velar-v-1-5
    swap-helper-a
    amt min p r st sp vt vs)
)
```
