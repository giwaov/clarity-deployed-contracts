---
title: "Trait Stacks-vesting"
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
```
