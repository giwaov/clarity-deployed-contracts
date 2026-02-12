(use-trait ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait stableswap-ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait stableswap-pool-trait-v1-2 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-2.stableswap-pool-trait)
(use-trait stableswap-pool-trait-v1-4 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-4.stableswap-pool-trait)
(use-trait xyk-ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait xyk-pool-trait-v1-1 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-1.xyk-pool-trait)
(use-trait xyk-pool-trait-v1-2 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)

(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))

(define-public (nice
    (a1 (optional uint))
    (mr1 (optional uint))
    (p1 (optional principal))
    (sr1 (optional bool))
    (st1 (optional (tuple (a <stableswap-ft-trait>) (b <stableswap-ft-trait>))))
    (sp1 (optional (tuple (a <stableswap-pool-trait-v1-2>))))
    (xt1 (optional (tuple (a <xyk-ft-trait>) (b <xyk-ft-trait>))))
    (xp1 (optional (tuple (a <xyk-pool-trait-v1-1>))))
    (a2 (optional uint))
    (mr2 (optional uint))
    (p2 (optional principal))
    (sr2 (optional bool))
    (st2 (optional (tuple (a <ft-trait>) (b <ft-trait>) (c <ft-trait>) (d <ft-trait>))))
    (sp2 (optional (tuple (a <stableswap-pool-trait-v1-4>) (b <stableswap-pool-trait-v1-4>))))
    (xt2 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (xp2 (optional (tuple (a <xyk-pool-trait-v1-2>))))
  )
  (let (
    (r1 
      (if (and 
            (is-some a1)
            (is-some mr1)
            (is-some sr1)
            (is-some st1)
            (is-some sp1)
            (is-some xt1)
            (is-some xp1))
        (some (try! (call-a
          (unwrap! a1 e5)
          (unwrap! mr1 e5)
          p1
          (unwrap! sr1 e5)
          (unwrap! st1 e5)
          (unwrap! sp1 e5)
          (unwrap! xt1 e5)
          (unwrap! xp1 e5))))
        none))
    (a-for-r2 
      (if (is-some r1)
        (unwrap! r1 e3)
        (unwrap! a2 e5)))
    (r2
      (if (and
            (is-some mr2)
            (is-some sr2)
            (is-some st2)
            (is-some sp2)
            (is-some xt2)
            (is-some xp2))
        (some (try! (call-b
          a-for-r2
          (unwrap! mr2 e5)
          p2
          (unwrap! sr2 e5)
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
    (mr uint)
    (p (optional principal))
    (sr bool)
    (st (tuple (a <stableswap-ft-trait>) (b <stableswap-ft-trait>)))
    (sp (tuple (a <stableswap-pool-trait-v1-2>)))
    (xt (tuple (a <xyk-ft-trait>) (b <xyk-ft-trait>)))
    (xp (tuple (a <xyk-pool-trait-v1-1>)))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-v-1-3
    swap-helper-a
    a
    mr
    p
    sr
    st
    sp
    xt
    xp)
)

(define-private (call-b
    (a uint)
    (mr uint)
    (p (optional principal))
    (sr bool)
    (st (tuple (a <ft-trait>) (b <ft-trait>) (c <ft-trait>) (d <ft-trait>)))
    (sp (tuple (a <stableswap-pool-trait-v1-4>) (b <stableswap-pool-trait-v1-4>)))
    (xt (tuple (a <ft-trait>) (b <ft-trait>)))
    (xp (tuple (a <xyk-pool-trait-v1-2>)))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2
    swap-helper-d
    a
    mr
    p
    sr
    st
    sp
    xt
    xp)
)