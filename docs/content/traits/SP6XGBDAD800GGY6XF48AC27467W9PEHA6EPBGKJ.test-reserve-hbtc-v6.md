---
title: "Trait test-reserve-hbtc-v6"
draft: true
---
```
;; @contract Reserve
;; @version 0.1
;; @description Main reserve contract holding protocol assets

(use-trait ft .sip-010-trait.sip-010-trait)

(define-constant ERR_INSUFFICIENT_BALANCE (err u105001))

;;-------------------------------------
;; Transfer
;;-------------------------------------

;; @desc - transfers asset to recipient
;; @param - asset: asset to transfer (sip-010-trait)
;; @param - amount: amount of asset to transfer (10**8)
;; @param - recipient: recipient of the asset
(define-public (transfer (asset <ft>) (amount uint) (recipient principal))
  (let (
    (balance (try! (contract-call? asset get-balance current-contract)))
  )
    (try! (contract-call? .test-hq-vaults-v6 check-is-protocol-two contract-caller recipient))
    (try! (contract-call? .test-state-hbtc-v6 check-transfer-auth (contract-of asset)))
    (asserts! (>= balance amount) ERR_INSUFFICIENT_BALANCE)
    (print { action: "transfer", user: contract-caller, data: { asset: asset, amount: amount, recipient: recipient, sender: current-contract, balance: balance }})
    (as-contract? ((with-ft (contract-of asset) "*" amount)) (try! (contract-call? asset transfer amount current-contract recipient none)))
  )
)
```
