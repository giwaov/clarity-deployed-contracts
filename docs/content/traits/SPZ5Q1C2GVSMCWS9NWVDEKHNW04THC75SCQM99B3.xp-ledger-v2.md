---
title: "Trait xp-ledger-v2"
draft: true
---
```
;; title: xp-ledger
;; summary: Tracks XP balances and allows an authorized contract to award XP
;; version: 1

;; constants
(define-constant err-not-owner (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-zero-amount (err u102))

;; data vars
(define-data-var contract-admin principal tx-sender)
(define-data-var xp-authority principal tx-sender)
(define-data-var total-xp uint u0)

;; data maps
;; { owner } -> { xp }
(define-map balances { owner: principal } { xp: uint })

;; private helpers
(define-private (is-owner (who principal))
  (is-eq who (var-get contract-admin)))

(define-private (is-authorized (who principal))
  (or (is-owner who)
      (is-eq who (var-get xp-authority))
      (is-eq contract-caller (var-get xp-authority))))

(define-private (assert-positive (amount uint))
  (> amount u0))

;; public functions

;; admin: update contract admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-owner tx-sender) err-not-owner)
    (var-set contract-admin new-admin)
    (print { event: "set-admin", admin: new-admin })
    (ok true)))

;; admin: designate the principal (often a contract) allowed to award XP
(define-public (set-authority (authority principal))
  (begin
    (asserts! (is-owner tx-sender) err-not-owner)
    (var-set xp-authority authority)
    (print { event: "set-authority", authority: authority })
    (ok true)))

;; authorized caller: award XP to a principal
(define-public (award-xp (recipient principal) (amount uint))
  (begin
    (asserts! (assert-positive amount) err-zero-amount)
    (asserts! (is-authorized tx-sender) err-not-authorized)
    (let (
          (current (default-to u0 (get xp (map-get? balances { owner: recipient }))))
          (new-balance (+ current amount)))
      (map-set balances { owner: recipient } { xp: new-balance })
      (var-set total-xp (+ (var-get total-xp) amount))
      (print { event: "award-xp", to: recipient, amount: amount, new-balance: new-balance })
      (ok new-balance))))

;; read only functions

;; read: current authority allowed to award XP
(define-read-only (get-authority)
  (ok (var-get xp-authority)))

;; read: admin
(define-read-only (get-admin)
  (ok (var-get contract-admin)))

;; read: total XP awarded
(define-read-only (get-total-xp)
  (ok (var-get total-xp)))

;; read: XP balance for a principal
(define-read-only (get-balance (owner principal))
  (ok (default-to u0 (get xp (map-get? balances { owner: owner })) )))

```
