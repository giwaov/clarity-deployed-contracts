(use-trait ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-1.xyk-pool-trait)
(use-trait share-fee-to-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)

(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))

(define-public (dori
    (pt1 (optional <xyk-pool-trait>))
    (xt1 (optional <ft-trait>))
    (yt1 (optional <ft-trait>))
    (xa1 (optional uint))
    (md1 (optional uint))
    (i2 (optional uint))
    (t02 (optional <ft-trait>))
    (t12 (optional <ft-trait>))
    (ti2 (optional <ft-trait>))
    (to2 (optional <ft-trait>))
    (sf2 (optional <share-fee-to-trait>))
    (ai2 (optional uint))
    (mo2 (optional uint))
    (p2 (optional principal))
  )
  (let (
    (r1 
      (if (and 
            (is-some pt1)
            (is-some xt1)
            (is-some yt1)
            (is-some xa1)
            (is-some md1))
        (some (try! (call-a
          (unwrap! pt1 e5)
          (unwrap! xt1 e5)
          (unwrap! yt1 e5)
          (unwrap! xa1 e5)
          (unwrap! md1 e5))))
        none))
    (a-for-r2 
      (if (is-some r1)
        (unwrap! r1 e3)
        (unwrap! ai2 e5)))
    (r2
      (if (and
            (is-some i2)
            (is-some t02)
            (is-some t12)
            (is-some ti2)
            (is-some to2)
            (is-some sf2)
            (is-some mo2))
        (some (try! (call-b
          (unwrap! i2 e5)
          (unwrap! t02 e5)
          (unwrap! t12 e5)
          (unwrap! ti2 e5)
          (unwrap! to2 e5)
          (unwrap! sf2 e5)
          a-for-r2
          (unwrap! mo2 e5)
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
    (pt <xyk-pool-trait>)
    (xt <ft-trait>)
    (yt <ft-trait>)
    (xa uint)
    (md uint)
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-1
    swap-x-for-y
    pt
    xt
    yt
    xa
    md)
)

(define-private (call-b
    (i uint)
    (t0 <ft-trait>)
    (t1 <ft-trait>)
    (ti <ft-trait>)
    (to <ft-trait>)
    (sf <share-fee-to-trait>)
    (ai uint)
    (mo uint)
    (p (optional principal))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.wrapper-velar-v-1-2
    swap-helper-a
    i
    t0
    t1
    ti
    to
    sf
    ai
    mo
    p)
)