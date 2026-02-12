---
title: "Trait keeper-action-17-v-1-1"
draft: true
---
```
;; keeper-action-17-v-1-1

;; Implement keeper action trait
(impl-trait .keeper-action-trait-v-1-3.keeper-action-trait)

;; Use all required traits
(use-trait ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)
(use-trait xyk-staking-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-staking-trait-v-1-2.xyk-staking-trait)
(use-trait xyk-emissions-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-emissions-trait-v-1-2.xyk-emissions-trait)
(use-trait stableswap-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-2.stableswap-pool-trait)
(use-trait stableswap-staking-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-staking-trait-v-1-2.stableswap-staking-trait)
(use-trait stableswap-emissions-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-emissions-trait-v-1-2.stableswap-emissions-trait)
(use-trait dlmm-pool-trait .dlmm-pool-trait-v-0-1.dlmm-pool-trait)
(use-trait dlmm-staking-trait .dlmm-staking-trait-v-0-1.dlmm-staking-trait)

;; Error constants
(define-constant ERR_INVALID_HELPER_DATA (err u10003))
(define-constant ERR_INVALID_PARAMETER_LIST (err u10004))
(define-constant ERR_INVALID_LIST_ELEMENT (err u10005))

;; Get output for execute-action function
(define-public (get-output
    (amount uint) (min-received uint)
    (fee-recipient principal) (owner-address principal)
    (bitcoin-address (buff 64)) (keeper-address principal)
    (token-list (optional (list 1000 <ft-trait>)))
    (xyk-pool-list (optional (list 1000 <xyk-pool-trait>)))
    (xyk-staking-list (optional (list 1000 <xyk-staking-trait>)))
    (xyk-emissions-list (optional (list 1000 <xyk-emissions-trait>)))
    (stableswap-pool-list (optional (list 1000 <stableswap-pool-trait>)))
    (stableswap-staking-list (optional (list 1000 <stableswap-staking-trait>)))
    (stableswap-emissions-list (optional (list 1000 <stableswap-emissions-trait>)))
    (dlmm-pool-list (optional (list 1000 <dlmm-pool-trait>)))
    (dlmm-staking-list (optional (list 1000 <dlmm-staking-trait>)))
    (uint-list (optional (list 1000 uint)))
    (bool-list (optional (list 1000 bool)))
    (principal-list (optional (list 1000 principal)))
  )
  (let (

  )
    (ok u0)
  )
)

;; Get minimum amount for execute-action function
(define-public (get-minimum
    (amount uint) (min-received uint)
    (fee-recipient principal) (owner-address principal)
    (bitcoin-address (buff 64)) (keeper-address principal)
    (token-list (optional (list 1000 <ft-trait>)))
    (xyk-pool-list (optional (list 1000 <xyk-pool-trait>)))
    (xyk-staking-list (optional (list 1000 <xyk-staking-trait>)))
    (xyk-emissions-list (optional (list 1000 <xyk-emissions-trait>)))
    (stableswap-pool-list (optional (list 1000 <stableswap-pool-trait>)))
    (stableswap-staking-list (optional (list 1000 <stableswap-staking-trait>)))
    (stableswap-emissions-list (optional (list 1000 <stableswap-emissions-trait>)))
    (dlmm-pool-list (optional (list 1000 <dlmm-pool-trait>)))
    (dlmm-staking-list (optional (list 1000 <dlmm-staking-trait>)))
    (uint-list (optional (list 1000 uint)))
    (bool-list (optional (list 1000 bool)))
    (principal-list (optional (list 1000 principal)))
  )
  (let (

  )
    (ok u0)
  )
)

;; Perform execute-action function
(define-public (execute-action 
    (amount uint) (min-received uint)
    (fee-recipient principal) (owner-address principal)
    (bitcoin-address (buff 64)) (keeper-address principal)
    (token-list (optional (list 1000 <ft-trait>)))
    (xyk-pool-list (optional (list 1000 <xyk-pool-trait>)))
    (xyk-staking-list (optional (list 1000 <xyk-staking-trait>)))
    (xyk-emissions-list (optional (list 1000 <xyk-emissions-trait>)))
    (stableswap-pool-list (optional (list 1000 <stableswap-pool-trait>)))
    (stableswap-staking-list (optional (list 1000 <stableswap-staking-trait>)))
    (stableswap-emissions-list (optional (list 1000 <stableswap-emissions-trait>)))
    (dlmm-pool-list (optional (list 1000 <dlmm-pool-trait>)))
    (dlmm-staking-list (optional (list 1000 <dlmm-staking-trait>)))
    (uint-list (optional (list 1000 uint)))
    (bool-list (optional (list 1000 bool)))
    (principal-list (optional (list 1000 principal)))
  )
  (let (
    ;; Unwrap required lists from parameters
    (unwrapped-token-list (unwrap! token-list ERR_INVALID_PARAMETER_LIST))
    (unwrapped-dlmm-pool-list (unwrap! dlmm-pool-list ERR_INVALID_PARAMETER_LIST))
    (unwrapped-uint-list (unwrap! uint-list ERR_INVALID_PARAMETER_LIST))
    (unwrapped-bool-list (unwrap! bool-list ERR_INVALID_PARAMETER_LIST))

    ;; Get token a trait
    (token-trait-a (unwrap! (element-at? unwrapped-token-list u0) ERR_INVALID_LIST_ELEMENT))

    ;; Get keeper fee and calculate updated amount
    (keeper-fee-amount u0);;(unwrap! (contract-call? .keeper-5-helper-v-1-1-dev get-keeper-fee-amount amount) ERR_INVALID_HELPER_DATA))
    (amount-after-keeper-fee (- amount keeper-fee-amount))

    ;; Transfer keeper fee from the contract to fee-recipient
    (transfer-keeper-fee (if (> keeper-fee-amount u0)
      (try! (contract-call? token-trait-a transfer keeper-fee-amount tx-sender fee-recipient none))
      false
    ))

    ;; Perform swap and get final swap result
    (swap-a (if (>= (len unwrapped-token-list) u2) (try! (swap-sa amount-after-keeper-fee owner-address unwrapped-token-list unwrapped-dlmm-pool-list unwrapped-uint-list unwrapped-bool-list u0)) {in: u0, out: u0}))
    (swap-b (if (>= (len unwrapped-token-list) u4) (try! (swap-sa amount-after-keeper-fee owner-address unwrapped-token-list unwrapped-dlmm-pool-list unwrapped-uint-list unwrapped-bool-list u1)) {in: u0, out: u0}))
    (swap-c (if (>= (len unwrapped-token-list) u6) (try! (swap-sa amount-after-keeper-fee owner-address unwrapped-token-list unwrapped-dlmm-pool-list unwrapped-uint-list unwrapped-bool-list u2)) {in: u0, out: u0}))
    (swap-d (if (>= (len unwrapped-token-list) u8) (try! (swap-sa amount-after-keeper-fee owner-address unwrapped-token-list unwrapped-dlmm-pool-list unwrapped-uint-list unwrapped-bool-list u3)) {in: u0, out: u0}))
    (swap-e (if (>= (len unwrapped-token-list) u10) (try! (swap-sa amount-after-keeper-fee owner-address unwrapped-token-list unwrapped-dlmm-pool-list unwrapped-uint-list unwrapped-bool-list u4)) {in: u0, out: u0}))
  )
    (begin
      ;; Print action data and return u0
      (print {
        action: "execute-action",
        contract: (as-contract tx-sender),
        caller: tx-sender,
        data: {
          keeper-fee-amount: keeper-fee-amount,
          swap-a: swap-a,
          swap-b: swap-b,
          swap-c: swap-c,
          swap-d: swap-d,
          swap-e: swap-e
        }
      })
      (ok u0)
    )
  )
)

(define-private (swap-sa
  (amount uint) (owner-address principal)
  (tokens (list 1000 <ft-trait>))
  (dlmm-pools (list 1000 <dlmm-pool-trait>))
  (uints (list 1000 uint))
  (bools (list 1000 bool))
  (swap-index uint)
)
  (let (

    ;; Get list indexes
    (token-trait-a-index (* swap-index u2))
    (token-trait-b-index (+ (* swap-index u2) u1))
    (dlmm-pool-trait-a-index swap-index)
    (amount-a-index (* swap-index u2))
    (min-received-a-index (+ (* swap-index u2) u1))
    (swap-reversed-a-index (* swap-index u2))
    (should-transfer-a-index (+ (* swap-index u2) u1))

    ;; Get tokens, DLMM pool traits, uints, and bools
    (token-trait-a (unwrap! (element-at? tokens token-trait-a-index) ERR_INVALID_LIST_ELEMENT))
    (token-trait-b (unwrap! (element-at? tokens token-trait-b-index) ERR_INVALID_LIST_ELEMENT))
    (dlmm-pool-trait-a (unwrap! (element-at? dlmm-pools dlmm-pool-trait-a-index) ERR_INVALID_LIST_ELEMENT))
    (amount-a (unwrap! (element-at? uints amount-a-index) ERR_INVALID_LIST_ELEMENT))
    (min-received-a (unwrap! (element-at? uints min-received-a-index) ERR_INVALID_LIST_ELEMENT))
    (swap-reversed-a (unwrap! (element-at? bools swap-reversed-a-index) ERR_INVALID_LIST_ELEMENT))
    (should-transfer-a (unwrap! (element-at? bools should-transfer-a-index) ERR_INVALID_LIST_ELEMENT))

    ;; Perform swap
    (swap-a (if (is-eq swap-reversed-a false)
      (try! (contract-call? .dlmm-swap-router-v-0-1 swap-x-for-y-simple-multi dlmm-pool-trait-a token-trait-a token-trait-b amount-a min-received-a))
      (try! (contract-call? .dlmm-swap-router-v-0-1 swap-y-for-x-simple-multi dlmm-pool-trait-a token-trait-a token-trait-b amount-a min-received-a)))
    )
  )
    ;; Transfer swap-a b tokens from the contract to owner-address if should-transfer-a is true
    (if should-transfer-a (try! (contract-call? token-trait-b transfer (get out swap-a) tx-sender owner-address none)) false)

    ;; Return swap-a
    (ok swap-a)
  )
)
```
