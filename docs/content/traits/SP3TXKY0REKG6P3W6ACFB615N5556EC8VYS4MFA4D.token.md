---
title: "Trait token"
draft: true
---
```
;; token.clar
;; Enhanced SIP-010 token with vesting and fees

(define-fungible-token enhanced-token)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-OWNER (err u100))
(define-constant ERR-NOT-MINTER (err u101))
(define-constant ERR-TRANSFERS-DISABLED (err u102))

(define-constant TRANSFERS-ENABLED true)
(define-constant TRANSFER-FEE u0) ;; Basis points

;; Maps
(define-map minters principal bool)
(define-map vesting-schedules principal 
  {
    total: uint,
    released: uint,
    start: uint,
    duration: uint
  }
)

;; Public Functions
(define-public (set-minter (minter principal) (allowed bool))
  (begin
    (asserts! (not (is-eq minter tx-sender)) (err u406))
    (ok (map-set minters minter allowed))
  )
)

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! TRANSFERS-ENABLED ERR-TRANSFERS-DISABLED)
    (asserts! (is-eq from tx-sender) (err u401))
    (asserts! (not (is-eq to tx-sender)) (err u407))
    (asserts! (> amount u0) (err u402))
    
    (match memo
      memo-val (begin (print memo-val) true)
      true
    )
    
    (let ((fee (/ (* amount TRANSFER-FEE) u10000)))
      (begin
        (if (> fee u0)
          (begin
            (unwrap! (ft-transfer? enhanced-token fee from CONTRACT-OWNER) (err u500))
            (ft-transfer? enhanced-token (- amount fee) from to))
          (ft-transfer? enhanced-token amount from to)
        )
      )
    )
  )
)

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (> amount u0) (err u403))
    (asserts! (not (is-eq recipient tx-sender)) (err u408))
    (ft-mint? enhanced-token amount recipient)
  )
)

(define-public (create-vesting (beneficiary principal) (amount uint) (duration-days uint))
  (begin
    (asserts! (not (is-eq beneficiary tx-sender)) (err u409))
    (asserts! (> amount u0) (err u404))
    (asserts! (> duration-days u0) (err u405))
    (ok (map-set vesting-schedules beneficiary {
      total: amount,
      released: u0,
      start: stacks-block-time,
      duration: (* duration-days u86400)
    }))
  )
)

;; Read-only
(define-read-only (get-vesting (user principal))
  (map-get? vesting-schedules user)
)

;; Read-only
(define-read-only (get-name) (ok "Enhanced Token"))
(define-read-only (get-symbol) (ok "ETOKEN"))
(define-read-only (get-decimals) (ok u18))
(define-read-only (get-balance (user principal)) (ok (ft-get-balance enhanced-token user)))

```
