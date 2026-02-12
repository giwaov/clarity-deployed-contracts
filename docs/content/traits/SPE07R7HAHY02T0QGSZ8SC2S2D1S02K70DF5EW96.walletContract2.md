---
title: "Trait walletContract2"
draft: true
---
```
;; ---------------------------------------------------------
;; Simple Wallet Contract
;; Clarity Version: 4
;; ---------------------------------------------------------

;; -------------------------
;; ERROR CODES
;; -------------------------
(define-constant ERR_INSUFFICIENT_BALANCE    (err u100))
(define-constant ERR_AMOUNT_MUST_BE_POSITIVE (err u101))

;; -------------------------
;; DATA STORAGE
;; -------------------------
;; Maps user -> deposited STX balance (in microstacks)
(define-map balances principal uint)

;; -------------------------
;; PRIVATE HELPERS
;; -------------------------
(define-private (is-valid-amount (amount uint))
  (> amount u0)
)

(define-private (get-balance (user principal))
  (default-to u0 (map-get? balances user))
)

(define-private (set-balance (user principal) (amount uint))
  (if (is-eq amount u0)
      (map-delete balances user)
      (map-set balances user amount))
)

;; -------------------------
;; PUBLIC FUNCTIONS
;; -------------------------

;; Deposit STX (STX must be sent with the transaction)
(define-public (deposit (amount uint))
  (let ((current-balance (get-balance tx-sender)))
    (asserts! (is-valid-amount amount) ERR_AMOUNT_MUST_BE_POSITIVE)

    ;; Ensure the user actuacontractlly sent the STX
    (asserts!
      (>= (stx-get-balance tx-sender) amount)
      ERR_AMOUNT_MUST_BE_POSITIVE
    )

    ;; Update internal balance only
    (set-balance tx-sender (+ current-balance amount))

    (ok true)
  )
)

;; Withdraw STX
(define-public (withdraw (amount uint))
  (let ((current-balance (get-balance tx-sender)))
    (asserts! (is-valid-amount amount) ERR_AMOUNT_MUST_BE_POSITIVE)
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)

    ;; Update balance first
    (set-balance tx-sender (- current-balance amount))

    ;; Transfer STX from contract to user
    (try! (stx-transfer? amount tx-sender tx-sender))

    (ok true)
  )
)


;; -------------------------
;; READ-ONLY FUNCTIONS
;; -------------------------

;; Get wallet balance of a user
(define-read-only (get-balance-of (user principal))
  (get-balance user)
)

```
