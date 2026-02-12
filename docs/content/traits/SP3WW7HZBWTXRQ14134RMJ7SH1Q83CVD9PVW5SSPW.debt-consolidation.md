---
title: "Trait debt-consolidation"
draft: true
---
```
;; Debt Consolidation Contract
;; Consolidates multiple debts into a single loan

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INVALID_AMOUNT (err u402))
(define-constant ERR_INSUFFICIENT_FUNDS (err u403))
(define-constant ERR_LOAN_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_CONSOLIDATED (err u405))

;; Data structures
(define-map consolidation-loans
    { loan-id: uint }
    {
        borrower: principal,
        total-debt: uint,
        new-rate: uint,
        monthly-payment: uint,
        term-months: uint,
        start-block: uint,
        active: bool,
        debts-consolidated: (list 10 uint)
    }
)

(define-map original-debts
    { debt-id: uint }
    {
        creditor: principal,
        amount: uint,
        rate: uint,
        consolidated: bool
    }
)

(define-data-var next-loan-id uint u1)
(define-data-var next-debt-id uint u1)
(define-data-var total-pool uint u0)

;; Add debt to be consolidated
(define-public (add-debt (creditor principal) (amount uint) (rate uint))
    (let (
        (debt-id (var-get next-debt-id))
    )
        (map-set original-debts
            { debt-id: debt-id }
            {
                creditor: creditor,
                amount: amount,
                rate: rate,
                consolidated: false
            }
        )
        (var-set next-debt-id (+ debt-id u1))
        (ok debt-id)
    )
)

;; Create consolidation loan
(define-public (consolidate-debts (debt-ids (list 10 uint)) (new-rate uint) (term-months uint))
    (let (
        (loan-id (var-get next-loan-id))
        (total-debt (calculate-total-debt debt-ids))
        (monthly-payment (calculate-monthly-payment total-debt new-rate term-months))
    )
        (asserts! (> total-debt u0) ERR_INVALID_AMOUNT)
        
        ;; Pay off original debts
        (try! (pay-off-debts debt-ids))
        
        ;; Create new consolidated loan
        (map-set consolidation-loans
            { loan-id: loan-id }
            {
                borrower: tx-sender,
                total-debt: total-debt,
                new-rate: new-rate,
                monthly-payment: monthly-payment,
                term-months: term-months,
                start-block: block-height,
                active: true,
                debts-consolidated: debt-ids
            }
        )
        
        ;; Mark debts as consolidated
        (try! (mark-debts-consolidated debt-ids))
        
        (var-set next-loan-id (+ loan-id u1))
        (ok loan-id)
    )
)

;; Make payment on consolidated loan
(define-public (make-payment (loan-id uint) (amount uint))
    (let (
        (loan (unwrap! (map-get? consolidation-loans { loan-id: loan-id }) ERR_LOAN_NOT_FOUND))
    )
        (asserts! (is-eq (get borrower loan) tx-sender) ERR_UNAUTHORIZED)
        (asserts! (get active loan) ERR_LOAN_NOT_FOUND)
        
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Update loan balance
        (let (
            (new-balance (- (get total-debt loan) amount))
        )
            (if (<= new-balance u0)
                (map-set consolidation-loans { loan-id: loan-id } (merge loan { active: false, total-debt: u0 }))
                (map-set consolidation-loans { loan-id: loan-id } (merge loan { total-debt: new-balance }))
            )
        )
        (ok true)
    )
)

;; Calculate total debt from debt IDs
(define-private (calculate-total-debt (debt-ids (list 10 uint)))
    (fold + (map get-debt-amount debt-ids) u0)
)

(define-private (get-debt-amount (debt-id uint))
    (match (map-get? original-debts { debt-id: debt-id })
        debt (get amount debt)
        u0
    )
)

;; Pay off original debts
(define-private (pay-off-debts (debt-ids (list 10 uint)))
    (fold pay-off-single-debt debt-ids (ok true))
)

(define-private (pay-off-single-debt (debt-id uint) (prev-result (response bool uint)))
    (match prev-result
        success (let (
            (debt (unwrap! (map-get? original-debts { debt-id: debt-id }) ERR_LOAN_NOT_FOUND))
        )
            (try! (as-contract (stx-transfer? (get amount debt) tx-sender (get creditor debt))))
            (ok true)
        )
        error (err error)
    )
)

;; Mark debts as consolidated
(define-private (mark-debts-consolidated (debt-ids (list 10 uint)))
    (fold mark-single-debt-consolidated debt-ids (ok true))
)

(define-private (mark-single-debt-consolidated (debt-id uint) (prev-result (response bool uint)))
    (match prev-result
        success (let (
            (debt (unwrap! (map-get? original-debts { debt-id: debt-id }) ERR_LOAN_NOT_FOUND))
        )
            (map-set original-debts { debt-id: debt-id } (merge debt { consolidated: true }))
            (ok true)
        )
        error (err error)
    )
)

;; Calculate monthly payment
(define-private (calculate-monthly-payment (principal uint) (annual-rate uint) (term-months uint))
    (let (
        (monthly-rate (/ annual-rate u1200)) ;; annual rate / 12 / 100
        (payment-factor (/ (* monthly-rate (pow (+ u100 monthly-rate) term-months)) 
                          (- (pow (+ u100 monthly-rate) term-months) u100)))
    )
        (/ (* principal payment-factor) u100)
    )
)

;; Read-only functions
(define-read-only (get-consolidation-loan (loan-id uint))
    (map-get? consolidation-loans { loan-id: loan-id })
)

(define-read-only (get-debt (debt-id uint))
    (map-get? original-debts { debt-id: debt-id })
)

(define-read-only (calculate-savings (debt-ids (list 10 uint)) (new-rate uint) (term-months uint))
    (let (
        (total-debt (calculate-total-debt debt-ids))
        (old-payments (calculate-old-total-payments debt-ids))
        (new-payment (calculate-monthly-payment total-debt new-rate term-months))
        (new-total (* new-payment term-months))
    )
        (if (> old-payments new-total)
            (- old-payments new-total)
            u0
        )
    )
)

(define-private (calculate-old-total-payments (debt-ids (list 10 uint)))
    (fold + (map calculate-old-payment debt-ids) u0)
)

(define-private (calculate-old-payment (debt-id uint))
    (match (map-get? original-debts { debt-id: debt-id })
        debt (* (get amount debt) (+ u100 (get rate debt)) u12) ;; simplified calculation
        u0
    )
)
```
