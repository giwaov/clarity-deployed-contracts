---
title: "Trait callback-1"
draft: true
---
```
;; test

(define-constant MARKET 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-market)

(define-constant VAULT-SBTC 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-sbtc)
(define-constant VAULT-USDH 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-usdh)
(define-constant VAULT-STX 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-stx)

(define-constant SBTC-TOKEN 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)
(define-constant USDH-TOKEN 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1)
(define-constant WSTX-TOKEN 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-wstx)

(define-constant MINTING-AUTO 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.minting-auto-v1-2)

(define-constant PYTH-STORAGE 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.pyth-storage-v4)
(define-constant PYTH-DECODER 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.pyth-pnau-decoder-v3)
(define-constant WORMHOLE-CORE 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.wormhole-core-v4)

(define-constant DEX-ROUTER 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-v-1-3)

(define-constant TOKEN-AEUSDC 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc)
(define-constant TOKEN-STX-VELAR 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-1)
(define-constant POOL-AEUSDC-USDH 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdh-v-1-2)
(define-constant POOL-STX-AEUSDC 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-1)

(impl-trait 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-traits.flash-callback)

(define-constant OP-SBTC-MINT-USDH u1)

(define-constant OP-STX-ZUSDH-SWAP u2)

(define-constant ERR-NO-DATA (err u910001))
(define-constant ERR-UNKNOWN-OP (err u910002))
(define-constant ERR-DECODE-FAILED (err u910003))
(define-constant ERR-LIQUIDATION-FAILED (err u910004))
(define-constant ERR-SWAP-FAILED (err u910005))
(define-constant ERR-MINT-FAILED (err u910006))
(define-constant ERR-INSUFFICIENT-PROFIT (err u910007))

(define-data-var callback-caller principal tx-sender)

(define-private (get-u8 (data (buff 4096)) (pos uint))
  (match (element-at? data pos)
    byte (buff-to-uint-be byte)
    u0))

(define-private (decode-u128 (data (buff 4096)) (start uint))
  (let (
    (end (+ start u16))
    (segment (default-to 0x (slice? data start end)))
  )
    (buff-to-uint-be (unwrap-panic (as-max-len? segment u16)))))

(define-private (decode-principal (data (buff 4096)) (start uint))
  (let (
    (version-pos start)
    (hash-start (+ start u1))
    (hash-end (+ start u21))
    (version-byte (get-u8 data version-pos))
    (hash-segment (default-to 0x (slice? data hash-start hash-end)))
    (hash-20 (unwrap-panic (as-max-len? hash-segment u20)))
  )
    (principal-construct-from-version-and-hash version-byte hash-20)))

(define-private (principal-construct-from-version-and-hash (version uint) (hash (buff 20)))
  (if (is-eq version u22)
      (unwrap-panic (principal-construct? 0x16 hash)) 
      (if (is-eq version u26)
          (unwrap-panic (principal-construct? 0x1a hash)) 
          (if (is-eq version u20)
              (unwrap-panic (principal-construct? 0x14 hash)) 
              (if (is-eq version u21)
                  (unwrap-panic (principal-construct? 0x15 hash))
                  (if (is-eq version u25)
                      (unwrap-panic (principal-construct? 0x19 hash))
                      (unwrap-panic (principal-construct? 0x1a hash))))))))

(define-public (callback
    (amount uint)
    (fee uint)
    (data (optional (buff 4096))))
  (let (
    (buf (unwrap! data ERR-NO-DATA))
    (op (get-u8 buf u0))
    (caller tx-sender)
  )

    (var-set callback-caller caller)

    (if (is-eq op OP-SBTC-MINT-USDH)
        (handle-sbtc-mint-usdh amount fee buf caller)
    (if (is-eq op OP-STX-ZUSDH-SWAP)
        (handle-stx-zusdh-swap amount fee buf caller)
    ERR-UNKNOWN-OP))))

(define-private (handle-sbtc-mint-usdh (amount uint) (fee uint) (data (buff 4096)) (caller principal))
  (let (
    (borrower (decode-principal data u1))
    (debt-amount (decode-u128 data u22))
    (min-collateral (decode-u128 data u38))
    (min-underlying (decode-u128 data u54))
    (profit-recipient (decode-principal data u70))
    (total-repayment (+ amount fee))
  )
    (execute-sbtc-mint-usdh-strategy borrower debt-amount min-collateral min-underlying profit-recipient total-repayment caller)))

(define-private (execute-sbtc-mint-usdh-strategy
    (borrower principal)
    (debt-amount uint)
    (min-collateral uint)
    (min-underlying uint)
    (profit-recipient principal)
    (total-repayment uint)
    (caller principal))
  (ok (try! (as-contract? ((with-all-assets-unsafe))
    (begin
      (try! (contract-call?
        'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.minting-auto-v1-2
        mint
        'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        debt-amount
        u2000
        none
        none
        {
          pyth-storage-contract: 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.pyth-storage-v4,
          pyth-decoder-contract: 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.pyth-pnau-decoder-v3,
          wormhole-core-contract: 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.wormhole-core-v4
        }))

      (let ((liq-result (try! (contract-call?
                            'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-market
                            liquidate-redeem
                            borrower
                            'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-sbtc
                            'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1
                            debt-amount
                            min-collateral
                            min-underlying
                            none
                            none))))

        (let ((sbtc-received (get underlying liq-result)))

          (let ((sbtc-balance (unwrap-panic (contract-call?
                                'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
                                get-balance
                                tx-sender))))

            (try! (contract-call?
              'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
              transfer
              sbtc-balance
              tx-sender
              caller
              none))

            (print {
              action: "flashloan-liquidation-sbtc-mint-usdh",
              borrower: borrower,
              debt-amount: debt-amount,
              sbtc-received: sbtc-received,
              sbtc-balance: sbtc-balance,
              total-repayment: total-repayment,
              profit-recipient: caller,
              caller: caller
            })

            true))))))))

(define-private (handle-stx-zusdh-swap (amount uint) (fee uint) (data (buff 4096)) (caller principal))
  (let (
    (borrower (decode-principal data u1))
    (debt-amount (decode-u128 data u22))
    (min-collateral (decode-u128 data u38))
    (min-underlying (decode-u128 data u54))
    (min-swap-out (decode-u128 data u70))
    (profit-recipient (decode-principal data u86))
    (total-repayment (+ amount fee))
  )
    (execute-stx-zusdh-strategy borrower debt-amount min-collateral min-underlying min-swap-out profit-recipient total-repayment caller)))

(define-private (execute-stx-zusdh-strategy
    (borrower principal)
    (debt-amount uint)
    (min-collateral uint)
    (min-underlying uint)
    (min-swap-out uint)
    (profit-recipient principal)
    (total-repayment uint)
    (caller principal))
  (ok (try! (as-contract? ((with-all-assets-unsafe))
    (begin
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

        (let ((usdh-received (get underlying liq-result)))

          (let ((stx-from-swap (try! (contract-call?
                                      'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-v-1-3
                                      swap-helper-a
                                      usdh-received
                                      min-swap-out
                                      none             
                                      true            
                                      {
                                        a: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc,
                                        b: 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1
                                      }
                                      {
                                        a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdh-v-1-2
                                      }
                                      {
                                        a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-1,
                                        b: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc
                                      }
                                      {
                                        a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-1
                                      }))))

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
                action: "flashloan-liquidation-stx-zusdh",
                borrower: borrower,
                debt-amount: debt-amount,
                usdh-received: usdh-received,
                stx-from-swap: stx-from-swap,
                stx-balance: stx-balance,
                total-repayment: total-repayment,
                profit-recipient: caller,
                caller: caller
              })

              true)))))))))

(define-read-only (get-op-sbtc-mint-usdh)
  OP-SBTC-MINT-USDH)

(define-read-only (get-op-stx-zusdh-swap)
  OP-STX-ZUSDH-SWAP)

```
