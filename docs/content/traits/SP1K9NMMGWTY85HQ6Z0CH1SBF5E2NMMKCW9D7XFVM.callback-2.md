---
title: "Trait callback-2"
draft: true
---
```

(define-constant MARKET 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-market)
(define-constant VAULT-USDH 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-usdh)
(define-constant VAULT-STX 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-stx)
(define-constant WSTX-TOKEN 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-wstx)
(define-constant DEX-ROUTER 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-v-1-3)
(define-constant TOKEN-AEUSDC 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc)
(define-constant TOKEN-USDH 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1)
(define-constant TOKEN-STX-VELAR 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-1)
(define-constant POOL-AEUSDC-USDH 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdh-v-1-2)
(define-constant POOL-STX-AEUSDC 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-1)

(impl-trait 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-traits.flash-callback)

(define-constant ERR-NO-DATA (err u920001))
(define-constant ERR-DECODE-FAILED (err u920003))


(define-private (decode-u128 (data (buff 4096)) (start uint))
  (buff-to-uint-be (unwrap-panic (as-max-len? (default-to 0x (slice? data start (+ start u16))) u16))))

(define-private (decode-principal (data (buff 4096)) (start uint))
  (let ((version (default-to u0 (match (element-at? data start) b (some (buff-to-uint-be b)) none)))
        (hash (unwrap-panic (as-max-len? (default-to 0x (slice? data (+ start u1) (+ start u21))) u20))))
    (if (is-eq version u22)
        (unwrap-panic (principal-construct? 0x16 hash))
        (if (is-eq version u26)
            (unwrap-panic (principal-construct? 0x1a hash))
            (if (is-eq version u20)
                (unwrap-panic (principal-construct? 0x14 hash))
                (if (is-eq version u21)
                    (unwrap-panic (principal-construct? 0x15 hash))
                    (unwrap-panic (principal-construct? 0x1a hash))))))))

(define-public (callback
    (amount uint)
    (fee uint)
    (data (optional (buff 4096))))
  (let ((buf (unwrap! data ERR-NO-DATA))
        (caller tx-sender)
        (borrower (decode-principal buf u0))
        (debt-amount (decode-u128 buf u21))
        (min-collateral (decode-u128 buf u37))
        (min-underlying (decode-u128 buf u53))
        (min-swap-out (decode-u128 buf u69)))
    (as-contract? ((with-all-assets-unsafe))
      (let ((liq-result (try! (contract-call?
                                'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-market
                                liquidate-redeem
                                borrower
                                'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-usdh
                                'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-wstx
                                debt-amount
                                min-collateral
                                min-underlying
                                none
                                none))))
        (let ((stx-from-swap (try! (contract-call?
                                    'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-v-1-3
                                    swap-helper-a
                                    (get underlying liq-result)
                                    min-swap-out
                                    none
                                    true
                                    { a: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc,
                                      b: 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1 }
                                    { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdh-v-1-2 }
                                    { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-1,
                                      b: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc }
                                    { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-1 }))))
          (let ((stx-balance (unwrap-panic (contract-call?
                                'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-wstx
                                get-balance
                                tx-sender))))
            (try! (contract-call?
                    'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-wstx
                    transfer
                    stx-balance
                    tx-sender
                    caller
                    none))
            (print {
              action: "flashloan-liquidation-stx-zusdh-v2",
              borrower: borrower,
              debt-amount: debt-amount,
              usdh-received: (get underlying liq-result),
              stx-from-swap: stx-from-swap,
              stx-balance: stx-balance,
              caller: caller
            })
            true))))))

```
