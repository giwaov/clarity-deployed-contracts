---
title: "Trait sbtc-yield-vault"
draft: true
---
```

;; sBTC Yield Vault - Minimal Version
;; Deployer: SP2QXPFF4M72QYZWXE7S5321XJDJ2DD32DGEMN5QA

(define-constant CONTRACT_OWNER tx-sender)
(define-constant SBTC_TOKEN 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)
(define-constant MAX_TVL u100000000)
(define-constant MANAGEMENT_FEE_BPS u1000)
(define-constant PRECISION u100000000)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_AMOUNT (err u1002))
(define-constant ERR_TVL_CAP_EXCEEDED (err u1004))

(define-fungible-token vault-shares)

(define-data-var vault-paused bool false)
(define-data-var total-assets uint u0)
(define-data-var pending-fees uint u0)

(define-private (calculate-shares-for-deposit (amount uint))
  (let ((total-supply (ft-get-supply vault-shares))
        (assets (var-get total-assets)))
    (if (is-eq total-supply u0)
      amount
      (/ (* amount total-supply) assets))))

(define-private (calculate-assets-for-shares (shares uint))
  (let ((total-supply (ft-get-supply vault-shares))
        (assets (var-get total-assets)))
    (if (is-eq total-supply u0)
      u0
      (/ (* shares assets) total-supply))))

(define-public (deposit (amount uint))
  (let ((sender tx-sender)
        (current-assets (var-get total-assets))
        (shares-to-mint (calculate-shares-for-deposit amount)))
    (asserts! (not (var-get vault-paused)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= (+ current-assets amount) MAX_TVL) ERR_TVL_CAP_EXCEEDED)
    (try! (ft-mint? vault-shares shares-to-mint sender))
    (var-set total-assets (+ current-assets amount))
    (print {event: "deposit", user: sender, amount: amount, shares: shares-to-mint})
    (ok shares-to-mint)))

(define-public (withdraw (shares uint))
  (let ((sender tx-sender)
        (user-shares (ft-get-balance vault-shares sender))
        (assets-to-return (calculate-assets-for-shares shares)))
    (asserts! (not (var-get vault-paused)) ERR_UNAUTHORIZED)
    (asserts! (> shares u0) ERR_INVALID_AMOUNT)
    (asserts! (<= shares user-shares) ERR_UNAUTHORIZED)
    (try! (ft-burn? vault-shares shares sender))
    (var-set total-assets (- (var-get total-assets) assets-to-return))
    (print {event: "withdraw", user: sender, shares: shares, assets: assets-to-return})
    (ok assets-to-return)))

(define-read-only (get-share-price)
  (let ((total-supply (ft-get-supply vault-shares))
        (assets (var-get total-assets)))
    (if (is-eq total-supply u0)
      PRECISION
      (/ (* assets PRECISION) total-supply))))

(define-read-only (get-vault-stats)
  {total-assets: (var-get total-assets),
   total-shares: (ft-get-supply vault-shares),
   share-price: (get-share-price),
   tvl-cap: MAX_TVL,
   is-paused: (var-get vault-paused)})

(define-read-only (get-user-shares (user principal))
  (ft-get-balance vault-shares user))

(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set vault-paused paused)
    (ok true)))

```
