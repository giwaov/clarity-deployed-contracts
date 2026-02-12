---
title: "Trait STX-Data"
draft: true
---
```



;; title: asset

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
;; public functions

;; Function to create a new token
(define-public (mint-token (token-name (string-ascii 64)) (token-category (string-ascii 32)) (max-supply uint) (token-price uint))
  (let
    (
      (token-id (+ (var-get token-counter) u1))
      (current-time (unwrap-panic (get-stacks-block-info? time u0)))
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


;; Updated function to update token price with additional checks
(define-public (update-token-price (token-id uint) (new-price uint))
  (let
    (
      (current-time (unwrap-panic (get-stacks-block-info? time u0)))
      (token-info (unwrap! (map-get? tokens { token-id: token-id }) err-token-not-found))
    )
    ;; Only contract admin can update prices
    (asserts! (is-eq tx-sender (var-get contract-admin)) err-not-authorized)
    ;; Validate new price
    (asserts! (> new-price u0) err-invalid-price-update)
    ;; Validate token-id
    (asserts! (is-valid-token token-id) err-token-not-found)
    ;; Update token price
    (map-set tokens
      { token-id: token-id }
      (merge token-info { 
        token-price: new-price,
        last-price-update: current-time
      })
    )
    ;; Record price update in history
    (map-set price-history
      { token-id: token-id, timestamp: current-time }
      { price: new-price }
    )
    (ok true)
  )
)



;; Function to authorize spending
(define-public (authorize-spending (authorized principal) (token-id uint) (allowed-amount uint))
  (let
    (
      (holder tx-sender)
    )
    (asserts! (is-valid-token token-id) err-token-not-found)
    (asserts! (not (is-eq authorized holder)) err-invalid-authorized-addr)
    (asserts! (>= allowed-amount u0) err-invalid-transfer-amount)
    (map-set allowances
      { holder: holder, authorized: authorized, token-id: token-id }
      { allowed-amount: allowed-amount }
    )
    (ok true)
  )
)



;; Function to transfer tokens
(define-public (transfer (recipient principal) (token-id uint) (transfer-amount uint))
  (let
    (
      (sender tx-sender)
    )
    (asserts! (is-valid-token token-id) err-token-not-found)
    (asserts! (not (is-eq recipient sender)) err-invalid-recipient)
    (asserts! (> transfer-amount u0) err-invalid-transfer-amount)
    (process-transfer sender recipient token-id transfer-amount)
  )
)

;; Function to transfer tokens as authorized spender
(define-public (transfer-as-authorized (from principal) (recipient principal) (token-id uint) (transfer-amount uint))
  (let
    (
      (spender tx-sender)
      (authorized-amount (get allowed-amount (get-authorized-amount from spender token-id)))
    )
    (asserts! (is-valid-token token-id) err-token-not-found)
    (asserts! (not (is-eq recipient from)) err-invalid-recipient)
    (asserts! (>= authorized-amount transfer-amount) err-insufficient-allowance)
    (asserts! (> transfer-amount u0) err-invalid-transfer-amount)
    (map-set allowances
      { holder: from, authorized: spender, token-id: token-id }
      { allowed-amount: (- authorized-amount transfer-amount) }
    )
    (process-transfer from recipient token-id transfer-amount)
  )
)

;; Helper function to process token transfer
(define-private (process-transfer (from principal) (recipient principal) (token-id uint) (transfer-amount uint))
  (let
    (
      (sender-balance (get amount (default-to { amount: u0 } (map-get? balances { holder: from, token-id: token-id }))))
      (recipient-balance (get amount (default-to { amount: u0 } (map-get? balances { holder: recipient, token-id: token-id }))))
    )
    (asserts! (>= sender-balance transfer-amount) err-insufficient-funds)
    (map-set balances
      { holder: from, token-id: token-id }
      { amount: (- sender-balance transfer-amount) }
    )
    (map-set balances
      { holder: recipient, token-id: token-id }
      { amount: (+ recipient-balance transfer-amount) }
    )
    (ok true)
  )
)



;; Function to change contract admin
(define-public (set-contract-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) err-not-authorized)
    (asserts! (not (is-eq new-admin (var-get contract-admin))) err-not-authorized)
    (ok (var-set contract-admin new-admin))
  )
)

;;;;;; READ ONLY FUNCTION ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Function to get token details
(define-read-only (get-token-details (token-id uint))
  (map-get? tokens { token-id: token-id })
)

;; Function to get holder balance for a token
(define-read-only (get-holder-balance (holder principal) (token-id uint))
  (default-to { amount: u0 } (map-get? balances { holder: holder, token-id: token-id }))
)


;; Function to get authorized amount
(define-read-only (get-authorized-amount (holder principal) (authorized principal) (token-id uint))
  (default-to { allowed-amount: u0 }
    (map-get? allowances { holder: holder, authorized: authorized, token-id: token-id })
  )
)

;; New function to get price history
(define-read-only (get-price-at-time (token-id uint) (timestamp uint))
  (map-get? price-history { token-id: token-id, timestamp: timestamp })
)




```
