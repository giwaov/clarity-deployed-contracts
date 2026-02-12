(use-trait bitflow-sip-010-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)

;; Velar's core contracts use the canonical SIP-010 trait.
(use-trait velar-sip-010-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait velar-share-fee-to-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)

(define-trait bitflow-core-trait
  (
    (swap-x-for-y (<xyk-pool-trait> <bitflow-sip-010-trait> <bitflow-sip-010-trait> uint uint) (response uint uint))
    (swap-y-for-x (<xyk-pool-trait> <bitflow-sip-010-trait> <bitflow-sip-010-trait> uint uint) (response uint uint))
  )
)

(define-trait velar-core-trait
  (
    (swap
      (uint <velar-sip-010-trait> <velar-sip-010-trait> <velar-share-fee-to-trait> uint uint)
      (response
        (tuple
          (a uint)
          (amt-fee-lps uint)
          (amt-fee-protocol uint)
          (amt-fee-rest uint)
          (amt-fee-share uint)
          (amt-in uint)
          (amt-in-adjusted uint)
          (amt-out uint)
          (b uint)
          (b0 uint)
          (b1 uint)
          (id uint)
          (k uint)
          (op (string-ascii 4))
          (pool (tuple
            (block-height uint)
            (burn-block-height uint)
            (lp-token principal)
            (protocol-fee (tuple (num uint) (den uint)))
            (reserve0 uint)
            (reserve1 uint)
            (share-fee (tuple (num uint) (den uint)))
            (swap-fee (tuple (num uint) (den uint)))
            (symbol (string-ascii 65))
            (token0 principal)
            (token1 principal)
          ))
          (token-in <velar-sip-010-trait>)
          (token-out <velar-sip-010-trait>)
          (user principal)
        )
        uint
      )
    )
  )
)

(define-trait alex-pool-trait
  (
    (swap-helper-a
      (<bitflow-sip-010-trait> <bitflow-sip-010-trait> <bitflow-sip-010-trait> uint uint uint (optional uint))
      (response uint uint)
    )
  )
)

(define-constant err-bitflow-call (err u120))
(define-constant err-velar-call (err u121))
(define-constant err-negative-profit (err u123))
(define-constant err-profit-too-low (err u124))
(define-constant err-token-mismatch (err u125))
(define-constant err-no-stx-after-bitflow (err u126))
(define-constant err-no-stx-after-velar (err u127))
(define-constant err-velar-zero-out (err u129))
(define-constant err-alex-call (err u130))
(define-constant err-no-leo-after-alex (err u131))
(define-constant err-no-stx-after-alex (err u132))
(define-constant err-invalid-wrapper-scale (err u133))

(define-private (calc-univ2-out
  (amt-in uint)
  (reserve-in uint)
  (reserve-out uint)
  (swap-fee (tuple (num uint) (den uint)))
)
  (let
    (
      (fee-num (get num swap-fee))
      (fee-den (get den swap-fee))
      (amt-in-adjusted (/ (* amt-in fee-num) fee-den))
    )
    (if (<= amt-in-adjusted u0)
      u0
      (/ (* amt-in-adjusted reserve-out) (+ reserve-in amt-in-adjusted))
    )
  )
)

(define-public (execute-bitflow-then-velar
  (bitflow-quote-token <bitflow-sip-010-trait>)
  (bitflow-stx-token <bitflow-sip-010-trait>)
  (velar-quote-token <velar-sip-010-trait>)
  (velar-stx-token <velar-sip-010-trait>)
  (bitflow-core <bitflow-core-trait>)
  (bitflow-pool <xyk-pool-trait>)
  (velar-core <velar-core-trait>)
  (velar-share-fee-to <velar-share-fee-to-trait>)
  (velar-pool-id uint)
  (velar-reserve-in uint)
  (velar-reserve-out uint)
  (velar-swap-fee (tuple (num uint) (den uint)))
  (bitflow-quote-in uint)
  (bitflow-min-stx-out uint)
  (min-profit uint)
)
  (begin
    ;; Enforce that Bitflow/Velar tokens refer to the same underlying contracts.
    (asserts! (is-eq (contract-of bitflow-quote-token) (contract-of velar-quote-token)) err-token-mismatch)

    (let
      (
        (quote-before (unwrap-panic (contract-call? bitflow-quote-token get-balance tx-sender)))
        (stx-before (unwrap-panic (contract-call? bitflow-stx-token get-balance tx-sender)))
        (bitflow-stx-out (unwrap!
          (contract-call?
            bitflow-core
            swap-y-for-x
            bitflow-pool
            bitflow-stx-token
            bitflow-quote-token
            bitflow-quote-in
            bitflow-min-stx-out
          )
          err-bitflow-call
        ))
        (stx-after-bitflow (unwrap-panic (contract-call? bitflow-stx-token get-balance tx-sender)))
      )
      (asserts! (> stx-after-bitflow stx-before) err-no-stx-after-bitflow)
      (let
        (
          (stx-in (- stx-after-bitflow stx-before))
        )
        (let
          (
            (velar-quote-out-raw (calc-univ2-out stx-in velar-reserve-in velar-reserve-out velar-swap-fee))
            (velar-quote-out (if (> velar-quote-out-raw u0) (- velar-quote-out-raw u1) u0))
          )
          (asserts! (> velar-quote-out u0) err-velar-zero-out)
          (unwrap!
            (contract-call?
              velar-core
              swap
              velar-pool-id
              velar-stx-token
              velar-quote-token
              velar-share-fee-to
              stx-in
              velar-quote-out
            )
            err-velar-call
          )
          (let
            (
              (quote-after (unwrap-panic (contract-call? bitflow-quote-token get-balance tx-sender)))
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
                  velar-quote-out: velar-quote-out
                }
              )
            )
          )
        )
      )
    )
  )
)

(define-public (execute-velar-then-bitflow
  (bitflow-quote-token <bitflow-sip-010-trait>)
  (bitflow-stx-token <bitflow-sip-010-trait>)
  (velar-quote-token <velar-sip-010-trait>)
  (velar-stx-token <velar-sip-010-trait>)
  (velar-core <velar-core-trait>)
  (velar-share-fee-to <velar-share-fee-to-trait>)
  (velar-pool-id uint)
  (velar-reserve-in uint)
  (velar-reserve-out uint)
  (velar-swap-fee (tuple (num uint) (den uint)))
  (velar-quote-in uint)
  (bitflow-core <bitflow-core-trait>)
  (bitflow-pool <xyk-pool-trait>)
  (bitflow-min-quote-out uint)
  (min-profit uint)
)
  (begin
    (asserts! (is-eq (contract-of bitflow-quote-token) (contract-of velar-quote-token)) err-token-mismatch)

    (let
      (
        (quote-before (unwrap-panic (contract-call? bitflow-quote-token get-balance tx-sender)))
        (stx-before (unwrap-panic (contract-call? bitflow-stx-token get-balance tx-sender)))
      )
      (let
        (
          (velar-stx-out-raw (calc-univ2-out velar-quote-in velar-reserve-in velar-reserve-out velar-swap-fee))
          (velar-stx-out (if (> velar-stx-out-raw u0) (- velar-stx-out-raw u1) u0))
        )
        (asserts! (> velar-stx-out u0) err-velar-zero-out)
        (unwrap!
          (contract-call?
            velar-core
            swap
            velar-pool-id
            velar-quote-token
            velar-stx-token
            velar-share-fee-to
            velar-quote-in
            velar-stx-out
          )
          err-velar-call
        )

        (let
          (
            (stx-after-velar (unwrap-panic (contract-call? bitflow-stx-token get-balance tx-sender)))
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
                  bitflow-stx-token
                  bitflow-quote-token
                  stx-to-sell
                  bitflow-min-quote-out
                )
                err-bitflow-call
              ))
              (quote-after (unwrap-panic (contract-call? bitflow-quote-token get-balance tx-sender)))
            )
            (asserts! (>= quote-after quote-before) err-negative-profit)
            (let ((profit (- quote-after quote-before)))
              (asserts! (>= profit min-profit) err-profit-too-low)
              (ok
                {
                  quote-before: quote-before,
                  quote-after: quote-after,
                  profit: profit,
                  stx-bought: velar-stx-out,
                  stx-sold: stx-to-sell,
                  bitflow-quote-out: bitflow-quote-out
                }
              )
            )
          )
        )
      )
    )
  )
)

(define-public (execute-bitflow-alex-then-velar
  (bitflow-quote-token <bitflow-sip-010-trait>)
  (bitflow-stx-token <bitflow-sip-010-trait>)
  (velar-quote-token <velar-sip-010-trait>)
  (velar-leo-token <velar-sip-010-trait>)
  (bitflow-core <bitflow-core-trait>)
  (bitflow-pool <xyk-pool-trait>)
  (alex-pool <alex-pool-trait>)
  (alex-stx-token <bitflow-sip-010-trait>)
  (alex-alex-token <bitflow-sip-010-trait>)
  (alex-leo-token <bitflow-sip-010-trait>)
  (alex-factor-stx-alex uint)
  (alex-factor-alex-leo uint)
  (wrapper-scale uint)
  (velar-core <velar-core-trait>)
  (velar-share-fee-to <velar-share-fee-to-trait>)
  (velar-pool-id uint)
  (velar-reserve-in uint)
  (velar-reserve-out uint)
  (velar-swap-fee (tuple (num uint) (den uint)))
  (bitflow-quote-in uint)
  (bitflow-min-stx-out uint)
  (alex-min-leo-out-wrapper uint)
  (min-profit uint)
)
  (begin
    (asserts! (is-eq (contract-of bitflow-quote-token) (contract-of velar-quote-token)) err-token-mismatch)
    (asserts! (> wrapper-scale u0) err-invalid-wrapper-scale)
    (let
      (
        (quote-before (unwrap-panic (contract-call? bitflow-quote-token get-balance tx-sender)))
        (stx-before (unwrap-panic (contract-call? bitflow-stx-token get-balance tx-sender)))
        (bitflow-stx-out (unwrap!
          (contract-call?
            bitflow-core
            swap-y-for-x
            bitflow-pool
            bitflow-stx-token
            bitflow-quote-token
            bitflow-quote-in
            bitflow-min-stx-out
          )
          err-bitflow-call
        ))
        (stx-after-bitflow (unwrap-panic (contract-call? bitflow-stx-token get-balance tx-sender)))
      )
      (asserts! (> stx-after-bitflow stx-before) err-no-stx-after-bitflow)
      (let
        (
          (stx-in (- stx-after-bitflow stx-before))
          (stx-in-wrapper (* (- stx-after-bitflow stx-before) wrapper-scale))
          (alex-leo-out-wrapper (unwrap!
            (contract-call?
              alex-pool
              swap-helper-a
              alex-stx-token
              alex-alex-token
              alex-leo-token
              alex-factor-stx-alex
              alex-factor-alex-leo
              stx-in-wrapper
              (some alex-min-leo-out-wrapper)
            )
            err-alex-call
          ))
        )
        (asserts! (> alex-leo-out-wrapper u0) err-no-leo-after-alex)
        (let
          (
            (leo-in (/ alex-leo-out-wrapper wrapper-scale))
          )
          (asserts! (> leo-in u0) err-no-leo-after-alex)
          (let
            (
              (velar-quote-out-raw (calc-univ2-out leo-in velar-reserve-in velar-reserve-out velar-swap-fee))
              (velar-quote-out (if (> velar-quote-out-raw u0) (- velar-quote-out-raw u1) u0))
            )
            (asserts! (> velar-quote-out u0) err-velar-zero-out)
            (unwrap!
              (contract-call?
                velar-core
                swap
                velar-pool-id
                velar-leo-token
                velar-quote-token
                velar-share-fee-to
                leo-in
                velar-quote-out
              )
              err-velar-call
            )
            (let
              (
                (quote-after (unwrap-panic (contract-call? bitflow-quote-token get-balance tx-sender)))
              )
              (asserts! (>= quote-after quote-before) err-negative-profit)
              (let ((profit (- quote-after quote-before)))
                (asserts! (>= profit min-profit) err-profit-too-low)
                (ok
                  {
                    quote-before: quote-before,
                    quote-after: quote-after,
                    profit: profit,
                    stx-in: stx-in,
                    bitflow-stx-out: bitflow-stx-out,
                    alex-leo-out-wrapper: alex-leo-out-wrapper,
                    velar-quote-out: velar-quote-out
                  }
                )
              )
            )
          )
        )
      )
    )
  )
)

(define-public (execute-velar-then-alex-bitflow
  (bitflow-quote-token <bitflow-sip-010-trait>)
  (bitflow-stx-token <bitflow-sip-010-trait>)
  (velar-quote-token <velar-sip-010-trait>)
  (velar-leo-token <velar-sip-010-trait>)
  (velar-core <velar-core-trait>)
  (velar-share-fee-to <velar-share-fee-to-trait>)
  (velar-pool-id uint)
  (velar-reserve-in uint)
  (velar-reserve-out uint)
  (velar-swap-fee (tuple (num uint) (den uint)))
  (velar-quote-in uint)
  (alex-pool <alex-pool-trait>)
  (alex-leo-token <bitflow-sip-010-trait>)
  (alex-alex-token <bitflow-sip-010-trait>)
  (alex-stx-token <bitflow-sip-010-trait>)
  (alex-factor-alex-leo uint)
  (alex-factor-stx-alex uint)
  (wrapper-scale uint)
  (alex-min-stx-out-wrapper uint)
  (bitflow-core <bitflow-core-trait>)
  (bitflow-pool <xyk-pool-trait>)
  (bitflow-min-quote-out uint)
  (min-profit uint)
)
  (begin
    (asserts! (is-eq (contract-of bitflow-quote-token) (contract-of velar-quote-token)) err-token-mismatch)
    (asserts! (> wrapper-scale u0) err-invalid-wrapper-scale)
    (let
      (
        (quote-before (unwrap-panic (contract-call? bitflow-quote-token get-balance tx-sender)))
      )
      (let
        (
          (velar-leo-out-raw (calc-univ2-out velar-quote-in velar-reserve-in velar-reserve-out velar-swap-fee))
          (velar-leo-out (if (> velar-leo-out-raw u0) (- velar-leo-out-raw u1) u0))
        )
        (asserts! (> velar-leo-out u0) err-velar-zero-out)
        (unwrap!
          (contract-call?
            velar-core
            swap
            velar-pool-id
            velar-quote-token
            velar-leo-token
            velar-share-fee-to
            velar-quote-in
            velar-leo-out
          )
          err-velar-call
        )
        (let
          (
            (leo-in-wrapper (* velar-leo-out wrapper-scale))
            (alex-stx-out-wrapper (unwrap!
              (contract-call?
                alex-pool
                swap-helper-a
                alex-leo-token
                alex-alex-token
                alex-stx-token
                alex-factor-alex-leo
                alex-factor-stx-alex
                leo-in-wrapper
                (some alex-min-stx-out-wrapper)
              )
              err-alex-call
            ))
          )
          (asserts! (> alex-stx-out-wrapper u0) err-no-stx-after-alex)
          (let
            (
              (stx-to-sell (/ alex-stx-out-wrapper wrapper-scale))
            )
            (asserts! (> stx-to-sell u0) err-no-stx-after-alex)
            (let
              (
                (bitflow-quote-out (unwrap!
                  (contract-call?
                    bitflow-core
                    swap-x-for-y
                    bitflow-pool
                    bitflow-stx-token
                    bitflow-quote-token
                    stx-to-sell
                    bitflow-min-quote-out
                  )
                  err-bitflow-call
                ))
                (quote-after (unwrap-panic (contract-call? bitflow-quote-token get-balance tx-sender)))
              )
              (asserts! (>= quote-after quote-before) err-negative-profit)
              (let ((profit (- quote-after quote-before)))
                (asserts! (>= profit min-profit) err-profit-too-low)
                (ok
                  {
                    quote-before: quote-before,
                    quote-after: quote-after,
                    profit: profit,
                    velar-leo-out: velar-leo-out,
                    alex-stx-out-wrapper: alex-stx-out-wrapper,
                    stx-sold: stx-to-sell,
                    bitflow-quote-out: bitflow-quote-out
                  }
                )
              )
            )
          )
        )
      )
    )
  )
)
