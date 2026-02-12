(use-trait ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait stableswap-ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait stableswap-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-4.stableswap-pool-trait)
(use-trait velar-ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait velar-share-fee-to-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)
(use-trait xyk-ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-1.xyk-pool-trait)

(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))

(define-public (tori
    (a1 (optional uint))
    (mr1 (optional uint))
    (p1 (optional principal))
    (sr1 (optional bool))
    (st1 (optional (tuple (a <stableswap-ft-trait>) (b <stableswap-ft-trait>))))
    (sp1 (optional (tuple (a <stableswap-pool-trait>))))
    (vt1 (optional (tuple (a <velar-ft-trait>) (b <velar-ft-trait>) (c <velar-ft-trait>))))
    (vsf1 (optional <velar-share-fee-to-trait>))
    (a2 (optional uint))
    (mr2 (optional uint))
    (p2 (optional principal))
    (sr2 (optional bool))
    (sst2 (optional (tuple (a <stableswap-ft-trait>) (b <stableswap-ft-trait>))))
    (ssp2 (optional (tuple (a <stableswap-pool-trait>))))
    (xt2 (optional (tuple (a <xyk-ft-trait>) (b <xyk-ft-trait>))))
    (xp2 (optional (tuple (a <xyk-pool-trait>))))
  )
  (let (
    (r1 
      (if (and 
            (is-some a1)
            (is-some mr1)
            (is-some sr1)
            (is-some st1)
            (is-some sp1)
            (is-some vt1)
            (is-some vsf1))
        (some (try! (call-a
          (unwrap! a1 e5)
          (unwrap! mr1 e5)
          p1
          (unwrap! sr1 e5)
          (unwrap! st1 e5)
          (unwrap! sp1 e5)
          (unwrap! vt1 e5)
          (unwrap! vsf1 e5))))
        none))
    (a-for-r2 
      (if (is-some r1)
        (unwrap! r1 e3)
        (unwrap! a2 e5)))
    (r2
      (if (and
            (is-some mr2)
            (is-some sr2)
            (is-some sst2)
            (is-some ssp2)
            (is-some xt2)
            (is-some xp2))
        (some (try! (call-b
          a-for-r2
          (unwrap! mr2 e5)
          p2
          (unwrap! sr2 e5)
          (unwrap! sst2 e5)
          (unwrap! ssp2 e5)
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
    (mr uint)
    (p (optional principal))
    (sr bool)
    (st (tuple (a <stableswap-ft-trait>) (b <stableswap-ft-trait>)))
    (sp (tuple (a <stableswap-pool-trait>)))
    (vt (tuple (a <velar-ft-trait>) (b <velar-ft-trait>) (c <velar-ft-trait>)))
    (vsf <velar-share-fee-to-trait>)
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-velar-v-1-5
    swap-helper-b
    a
    mr
    p
    sr
    st
    sp
    vt
    vsf)
)

(define-private (call-b
    (a uint)
    (mr uint)
    (p (optional principal))
    (sr bool)
    (sst (tuple (a <stableswap-ft-trait>) (b <stableswap-ft-trait>)))
    (ssp (tuple (a <stableswap-pool-trait>)))
    (xt (tuple (a <xyk-ft-trait>) (b <xyk-ft-trait>)))
    (xp (tuple (a <xyk-pool-trait>)))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-v-1-5
    swap-helper-a
    a
    mr
    p
    sr
    sst
    ssp
    xt
    xp)
)