(use-trait ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait xyk-pool-trait-v1-2 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)
(use-trait share-fee-to-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)

(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))

(define-public (serve
    (a1 (optional uint))
    (a2 (optional uint))
    (a3 (optional principal))
    (a4 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (a5 (optional (tuple (a <xyk-pool-trait-v1-2>))))
    (a6 (optional uint))
    (a7 (optional bool))
    (a8 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (a9 (optional (tuple (a <xyk-pool-trait-v1-2>))))
    (a10 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (a11 (optional (tuple (a <share-fee-to-trait>))))
  )
  (let (
    (r1 
      (if (and 
            (is-some a1)
            (is-some a2)
            (is-some a4)
            (is-some a5))
        (some (try! (call-a
          (unwrap! a1 e5)
          (unwrap! a2 e5)
          a3
          (unwrap! a4 e5)
          (unwrap! a5 e5))))
        none))
    (a-for-r2 
      (if (is-some r1)
        (unwrap! r1 e3)
        (unwrap! a1 e5)))
    (r2
      (if (and
            (is-some a6)
            (is-some a7)
            (is-some a8)
            (is-some a9)
            (is-some a10)
            (is-some a11))
        (some (try! (call-b
          a-for-r2
          (unwrap! a6 e5)
          a3
          (unwrap! a7 e5)
          (unwrap! a8 e5)
          (unwrap! a9 e5)
          (unwrap! a10 e5)
          (unwrap! a11 e5))))
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
    (xt (tuple (a <ft-trait>) (b <ft-trait>)))
    (xp (tuple (a <xyk-pool-trait-v1-2>)))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-swap-helper-v-1-3
    swap-helper-a
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