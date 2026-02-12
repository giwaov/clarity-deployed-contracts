(use-trait ft-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)
(use-trait xyk-pool-trait-v1-2 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)
(use-trait share-fee-to-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)
(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))
(define-public (topulli
    (a1 (optional uint))
    (a2 (optional uint))
    (a3 (optional principal))
    (xt1 (optional (tuple (a <ft-trait>) (b <ft-trait>) (c <ft-trait>) (d <ft-trait>))))
    (xp1 (optional (tuple (a <xyk-pool-trait-v1-2>) (b <xyk-pool-trait-v1-2>))))
    (a4 (optional uint))
    (a5 (optional uint))
    (a6 (optional uint))
    (t0 (optional <ft-trait>))
    (t1 (optional <ft-trait>))
    (ti (optional <ft-trait>))
    (to (optional <ft-trait>))
    (sft (optional <share-fee-to-trait>))
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
            (is-some t0)
            (is-some t1)
            (is-some ti)
            (is-some to)
            (is-some sft))
        (some (let ((res (try! (try! (call-b
          (unwrap! a4 e5)
          a-for-r2
          (unwrap! a5 e5)
          (unwrap! a6 e5)
          (unwrap! t0 e5)
          (unwrap! t1 e5)
          (unwrap! ti e5)
          (unwrap! to e5)
          (unwrap! sft e5)
          p2)))))
          (asserts! (>= (get amt-out res) (unwrap! a6 e5)) e4)
          (get amt-out res)))
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
(define-private (call-b
    (id uint)
    (amt-in uint)
    (amt-out-min uint)
    (amt-check uint)
    (t0 <ft-trait>)
    (t1 <ft-trait>)
    (ti <ft-trait>)
    (to <ft-trait>)
    (sft <share-fee-to-trait>)
    (p (optional principal))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.wrapper-velar-v-1-2
    swap-helper-a
    id
    t0
    t1
    ti
    to
    sft
    amt-in
    amt-out-min
    p)
)