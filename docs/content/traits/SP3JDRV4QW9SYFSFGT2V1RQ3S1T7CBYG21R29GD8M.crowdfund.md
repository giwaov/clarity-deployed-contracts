---
title: "Trait crowdfund"
draft: true
---
```
;; Simple Crowdfund Contract

(define-constant owner tx-sender)
(define-constant goal u5000000000) ;; 5000 STX goal

(define-data-var total-raised uint u0)
(define-map contributions principal uint)

;; Contribute to campaign
(define-public (contribute (amount uint))
  (let ((current (default-to u0 (map-get? contributions tx-sender))))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set contributions tx-sender (+ current amount))
    (var-set total-raised (+ (var-get total-raised) amount))
    (ok true)
  )
)

;; Claim funds if goal met
(define-public (claim)
  (begin
    (asserts! (is-eq tx-sender owner) (err u1))
    (asserts! (>= (var-get total-raised) goal) (err u2))
    (as-contract (stx-transfer? (var-get total-raised) tx-sender owner))
  )
)

;; Get refund if goal not met
(define-public (refund)
  (let ((amount (default-to u0 (map-get? contributions tx-sender))))
    (asserts! (< (var-get total-raised) goal) (err u3))
    (asserts! (> amount u0) (err u4))
    (map-delete contributions tx-sender)
    (as-contract (stx-transfer? amount tx-sender tx-sender))
  )
)

;; Read functions
(define-read-only (get-total) (var-get total-raised))
(define-read-only (get-contribution (user principal)) 
  (default-to u0 (map-get? contributions user)))
```
