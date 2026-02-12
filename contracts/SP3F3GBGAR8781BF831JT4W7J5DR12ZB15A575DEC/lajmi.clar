(use-trait ft-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)
(use-trait xyk-pool-trait-v1-2 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)

(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))

(define-public (fundit
    (a1 (optional uint))
    (a2 (optional uint))
    (a3 (optional principal))
    (xt1 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (xp1 (optional (tuple (a <xyk-pool-trait-v1-2>))))
    (a4 (optional <ft-trait>))
    (a5 (optional <ft-trait>))
    (a6 (optional uint))
    (a7 (optional uint))
    (p2 (optional principal))
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
            (is-some a5)
            (is-some a6)
            (is-some a7))
        (some (try! (call-b
          (unwrap! a4 e5)
          (unwrap! a5 e5)
          a-for-r2
          (unwrap! a6 e5)
          (unwrap! a7 e5)
          p2)))
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
    (tx <ft-trait>)
    (ty <ft-trait>)
    (dy uint)
    (min-dx uint)
    (amt-check uint)
    (p (optional principal))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.wrapper-arkadiko-v-1-2
    swap-y-for-x
    tx
    ty
    dy
    min-dx
    p)
)