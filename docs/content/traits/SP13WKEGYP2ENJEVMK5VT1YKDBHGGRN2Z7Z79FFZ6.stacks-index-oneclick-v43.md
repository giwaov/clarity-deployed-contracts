---
title: "Trait stacks-index-oneclick-v43"
draft: true
---
```
;; =====================================================================
;; StacksIndex OneClick V43 - Simple swap-helper-a only
;; =====================================================================
;;
;; V43: Only uses swap-helper-a for USDCx <-> STX
;; No chained swaps - just simple direct calls
;;
;; =====================================================================

;; =====================
;; DATA VARIABLES
;; =====================

(define-data-var total-investments uint u0)
(define-data-var total-volume uint u0)
(define-data-var total-sells uint u0)
(define-data-var total-sell-volume uint u0)

;; =====================
;; READ-ONLY FUNCTIONS
;; =====================

(define-read-only (get-stats)
  {
    total-investments: (var-get total-investments),
    total-volume: (var-get total-volume),
    total-sells: (var-get total-sells),
    total-sell-volume: (var-get total-sell-volume)
  }
)

;; =====================================================================
;; SWAP FUNCTIONS - Using swap-helper-a (confirmed working)
;; =====================================================================

;; USDCx -> STX via Bitflow swap-helper-a
(define-public (swap-usdcx-to-stx
    (amount uint)
    (min-out uint)
  )
  (begin
    (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2
      swap-helper-a
      amount
      min-out
      none
      false
      { a: 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx, b: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc }
      { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdcx-v-1-1 }
      { a: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, b: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2 }
      { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-2 }
    ))
    (var-set total-investments (+ (var-get total-investments) u1))
    (var-set total-volume (+ (var-get total-volume) amount))
    (print { event: "swap-usdcx-to-stx-v43", user: tx-sender, amount: amount })
    (ok true)
  )
)

;; STX -> USDCx via Bitflow (reversed)
(define-public (swap-stx-to-usdcx
    (amount uint)
    (min-out uint)
  )
  (begin
    (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2
      swap-helper-a
      amount
      min-out
      none
      true
      { a: 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx, b: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc }
      { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdcx-v-1-1 }
      { a: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, b: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2 }
      { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-2 }
    ))
    (var-set total-sells (+ (var-get total-sells) u1))
    (var-set total-sell-volume (+ (var-get total-sell-volume) amount))
    (print { event: "swap-stx-to-usdcx-v43", user: tx-sender, amount: amount })
    (ok true)
  )
)

;; =====================================================================
;; INVEST FUNCTION - Simple STX only
;; =====================================================================

(define-public (invest-stx
    (usdcx-amount uint)
    (min-stx-out uint)
  )
  (begin
    (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2
      swap-helper-a
      usdcx-amount
      min-stx-out
      none
      false
      { a: 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx, b: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc }
      { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdcx-v-1-1 }
      { a: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, b: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2 }
      { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-2 }
    ))
    (var-set total-investments (+ (var-get total-investments) u1))
    (var-set total-volume (+ (var-get total-volume) usdcx-amount))
    (print { event: "invest-stx-v43", investor: tx-sender, amount: usdcx-amount })
    (ok { invested: usdcx-amount })
  )
)

;; =====================================================================
;; SELL FUNCTION - Simple STX only
;; =====================================================================

(define-public (sell-stx
    (stx-amount uint)
    (min-usdcx-out uint)
  )
  (begin
    (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2
      swap-helper-a
      stx-amount
      min-usdcx-out
      none
      true
      { a: 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx, b: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc }
      { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdcx-v-1-1 }
      { a: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, b: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2 }
      { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-2 }
    ))
    (var-set total-sells (+ (var-get total-sells) u1))
    (var-set total-sell-volume (+ (var-get total-sell-volume) stx-amount))
    (print { event: "sell-stx-v43", seller: tx-sender, amount: stx-amount })
    (ok { sold: stx-amount })
  )
)

;; =====================
;; END OF CONTRACT
;; =====================

```
