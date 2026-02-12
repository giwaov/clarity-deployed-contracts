---
title: "Trait remarkable-emerald-fox"
draft: true
---
```
(define-trait route-engine-trait
  (
    (ss ((buff 400)) (response (list 20 (response uint uint)) uint))
  )
)

(define-trait quote-token-trait
  (
    (get-balance (principal) (response uint uint))
  )
)

(define-constant err-first-leg-call (err u120))
(define-constant err-second-leg-call (err u121))
(define-constant err-first-leg-step (err u122))
(define-constant err-second-leg-step (err u123))
(define-constant err-negative-profit (err u124))
(define-constant err-profit-too-low (err u125))
(define-constant err-route-empty (err u127))

(define-public (execute-bitflow-then-velar
  (quote-token <quote-token-trait>)
  (bitflow-route (buff 400))
  (bitflow-engine <route-engine-trait>)
  (velar-route (buff 400))
  (velar-engine <route-engine-trait>)
  (min-profit uint)
)
  (execute-pair
    quote-token
    true
    bitflow-route
    bitflow-engine
    velar-route
    velar-engine
    min-profit
  )
)

(define-public (execute-velar-then-bitflow
  (quote-token <quote-token-trait>)
  (velar-route (buff 400))
  (velar-engine <route-engine-trait>)
  (bitflow-route (buff 400))
  (bitflow-engine <route-engine-trait>)
  (min-profit uint)
)
  (execute-pair
    quote-token
    false
    velar-route
    velar-engine
    bitflow-route
    bitflow-engine
    min-profit
  )
)

(define-private (execute-pair
  (quote-token <quote-token-trait>)
  (first-is-bitflow bool)
  (first-route (buff 400))
  (first-engine <route-engine-trait>)
  (second-route (buff 400))
  (second-engine <route-engine-trait>)
  (min-profit uint)
)
  (begin
    (asserts! (> (len first-route) u0) err-route-empty)
    (asserts! (> (len second-route) u0) err-route-empty)
    (let
      (
        (balance-before (unwrap-panic (contract-call? quote-token get-balance tx-sender)))
        (first-raw (if first-is-bitflow
          (contract-call? 'SP5KCQ6CQAS73AMM002HMK94CCYEA4P3C94VX3K4.mole r first-route first-engine)
          (contract-call? 'SP2H674PRTZV6YW56K0FMR7GDGZE4ZC5HMYZ3CDEV.dome r first-route first-engine)
        ))
      )
      (let ((first-result (unwrap! first-raw err-first-leg-call)))
        (asserts! (all-steps-ok first-result) err-first-leg-step)
        (let
          (
            (second-raw (if first-is-bitflow
              (contract-call? 'SP2H674PRTZV6YW56K0FMR7GDGZE4ZC5HMYZ3CDEV.dome r second-route second-engine)
              (contract-call? 'SP5KCQ6CQAS73AMM002HMK94CCYEA4P3C94VX3K4.mole r second-route second-engine)
            ))
            (second-result (unwrap! second-raw err-second-leg-call))
          )
          (asserts! (all-steps-ok second-result) err-second-leg-step)
          (let ((balance-after (unwrap-panic (contract-call? quote-token get-balance tx-sender))))
            (asserts! (>= balance-after balance-before) err-negative-profit)
            (let ((profit (- balance-after balance-before)))
              (asserts! (>= profit min-profit) err-profit-too-low)
              (ok
                {
                  balance-before: balance-before,
                  balance-after: balance-after,
                  profit: profit
                }
              )
            )
          )
        )
      )
    )
  )
)

(define-private (all-steps-ok (steps (list 20 (response uint uint))))
  (fold step-ok steps true)
)

(define-private (step-ok (step (response uint uint)) (acc bool))
  (if acc
    (match step
      step-ok-value true
      step-err-value false
    )
    false
  )
)

```
