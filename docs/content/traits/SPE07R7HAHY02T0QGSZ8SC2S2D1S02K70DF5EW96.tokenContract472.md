---
title: "Trait tokenContract472"
draft: true
---
```
;; ---------------------------------------------------------
;; SimpleToken (SIP-010)
;; Version: 1.0.0
;; Clarity Version: 4
;; ---------------------------------------------------------

;; -------------------------
;; ERROR CODES (SIP-010 style)
;; -------------------------
(define-constant ERR_UNAUTHORIZED            (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE    (err u101))
(define-constant ERR_AMOUNT_MUST_BE_POSITIVE (err u102))
(define-constant ERR_ALREADY_INITIALIZED     (err u103))

;; -------------------------
;; TOKEN METADATA
;; -------------------------
(define-constant TOKEN-NAME   "SimpleToken")
(define-constant TOKEN-SYMBOL "STK")
(define-constant TOKEN-URI    none)
(define-constant DECIMALS     u6)

(define-constant INITIAL-SUPPLY u1000000000000) ;; 1,000,000 * 10^6

;; -------------------------
;; FUNGIBLE TOKEN
;; -------------------------
(define-fungible-token simple-token)

;; -------------------------
;; DATA STORAGE
;; -------------------------
(define-data-var initialized bool false)
(define-data-var contract-owner principal tx-sender)

;; -------------------------
;; PRIVATE HELPERS
;; -------------------------
(define-private (is-valid-amount (amount uint))
  (> amount u0)
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
    (try! (ft-mint? simple-token INITIAL-SUPPLY tx-sender))
    (ok true)
  )
)

;; SIP-010 transfer
(define-public (transfer
  (amount uint)
  (sender principal)
  (recipient principal)
  (memo (optional (buff 34))))
  (begin
    (asserts! (is-valid-amount amount) ERR_AMOUNT_MUST_BE_POSITIVE)
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)

    (match (ft-transfer? simple-token amount sender recipient)
      success (ok success)
      error   (err error)
    )
  )
)


;; Mint new tokens (owner only)
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-valid-amount amount) ERR_AMOUNT_MUST_BE_POSITIVE)

    (try! (ft-mint? simple-token amount recipient))
    (ok true)
  )
)

;; Burn own tokens
(define-public (burn (amount uint))
  (begin
    (asserts! (is-valid-amount amount) ERR_AMOUNT_MUST_BE_POSITIVE)

    (try! (ft-burn? simple-token amount tx-sender))
    (ok true)
  )
)

;; -------------------------
;; SIP-010 READ-ONLY FUNCTIONS
;; -------------------------

(define-read-only (get-name)
  TOKEN-NAME
)

(define-read-only (get-symbol)
  TOKEN-SYMBOL
)

(define-read-only (get-decimals)
  DECIMALS
)

(define-read-only (get-total-supply)
  (ft-get-supply simple-token)
)

(define-read-only (get-balance (who principal))
  (ft-get-balance simple-token who)
)

(define-read-only (get-token-uri)
  TOKEN-URI
)

```
