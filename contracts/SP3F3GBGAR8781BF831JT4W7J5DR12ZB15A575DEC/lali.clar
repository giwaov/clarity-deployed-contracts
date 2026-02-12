(use-trait ft-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)
(use-trait xyk-pool-trait-v1-2 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)
(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))
(define-public (xhan
    (a1 (optional uint))
    (a2 (optional uint))
    (a3 (optional principal))
    (xt1 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (a4 (optional uint))
    (a5 (optional principal))
    (xt2 (optional (tuple (a <ft-trait>) (b <ft-trait>) (c <ft-trait>) (d <ft-trait>))))
    (xp2 (optional (tuple (a <xyk-pool-trait-v1-2>) (b <xyk-pool-trait-v1-2>))))
  )
  (let (
    (r1
      (if (and
            (is-some a1)
            (is-some a2)
            (is-some xt1))
        (some (unwrap! (element-at (try! (call-a
          (unwrap! xt1 e5)
          (unwrap! a1 e5)
          (unwrap! a2 e5)
          a3)) u1) e2))
        none))
    (a-for-r2
      (if (is-some r1)
        (unwrap! r1 e3)
        (unwrap! a1 e5)))
    (r2
      (if (and
            (is-some a4)
            (is-some xt2)
            (is-some xp2))
        (some (try! (call-b
          a-for-r2
          (unwrap! a4 e5)
          a5
          (unwrap! xt2 e5)
          (unwrap! xp2 e5))))
        none))
  )
    (begin
      (asserts! (or (is-some r1) (is-some r2)) e5)
      (ok { r1: r1, r2: r2 })
    )
  )
)
(define-private (call-a
    (xt (tuple (a <ft-trait>) (b <ft-trait>)))
    (dx uint)
    (m uint)
    (p (optional principal))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.wrapper-arkadiko-v-1-2
    swap-x-for-y
    (get a xt)
    (get b xt)
    dx
    m
    p)
)
(define-private (call-b
    (a uint)
    (m uint)
    (p (optional principal))
    (xt (tuple (a <ft-trait>) (b <ft-trait>) (c <ft-trait>) (d <ft-trait>)))
    (xp (tuple (a <xyk-pool-trait-v1-2>) (b <xyk-pool-trait-v1-2>)))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-swap-helper-v-1-3
    swap-helper-b
    a
    m
    p
    xt
    xp)
)