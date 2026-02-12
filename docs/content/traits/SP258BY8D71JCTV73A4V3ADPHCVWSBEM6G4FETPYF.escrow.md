---
title: "Trait escrow"
draft: true
---
```
;; escrow.clar
;; Escrow system with milestones and disputes

;; Constants
(define-constant CONTRACT-ADDRESS .escrow)
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-ARBITRATOR (err u101))
(define-constant ERR-ESCROW-NOT-FOUND (err u102))
(define-constant ERR-NOT-BUYER (err u103))
(define-constant ERR-NOT-PARTY (err u105))
(define-constant ERR-INVALID-AMOUNT (err u106))
(define-constant ERR-ESCROW-NOT-ACTIVE (err u107))
(define-constant ERR-ALREADY-DISPUTED (err u108))
(define-constant ERR-SAME-PARTY (err u109))

;; Status
(define-constant STATUS-ACTIVE u0)
(define-constant STATUS-COMPLETED u1)
(define-constant STATUS-DISPUTED u2)
(define-constant STATUS-REFUNDED u3)

;; Data Variables
(define-data-var escrow-counter uint u0)

;; Maps
(define-map escrows uint 
  {
    buyer: principal,
    seller: principal,
    amount: uint,
    status: uint,
    deadline: uint
  }
)

(define-map arbitrators principal bool)

;; Public Functions
(define-public (add-arbitrator (arbitrator principal))
  (begin
    (asserts! (not (is-eq arbitrator tx-sender)) (err u111))
    (ok (map-set arbitrators arbitrator true))
  )
)

(define-public (create-escrow (seller principal) (amount uint) (duration-days uint))
  (let (
    (escrow-id (+ (var-get escrow-counter) u1))
    (deadline (+ stacks-block-time (* duration-days u86400)))
  )
    (begin
      (asserts! (> amount u0) ERR-INVALID-AMOUNT)
      (asserts! (not (is-eq seller tx-sender)) ERR-SAME-PARTY)
      (asserts! (> duration-days u0) (err u112))
      (unwrap-panic (stx-transfer? amount tx-sender CONTRACT-ADDRESS))
      
      (map-set escrows escrow-id {
        buyer: tx-sender,
        seller: seller,
        amount: amount,
        status: STATUS-ACTIVE,
        deadline: deadline
      })
      
      (var-set escrow-counter escrow-id)
      (ok escrow-id)
    )
  )
)

(define-public (complete-escrow (escrow-id uint))
  (let ((escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND)))
    (begin
      (asserts! (is-eq (get buyer escrow) tx-sender) ERR-NOT-BUYER)
      (asserts! (is-eq (get status escrow) STATUS-ACTIVE) ERR-ESCROW-NOT-ACTIVE)
      
      (map-set escrows escrow-id (merge escrow { status: STATUS-COMPLETED }))
      (try! (stx-transfer? (get amount escrow) CONTRACT-ADDRESS (get seller escrow)))
      (ok true)
    )
  )
)

(define-public (raise-dispute (escrow-id uint))
  (let ((escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND)))
    (begin
      (asserts! (or (is-eq (get buyer escrow) tx-sender) (is-eq (get seller escrow) tx-sender)) ERR-NOT-PARTY)
      (asserts! (is-eq (get status escrow) STATUS-ACTIVE) ERR-ESCROW-NOT-ACTIVE)
      
      (map-set escrows escrow-id (merge escrow { status: STATUS-DISPUTED }))
      (ok true)
    )
  )
)

(define-public (resolve-dispute (escrow-id uint) (buyer-wins bool))
  (let ((escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND)))
    (begin
      (asserts! (is-eq (get status escrow) STATUS-DISPUTED) ERR-ALREADY-DISPUTED)
      
      (if buyer-wins
        (begin
          (map-set escrows escrow-id (merge escrow { status: STATUS-REFUNDED }))
          (try! (stx-transfer? (get amount escrow) CONTRACT-ADDRESS (get buyer escrow))))
        (begin
          (map-set escrows escrow-id (merge escrow { status: STATUS-COMPLETED }))
          (try! (stx-transfer? (get amount escrow) CONTRACT-ADDRESS (get seller escrow)))))
      (ok true)
    )
  )
)

;; Read-only
(define-read-only (get-escrow (escrow-id uint))
  (map-get? escrows escrow-id)
)

;; CLARITY 4 FEATURE: to-ascii? for escrow status
(define-read-only (get-escrow-status-ascii (escrow-id uint))
  (match (map-get? escrows escrow-id)
    escrow (let (
      (amount-ascii (match (to-ascii? (get amount escrow)) ok-val ok-val err "0"))
      (status-val (get status escrow))
      (status-str (if (is-eq status-val STATUS-ACTIVE) "ACTIVE"
        (if (is-eq status-val STATUS-COMPLETED) "COMPLETED"
        (if (is-eq status-val STATUS-DISPUTED) "DISPUTED"
        "REFUNDED"))))
    )
      (ok {
        buyer: (get buyer escrow),
        seller: (get seller escrow),
        amount: amount-ascii,
        status: status-str
      })
    )
    (ok {
        buyer: tx-sender,
        seller: tx-sender,
        amount: "0",
        status: "NOT_FOUND"
    })
  )
)

```
