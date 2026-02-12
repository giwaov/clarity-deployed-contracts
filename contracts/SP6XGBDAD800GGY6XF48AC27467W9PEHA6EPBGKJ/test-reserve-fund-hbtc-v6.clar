;; @contract Reserve Fund
;; @version 0.1
;; @description Reserve fund contract to cover negative rewards

(use-trait ft .sip-010-trait.sip-010-trait)

(define-constant ERR_INSUFFICIENT_BALANCE (err u106001))

;;-------------------------------------
;; Transfer
;;-------------------------------------

;; @desc - transfers asset from reserve fund to recipient
;; @param - asset: asset to transfer (sip-010-trait)
;; @param - amount: amount of asset to transfer (10**8)
;; @param - recipient: recipient of the asset
;; @param - memo: optional memo for the transfer
(define-public (transfer (asset <ft>) (amount uint) (recipient principal) (memo (optional (buff 34))))
  (let (
    (balance (try! (contract-call? asset get-balance current-contract)))
  )
    (try! (contract-call? .test-hq-vaults-v6 check-is-protocol contract-caller))
    (try! (contract-call? .test-state-hbtc-v6 check-transfer-auth (contract-of asset)))
    (asserts! (>= balance amount) ERR_INSUFFICIENT_BALANCE)
    (print { action: "transfer", user: contract-caller, data: { asset: asset, amount: amount, recipient: recipient, sender: current-contract, balance: balance }})
    (as-contract? ((with-ft (contract-of asset) "*" amount)) (try! (contract-call? asset transfer amount current-contract recipient memo)))
  )
)