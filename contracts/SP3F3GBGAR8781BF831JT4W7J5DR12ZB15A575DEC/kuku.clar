(use-trait ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-1.xyk-pool-trait)
(use-trait share-fee-to-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)
(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))
(define-public (minone
    (v1 (optional uint))
    (t0a (optional <ft-trait>))
    (t1a (optional <ft-trait>))
    (tia (optional <ft-trait>))
    (toa (optional <ft-trait>))
    (sfa (optional <share-fee-to-trait>))
    (ai1 (optional uint))
    (ao1 (optional uint))
    (p1 (optional principal))
    (a2 (optional uint))
    (mr2 (optional uint))
    (p2 (optional principal))
    (pt2 (optional <xyk-pool-trait>))
    (xt2 (optional <ft-trait>))
    (yt2 (optional <ft-trait>))
    (xr2 (optional bool))
    (v2 (optional uint))
    (t0b (optional <ft-trait>))
    (t1b (optional <ft-trait>))
    (tib (optional <ft-trait>))
    (tob (optional <ft-trait>))
    (sfb (optional <share-fee-to-trait>))
  )
  (let (
    (r1 
      (if (and 
            (is-some v1)
            (is-some t0a)
            (is-some t1a)
            (is-some tia)
            (is-some toa)
            (is-some sfa)
            (is-some ai1)
            (is-some ao1))
        (some (try! (call-a
          (unwrap! v1 e5)
          (unwrap! t0a e5)
          (unwrap! t1a e5)
          (unwrap! tia e5)
          (unwrap! toa e5)
          (unwrap! sfa e5)
          (unwrap! ai1 e5)
          (unwrap! ao1 e5)
          p1)))
        none))
    (a-for-r2 
      (if (is-some r1)
        (unwrap! r1 e3)
        (unwrap! ai1 e5)))
    (r2
      (if (and
            (is-some a2)
            (is-some mr2)
            (is-some pt2)
            (is-some xt2)
            (is-some yt2)
            (is-some xr2)
            (is-some v2)
            (is-some t0b)
            (is-some t1b)
            (is-some tib)
            (is-some tob)
            (is-some sfb))
        (some (try! (call-b
          a-for-r2
          (unwrap! mr2 e5)
          p2
          (unwrap! pt2 e5)
          (unwrap! xt2 e5)
          (unwrap! yt2 e5)
          (unwrap! xr2 e5)
          (unwrap! v2 e5)
          (unwrap! t0b e5)
          (unwrap! t1b e5)
          (unwrap! tib e5)
          (unwrap! tob e5)
          (unwrap! sfb e5))))
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
    (amount uint)
    (min-received uint)
    (provider (optional principal))
    (pool-trait <xyk-pool-trait>)
    (x-token-trait <ft-trait>)
    (y-token-trait <ft-trait>)
    (xyk-reversed bool)
    (id uint)
    (token0 <ft-trait>)
    (token1 <ft-trait>)
    (token-in <ft-trait>)
    (token-out <ft-trait>)
    (share-fee-to <share-fee-to-trait>)
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-xyk-velar-v-1-2 swap-helper-b
    amount
    min-received
    provider
    pool-trait
    x-token-trait
    y-token-trait
    xyk-reversed
    id
    token0
    token1
    token-in
    token-out
    share-fee-to)
)