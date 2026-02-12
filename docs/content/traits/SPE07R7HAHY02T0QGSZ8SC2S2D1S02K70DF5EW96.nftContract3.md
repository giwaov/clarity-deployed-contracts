---
title: "Trait nftContract3"
draft: true
---
```
;; ---------------------------------------------------------
;; Simple Fungible Token
;; Clarity Version: 4
;; ---------------------------------------------------------

;; -------------------------
;; ERROR CODES
;; -------------------------
(define-constant ERR_UNAUTHORIZED            (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE    (err u101))
(define-constant ERR_AMOUNT_MUST_BE_POSITIVE (err u102))
(define-constant ERR_SELF_TRANSFER           (err u103))
(define-constant ERR_ALREADY_INITIALIZED     (err u104))
(define-constant ERR_INSUFFICIENT_ALLOWANCE  (err u105))

;; -------------------------
;; TOKEN CONFIGURATION
;; -------------------------
(define-constant TOKEN-NAME    "SimpleNFT")
(define-constant TOKEN-SYMBOL  "SNFT")
(define-constant DECIMALS      u6)
(define-constant INITIAL-SUPPLY u1000000000000) ;; 1,000,000 * 10^6

;; -------------------------
;; DATA STORAGE
;; -------------------------
(define-data-var name (string-ascii 32) TOKEN-NAME)
(define-data-var symbol (string-ascii 8) TOKEN-SYMBOL)
(define-data-var decimals uint DECIMALS)
(define-data-var total-supply uint u0)
(define-data-var initialized bool false)
(define-data-var contract-owner principal tx-sender)

;; -------------------------
;; FUNGIBLE TOKEN DEFINITION
;; -------------------------
(define-fungible-token simple-token)

;; Balances
(define-map balances principal uint)

;; Allowances
(define-map allowances
  { owner: principal, spender: principal }
  uint
)

;; -------------------------
;; PRIVATE HELPERS
;; -------------------------
(define-private (is-valid-amount (amount uint))
  (> amount u0)
)

(define-private (get-balance (who principal))
  (default-to u0 (map-get? balances who))
)

(define-private (set-balance (who principal) (amount uint))
  (if (is-eq amount u0)
      (map-delete balances who)
      (map-set balances who amount))
)

(define-private (transfer-internal
  (from principal)
  (to principal)
  (amount uint))
  (let (
        (from-balance (get-balance from))
        (to-balance   (get-balance to))
       )
    (asserts! (is-valid-amount amount) ERR_AMOUNT_MUST_BE_POSITIVE)
    (asserts! (not (is-eq from to)) ERR_SELF_TRANSFER)
    (asserts! (>= from-balance amount) ERR_INSUFFICIENT_BALANCE)

    (set-balance from (- from-balance amount))
    (set-balance to   (+ to-balance amount))
    (ok true)
  )
)

;; -------------------------
;; PUBLIC FUNCTIONS
;; -------------------------

;; One-time initialization
(define-public (initialize)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (not (var-get initialized)) ERR_ALREADY_INITIALIZED)

    (var-set initialized true)
    (var-set total-supply INITIAL-SUPPLY)
    (map-set balances tx-sender INITIAL-SUPPLY)
    (ok true)
  )
)

;; Transfer tokens
(define-public (transfer (to principal) (amount uint))
  (begin
    (asserts! (is-valid-amount amount) ERR_AMOUNT_MUST_BE_POSITIVE)
    (asserts! (is-eq tx-sender to) ERR_UNAUTHORIZED)

    (try! (ft-transfer? simple-token amount tx-sender to))
    (ok true)
  )
)
;; (define-public (transfer (to principal) (amount uint))
;;   (begin
;;     (asserts! (is-valid-amount amount) ERR_AMOUNT_MUST_BE_POSITIVE)
;;     (ft-transfer? simple-token amount tx-sender to)
;;   )
;; )

;; Approve allowance
(define-public (approve (spender principal) (amount uint))
  (begin
    (asserts! (is-valid-amount amount) ERR_AMOUNT_MUST_BE_POSITIVE)
    (map-set allowances { owner: tx-sender, spender: spender } amount)
    (ok true)
  )
)

;; Transfer from allowance
(define-public (transfer-from (from principal) (to principal) (amount uint))
  (let (
        (spender tx-sender)
        (allowance (default-to u0
          (map-get? allowances { owner: from, spender: spender })))
       )
    (asserts! (is-valid-amount amount) ERR_AMOUNT_MUST_BE_POSITIVE)
    (asserts! (>= allowance amount) ERR_INSUFFICIENT_ALLOWANCE)

    (map-set allowances
      { owner: from, spender: spender }
      (- allowance amount))

    (transfer-internal from to amount)
  )
)

;; Mint (owner only)
(define-public (mint (to principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-valid-amount amount) ERR_AMOUNT_MUST_BE_POSITIVE)

    (var-set total-supply (+ (var-get total-supply) amount))
    (set-balance to (+ (get-balance to) amount))
    (ok true)
  )
)

;; Burn own tokens
(define-public (burn (amount uint))
  (let (
        (balance (get-balance tx-sender))
       )
    (asserts! (is-valid-amount amount) ERR_AMOUNT_MUST_BE_POSITIVE)
    (asserts! (>= balance amount) ERR_INSUFFICIENT_BALANCE)

    (set-balance tx-sender (- balance amount))
    (var-set total-supply (- (var-get total-supply) amount))
    (ok true)
  )
)

;; -------------------------
;; READ-ONLY FUNCTIONS
;; -------------------------

(define-read-only (get-name)
  (var-get name)
)

(define-read-only (get-symbol)
  (var-get symbol)
)

(define-read-only (get-decimals)
  (var-get decimals)
)

(define-read-only (get-total-supply)
  (var-get total-supply)
)

(define-read-only (get-balance-of (who principal))
  (get-balance who)
)

(define-read-only (get-allowance (owner principal) (spender principal))
  (default-to u0 (map-get? allowances { owner: owner, spender: spender }))
)

```
