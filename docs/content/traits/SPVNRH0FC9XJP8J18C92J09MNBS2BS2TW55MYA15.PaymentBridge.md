---
title: "Trait PaymentBridge"
draft: true
---
```

;; A simple escrow system for secure peer-to-peer transactions
;; TrustBridge: P2P Trust and Payment Protocol

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NO-AUTH (err u1))
(define-constant ERR-LOW-VALUE (err u2))
(define-constant ERR-INVALID-USER (err u3))
(define-constant ERR-NO-PAYMENT (err u4))
(define-constant ADMIN tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ZERO-AMOUNT (err u101))
(define-constant ERR-SELF-DEAL (err u102))
(define-constant ERR-DEAL-NOT-EXIST (err u103))
(define-constant ERR-BAD-RATING (err u104))
(define-constant ERR-INVALID-DEAL-ID (err u105))

;; Basic payment storage
(define-map payments 
  { id: uint }
  {
    from: principal,
    to: principal,
    amount: uint,
    is-complete: bool,
    created-at: uint
  }
)
;; Check if deal parties are different
(define-private (validate-counterparty (counterparty principal))
  (and 
    (not (is-eq counterparty tx-sender))
    (not (is-eq counterparty ADMIN))
  )
)

;; Payment counter
(define-data-var payment-id-counter uint u1)
;; (define-data-var user principal 'SP3X1Q4Z2F5J7Y6G9K8H9F5J4D5J4D5J4D5J4D5J4D5J4D)
(define-private (validate-deal-id (deal-id uint))
  (and 
    (> deal-id u0)
    (< deal-id (var-get deal-counter))
  )
)

;; ;; Create new payment
;; (define-public (create-payment 
;;   (recipient principal) 
;;   (amount uint)))
;; Deal storage
(define-map deals 
  { deal-id: uint }
  {
    initiator: principal,
    counterparty: principal,
    value: uint,
    state: (string-ascii 20),
    timestamp: uint,
    trust-score: uint
  }
)

;; Trust profiles
(define-map trust-profiles 
  { address: principal }
  { cumulative-score: uint, deal-count: uint }
)

;; Deal counter
(define-data-var deal-counter uint u1)


;; Check if user is valid
(define-private (is-valid-user (recipient principal))
  (and 
    (not (is-eq recipient tx-sender))
    (not (is-eq recipient ADMIN))
  )
)

;; Initiate new deal
(define-public (initiate-deal 
  (counterparty principal) 
  (value uint)
)
  (begin
    (asserts! (is-valid-user counterparty) ERR-INVALID-USER)
    (asserts! (> value u0) ERR-LOW-VALUE)
    ;; Validate counterparty
    (asserts! (validate-counterparty counterparty) ERR-SELF-DEAL)

    ;; Validate value
    (asserts! (> value u0) ERR-ZERO-AMOUNT)

    (let 
      (
        (id (var-get payment-id-counter))
        (current-deal-id (var-get deal-counter))
      )
      (var-set payment-id-counter (+ id u1))
      ;; Update deal counter
      (var-set deal-counter (+ current-deal-id u1))

      (map-set payments 
        { id: id }
        {
          from: tx-sender,
          to: counterparty,
          amount: value,
          is-complete: false,
          created-at: stacks-block-height
        }
      )
      
      ;; Record deal
      (map-set deals 
        { deal-id: current-deal-id }
        {
          initiator: tx-sender,
          counterparty: counterparty,
          value: value,
          state: "OPEN",
          timestamp: stacks-block-height,
          trust-score: u0
        }
      )

      (ok current-deal-id)
    )
  )
)

;; Complete payment
(define-public (complete-payment (payment-id uint))
  (let 
    (
      (payment (unwrap! (map-get? payments { id: payment-id }) ERR-NO-PAYMENT))
    )
    (asserts! (is-eq tx-sender (get from payment)) ERR-NO-AUTH)

    ;; Process the payment
    (try! (stx-transfer? 
      (get amount payment) 
      tx-sender 
      (get to payment)
    ))
    
    ;; Update payment status
    (map-set payments 
      { id: payment-id }
      (merge payment { is-complete: true })
    )
    
    ;; Return success
    (ok true)
  )
)

;; Add trust rating
(define-public (rate-counterparty 
  (deal-id uint) 
  (rating uint)
)
  (begin
    ;; Validate deal
    (asserts! (validate-deal-id deal-id) ERR-INVALID-DEAL-ID)

    (let 
      (
        (deal (unwrap! 
          (map-get? deals { deal-id: deal-id }) 
          ERR-DEAL-NOT-EXIST
        ))
        (initiator (get initiator deal))
        (counterparty (get counterparty deal))
      )
      ;; Verify rater
      (asserts! 
        (is-eq tx-sender counterparty) 
        ERR-NOT-AUTHORIZED
      )
      (asserts! (> rating u0) ERR-BAD-RATING)

      ;; Update trust profile
      (map-set trust-profiles 
        { address: initiator }
        {
          cumulative-score: (+ 
            (get cumulative-score 
              (default-to 
                { cumulative-score: u0, deal-count: u0 } 
                (map-get? trust-profiles { address: initiator })
              )
            )
            rating
          ),
          deal-count: (+ 
            (get deal-count 
              (default-to 
                { cumulative-score: u0, deal-count: u0 } 
                (map-get? trust-profiles { address: initiator })
              )
            )
            u1
          )
        }
      )

      ;; Update deal rating
      (map-set deals 
        { deal-id: deal-id }
        (merge deal { trust-score: rating })
      )

      (ok true)
    )
  )
)

;; Query trust profile
(define-read-only (get-trust-profile (address principal))
  (default-to 
    { cumulative-score: u0, deal-count: u0 }
    (map-get? trust-profiles { address: address })
  )
)

;; Get payment details
(define-read-only (get-payment-info (payment-id uint))
  (map-get? payments { id: payment-id }))
;; Query deal information
(define-read-only (get-deal-info (deal-id uint))
  (map-get? deals { deal-id: deal-id })
)


```
