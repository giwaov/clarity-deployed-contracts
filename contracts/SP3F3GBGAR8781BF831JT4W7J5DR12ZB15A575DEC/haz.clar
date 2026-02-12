;; haz

(use-trait ft-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)
(use-trait xyk-pool-trait-v1-1 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-1.xyk-pool-trait)

(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))

(define-public (bullari
    (pt1 (optional <xyk-pool-trait-v1-1>))
    (xt1 (optional <ft-trait>))
    (yt1 (optional <ft-trait>))
    (xa1 (optional uint))
    (md1 (optional uint))
    (pt2 (optional <xyk-pool-trait-v1-1>))
    (xt2 (optional <ft-trait>))
    (yt2 (optional <ft-trait>))
    (a2 (optional uint))
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
        (unwrap! xa1 e5)))
    (r2
      (if (and
            (is-some pt2)
            (is-some xt2)
            (is-some yt2)
            (is-some a2))
        (some (try! (call-b
          (unwrap! pt2 e5)
          (unwrap! xt2 e5)
          (unwrap! yt2 e5)
          a-for-r2
          (unwrap! a2 e5))))
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
    (pt <xyk-pool-trait-v1-1>)
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
    (pt <xyk-pool-trait-v1-1>)
    (xt <ft-trait>)
    (yt <ft-trait>)
    (ya uint)
    (md uint)
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-1
    swap-y-for-x
    pt
    xt
    yt
    ya
    md)
)