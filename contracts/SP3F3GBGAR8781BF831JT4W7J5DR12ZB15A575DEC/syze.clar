;; syze

(use-trait ft-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)
(use-trait xyk-pool-trait-v1-1 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-1.xyk-pool-trait)
(use-trait xyk-pool-trait-v1-2 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)

(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))

(define-public (dielli
    (pt1 (optional <xyk-pool-trait-v1-1>))
    (xt1 (optional <ft-trait>))
    (yt1 (optional <ft-trait>))
    (ya1 (optional uint))
    (md1 (optional uint))
    (a2 (optional uint))
    (mr2 (optional uint))
    (p2 (optional principal))
    (xt2 (optional (tuple (a <ft-trait>) (b <ft-trait>))))
    (xp2 (optional (tuple (a <xyk-pool-trait-v1-2>))))
  )
  (let (
    (r1 
      (if (and 
            (is-some pt1)
            (is-some xt1)
            (is-some yt1)
            (is-some ya1)
            (is-some md1))
        (some (try! (call-a
          (unwrap! pt1 e5)
          (unwrap! xt1 e5)
          (unwrap! yt1 e5)
          (unwrap! ya1 e5)
          (unwrap! md1 e5))))
        none))
    (a-for-r2 
      (if (is-some r1)
        (unwrap! r1 e3)
        (unwrap! ya1 e5)))
    (r2
      (if (and
            (is-some a2)
            (is-some mr2)
            (is-some xt2)
            (is-some xp2))
        (some (try! (call-b
          a-for-r2
          (unwrap! mr2 e5)
          p2
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

(define-private (call-b
    (a uint)
    (mr uint)
    (p (optional principal))
    (xt (tuple (a <ft-trait>) (b <ft-trait>)))
    (xp (tuple (a <xyk-pool-trait-v1-2>)))
  )
  (contract-call?
    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-swap-helper-v-1-3
    swap-helper-a
    a
    mr
    p
    xt
    xp)
)