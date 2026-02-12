---
title: "Trait VestingSTX2"
draft: true
---
```
;; SFTVault
;; <add a description here>

;; constants
;;

;; data maps and vars
;;
;; title: asset

;; private functions
;;
;; Define error constants ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-constant err-not-authorized (err u100))
(define-constant err-token-exists (err u101))
(define-constant err-token-not-found (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-invalid-token-name (err u104))
(define-constant err-invalid-category (err u105))
(define-constant err-invalid-max-supply (err u106))
(define-constant err-invalid-token-price (err u107))
(define-constant err-invalid-recipient (err u108))
(define-constant err-invalid-transfer-amount (err u109))
(define-constant err-insufficient-allowance (err u110))
(define-constant err-invalid-authorized-addr (err u111))
(define-constant err-invalid-price-update (err u112))


;; Counter for token IDs
(define-data-var token-counter uint u0)
(define-data-var contract-admin principal tx-sender)

;;;;;;; MAP ;;;;;;;
;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;
;; Define the token structure
(define-map tokens
  { token-id: uint }
  {
    token-name: (string-ascii 64),
    token-category: (string-ascii 32),
    max-supply: uint,
    token-price: uint,
    last-price-update: uint  ;; Added timestamp for price updates
  }
)


;; Define balances structure
(define-map balances
  { holder: principal, token-id: uint }
  { amount: uint }
)


;; Define allowance structure
(define-map allowances
  { holder: principal, authorized: principal, token-id: uint }
  { allowed-amount: uint }
)


;; Define price history structure
(define-map price-history
  { token-id: uint, timestamp: uint }
  { price: uint }
)

;; Function to validate token-id
(define-read-only (is-valid-token (token-id uint))
  (is-some (map-get? tokens { token-id: token-id }))
)

;; Get token information
(define-read-only (get-token-info (token-id uint))
  (map-get? tokens { token-id: token-id })
)

;; Get balance of a holder for a specific token
(define-read-only (get-balance (holder principal) (token-id uint))
  (default-to u0 (get amount (map-get? balances { holder: holder, token-id: token-id })))
)

;; Get allowance amount
(define-read-only (get-allowance (holder principal) (spender principal) (token-id uint))
  (default-to u0 (get allowed-amount (map-get? allowances { holder: holder, authorized: spender, token-id: token-id })))
)

;; Get price at a specific timestamp
(define-read-only (get-price-at-time (token-id uint) (timestamp uint))
  (map-get? price-history { token-id: token-id, timestamp: timestamp })
)

;; Get current token counter value
(define-read-only (get-token-counter)
  (var-get token-counter)
)

;; Get contract admin
(define-read-only (get-contract-admin)
  (var-get contract-admin)
)

;; public functions
;;

;; Function to create a new token
(define-public (mint-token (token-name (string-ascii 64)) (token-category (string-ascii 32)) (max-supply uint) (token-price uint))
  (let
    (
      (token-id (+ (var-get token-counter) u1))
      (current-time stacks-block-time)
    )
    (asserts! (is-eq tx-sender (var-get contract-admin)) err-not-authorized)
    (asserts! (is-none (map-get? tokens { token-id: token-id })) err-token-exists)
    ;; Input validation
    (asserts! (> (len token-name) u0) err-invalid-token-name)
    (asserts! (> (len token-category) u0) err-invalid-category)
    (asserts! (> max-supply u0) err-invalid-max-supply)
    (asserts! (> token-price u0) err-invalid-token-price)
    (map-set tokens
      { token-id: token-id }
      { 
        token-name: token-name, 
        token-category: token-category, 
        max-supply: max-supply, 
        token-price: token-price,
        last-price-update: current-time
      }
    )
    ;; Record initial price in history
    (map-set price-history
      { token-id: token-id, timestamp: current-time }
      { price: token-price }
    )
    (map-set balances
      { holder: (var-get contract-admin), token-id: token-id }
      { amount: max-supply }
    )
    (var-set token-counter token-id)
    (ok token-id)
  )
)

;; Function to transfer tokens
(define-public (transfer (token-id uint) (amount uint) (sender principal) (recipient principal))
  (let
    (
      (sender-balance (default-to u0 (get amount (map-get? balances { holder: sender, token-id: token-id }))))
      (recipient-balance (default-to u0 (get amount (map-get? balances { holder: recipient, token-id: token-id }))))
    )
    ;; Validate inputs
    (asserts! (is-valid-token token-id) err-token-not-found)
    (asserts! (> amount u0) err-invalid-transfer-amount)
    (asserts! (is-eq tx-sender sender) err-not-authorized)
    (asserts! (is-standard recipient) err-invalid-recipient)
    (asserts! (>= sender-balance amount) err-insufficient-funds)

    ;; Update sender balance
    (map-set balances
      { holder: sender, token-id: token-id }
      { amount: (- sender-balance amount) }
    )

    ;; Update recipient balance
    (map-set balances
      { holder: recipient, token-id: token-id }
      { amount: (+ recipient-balance amount) }
    )

    (ok true)
  )
)

;; Function to approve an address to spend tokens on behalf of holder
(define-public (approve (token-id uint) (spender principal) (amount uint))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-token token-id) err-token-not-found)
    (asserts! (is-standard spender) err-invalid-authorized-addr)
    (asserts! (> amount u0) err-invalid-transfer-amount)

    ;; Set allowance
    (map-set allowances
      { holder: tx-sender, authorized: spender, token-id: token-id }
      { allowed-amount: amount }
    )

    (ok true)
  )
)

;; Function to transfer tokens from an approved address
(define-public (transfer-from (token-id uint) (amount uint) (owner principal) (recipient principal))
  (let
    (
      (current-allowance (default-to u0 (get allowed-amount (map-get? allowances { holder: owner, authorized: tx-sender, token-id: token-id }))))
      (owner-balance (default-to u0 (get amount (map-get? balances { holder: owner, token-id: token-id }))))
      (recipient-balance (default-to u0 (get amount (map-get? balances { holder: recipient, token-id: token-id }))))
    )
    ;; Validate inputs
    (asserts! (is-valid-token token-id) err-token-not-found)
    (asserts! (> amount u0) err-invalid-transfer-amount)
    (asserts! (is-standard recipient) err-invalid-recipient)
    (asserts! (>= current-allowance amount) err-insufficient-allowance)
    (asserts! (>= owner-balance amount) err-insufficient-funds)

    ;; Update allowance
    (map-set allowances
      { holder: owner, authorized: tx-sender, token-id: token-id }
      { allowed-amount: (- current-allowance amount) }
    )

    ;; Update owner balance
    (map-set balances
      { holder: owner, token-id: token-id }
      { amount: (- owner-balance amount) }
    )

    ;; Update recipient balance
    (map-set balances
      { holder: recipient, token-id: token-id }
      { amount: (+ recipient-balance amount) }
    )

    (ok true)
  )
)

;; Function to update token price (admin only)
(define-public (update-price (token-id uint) (new-price uint))
  (let
    (
      (token-data (unwrap! (map-get? tokens { token-id: token-id }) err-token-not-found))
      (current-time stacks-block-time)
    )
    ;; Validate inputs
    (asserts! (is-eq tx-sender (var-get contract-admin)) err-not-authorized)
    (asserts! (> new-price u0) err-invalid-price-update)

    ;; Update token price and timestamp
    (map-set tokens
      { token-id: token-id }
      (merge token-data { token-price: new-price, last-price-update: current-time })
    )

    ;; Record price in history
    (map-set price-history
      { token-id: token-id, timestamp: current-time }
      { price: new-price }
    )

    (ok true)
  )
)

;; Function to burn tokens (reduce supply)
(define-public (burn (token-id uint) (amount uint))
  (let
    (
      (holder-balance (default-to u0 (get amount (map-get? balances { holder: tx-sender, token-id: token-id }))))
    )
    ;; Validate inputs
    (asserts! (is-valid-token token-id) err-token-not-found)
    (asserts! (> amount u0) err-invalid-transfer-amount)
    (asserts! (>= holder-balance amount) err-insufficient-funds)

    ;; Reduce holder balance
    (map-set balances
      { holder: tx-sender, token-id: token-id }
      { amount: (- holder-balance amount) }
    )

    (ok true)
  )
)

;; Function to change contract admin (current admin only)
(define-public (set-contract-admin (new-admin principal))
  (begin
    ;; Validate that caller is current admin
    (asserts! (is-eq tx-sender (var-get contract-admin)) err-not-authorized)
    (asserts! (is-standard new-admin) err-invalid-authorized-addr)

    ;; Update contract admin
    (var-set contract-admin new-admin)

    (ok true)
  )
)
```
