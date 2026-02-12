(use-trait sip-010-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)

(define-trait bitflow-core-trait
  (
    (swap-x-for-y (<xyk-pool-trait> <sip-010-trait> <sip-010-trait> uint uint) (response uint uint))
    (swap-y-for-x (<xyk-pool-trait> <sip-010-trait> <sip-010-trait> uint uint) (response uint uint))
  )
)

(define-trait route-engine-trait
  (
    (ss ((buff 400)) (response (list 20 (response uint uint)) uint))
  )
)

(define-constant err-bitflow-call (err u120))
(define-constant err-velar-call (err u121))
(define-constant err-route-empty (err u122))
(define-constant err-negative-profit (err u123))
(define-constant err-profit-too-low (err u124))
(define-constant err-no-stx-after-velar (err u125))
(define-constant err-no-stx-after-bitflow (err u126))

(define-public (execute-bitflow-then-velar
  (quote-token <sip-010-trait>)
  (stx-token <sip-010-trait>)
  (bitflow-core <bitflow-core-trait>)
  (bitflow-pool <xyk-pool-trait>)
  (bitflow-quote-in uint)
  (bitflow-min-stx-out uint)
  (velar-route (buff 400))
  (velar-engine <route-engine-trait>)
  (min-profit uint)
)
  (begin
    (asserts! (> (len velar-route) u0) err-route-empty)
    (let
      (
        (quote-before (unwrap-panic (contract-call? quote-token get-balance tx-sender)))
        (stx-before (unwrap-panic (contract-call? stx-token get-balance tx-sender)))
        (bitflow-stx-out (unwrap!
          (contract-call?
            bitflow-core
            swap-y-for-x
            bitflow-pool
            stx-token
            quote-token
            bitflow-quote-in
            bitflow-min-stx-out
          )
          err-bitflow-call
        ))
        (stx-after-bitflow (unwrap-panic (contract-call? stx-token get-balance tx-sender)))
      )
      (asserts! (> stx-after-bitflow stx-before) err-no-stx-after-bitflow)
      (let
        (
          (velar-result (unwrap! (contract-call? velar-engine ss velar-route) err-velar-call))
          (quote-after (unwrap-panic (contract-call? quote-token get-balance tx-sender)))
        )
        (asserts! (>= quote-after quote-before) err-negative-profit)
        (let ((profit (- quote-after quote-before)))
          (asserts! (>= profit min-profit) err-profit-too-low)
          (ok
            {
              quote-before: quote-before,
              quote-after: quote-after,
              profit: profit,
              bitflow-stx-out: bitflow-stx-out,
              velar-steps: (len velar-result)
            }
          )
        )
      )
    )
  )
)

(define-public (execute-velar-then-bitflow
  (quote-token <sip-010-trait>)
  (stx-token <sip-010-trait>)
  (velar-route (buff 400))
  (velar-engine <route-engine-trait>)
  (bitflow-core <bitflow-core-trait>)
  (bitflow-pool <xyk-pool-trait>)
  (bitflow-min-quote-out uint)
  (min-profit uint)
)
  (begin
    (asserts! (> (len velar-route) u0) err-route-empty)
    (let
      (
        (quote-before (unwrap-panic (contract-call? quote-token get-balance tx-sender)))
        (stx-before (unwrap-panic (contract-call? stx-token get-balance tx-sender)))
        (velar-result (unwrap! (contract-call? velar-engine ss velar-route) err-velar-call))
        (stx-after-velar (unwrap-panic (contract-call? stx-token get-balance tx-sender)))
      )
      (asserts! (> stx-after-velar stx-before) err-no-stx-after-velar)
      (let
        (
          (stx-to-sell (- stx-after-velar stx-before))
          (bitflow-quote-out (unwrap!
            (contract-call?
              bitflow-core
              swap-x-for-y
              bitflow-pool
              stx-token
              quote-token
              stx-to-sell
              bitflow-min-quote-out
            )
            err-bitflow-call
          ))
          (quote-after (unwrap-panic (contract-call? quote-token get-balance tx-sender)))
        )
        (asserts! (>= quote-after quote-before) err-negative-profit)
        (let ((profit (- quote-after quote-before)))
          (asserts! (>= profit min-profit) err-profit-too-low)
          (ok
            {
              quote-before: quote-before,
              quote-after: quote-after,
              profit: profit,
              stx-sold: stx-to-sell,
              bitflow-quote-out: bitflow-quote-out,
              velar-steps: (len velar-result)
            }
          )
        )
      )
    )
  )
)
