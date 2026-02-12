;; gjujtsat

(use-trait ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait xyk-ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)
(use-trait share-fee-to-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)

(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))

(define-public (gjujn
    ;; Swap 1 params (wrapper-velar)
    (v1 (optional uint))
    (t0 (optional <ft-trait>))
    (t1 (optional <ft-trait>))
    (ti (optional <ft-trait>))
    (to (optional <ft-trait>))
    (sf (optional <share-fee-to-trait>))
    (ai (optional uint))
    (ao (optional uint))
    (p1 (optional principal))
    
    ;; Swap 2 params (router-xyk-velar)
    (a2 (optional uint))
    (mr (optional uint))
    (p2 (optional principal))
    (sr (optional bool))
    (xt (optional (tuple (a <xyk-ft-trait>) (b <xyk-ft-trait>))))
    (xp (optional (tuple (a <xyk-pool-trait>))))
    (vt (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (vs (optional <share-fee-to-trait>))
  )
  (let (
    (r1 
      (if (and 
            (is-some v1)
            (is-some t0)
            (is-some t1)
            (is-some ti)
            (is-some to)
            (is-some sf)
            (is-some ai)
            (is-some ao))
        (some (try! (call-a
          (unwrap! v1 e5)
          (unwrap! t0 e5)
          (unwrap! t1 e5)
          (unwrap! ti e5)
          (unwrap! to e5)
          (unwrap! sf e5)
          (unwrap! ai e5)
          (unwrap! ao e5)
          p1)))
        none))
    (a-for-r2 
      (if (is-some r1)
        (unwrap! r1 e3)
        (unwrap! ai e5)))
    (r2
      (if (and
            (is-some a2)
            (is-some mr)
            (is-some sr)
            (is-some xt)
            (is-some xp)
            (is-some vt)
            (is-some vs))
        (some (try! (call-b
          a-for-r2
          (unwrap! mr e5)
          p2
          (unwrap! sr e5)
          (unwrap! xt e5)
          (unwrap! xp e5)
          (unwrap! vt e5)
          (unwrap! vs e5))))
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
    ;; wrapper-velar returns (ok (response tuple uint))
    ;; We need to unwrap twice: once for the outer ok, once for the inner response
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
    ;; outer-result is now (response tuple uint), unwrap it to get the tuple
    (swap-tuple (try! outer-result))
    ;; Extract amt-out from the tuple
    (amt-out-value (get amt-out swap-tuple))
  )
    (ok amt-out-value)
  )
)

(define-private (call-b
    (amount uint)
    (min-received uint)
    (provider (optional principal))
    (swaps-reversed bool)
    (xyk-tokens (tuple (a <xyk-ft-trait>) (b <xyk-ft-trait>)))
    (xyk-pools (tuple (a <xyk-pool-trait>)))
    (velar-tokens (tuple (a <ft-trait>) (b <ft-trait>)))
    (velar-share-fee-to <share-fee-to-trait>)
  )
  (let (
    (result (try! (contract-call?
      'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-xyk-velar-v-1-4 swap-helper-a
      amount
      min-received
      provider
      swaps-reversed
      xyk-tokens
      xyk-pools
      velar-tokens
      velar-share-fee-to)))
  )
    (ok result)
  )
)