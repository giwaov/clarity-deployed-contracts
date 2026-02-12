---
title: "Trait loan-insurance"
draft: true
---
```
;; Loan Insurance Contract
;; Provides insurance coverage for lending protocols

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INVALID_AMOUNT (err u402))
(define-constant ERR_INSUFFICIENT_FUNDS (err u403))
(define-constant ERR_POLICY_NOT_FOUND (err u404))
(define-constant ERR_CLAIM_DENIED (err u405))

;; Data structures
(define-map insurance-policies
    { policy-id: uint }
    {
        borrower: principal,
        loan-amount: uint,
        premium-paid: uint,
        coverage-amount: uint,
        expiry-block: uint,
        active: bool
    }
)

(define-map claims
    { claim-id: uint }
    {
        policy-id: uint,
        claimant: principal,
        amount: uint,
        status: (string-ascii 20),
        filed-at: uint
    }
)

(define-data-var next-policy-id uint u1)
(define-data-var next-claim-id uint u1)
(define-data-var insurance-pool uint u0)

;; Purchase insurance policy
(define-public (purchase-policy (loan-amount uint) (coverage-amount uint) (duration uint))
    (let (
        (policy-id (var-get next-policy-id))
        (premium (calculate-premium loan-amount coverage-amount duration))
    )
        (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
        (map-set insurance-policies
            { policy-id: policy-id }
            {
                borrower: tx-sender,
                loan-amount: loan-amount,
                premium-paid: premium,
                coverage-amount: coverage-amount,
                expiry-block: (+ block-height duration),
                active: true
            }
        )
        (var-set next-policy-id (+ policy-id u1))
        (var-set insurance-pool (+ (var-get insurance-pool) premium))
        (ok policy-id)
    )
)

;; File insurance claim
(define-public (file-claim (policy-id uint) (claim-amount uint))
    (let (
        (policy (unwrap! (map-get? insurance-policies { policy-id: policy-id }) ERR_POLICY_NOT_FOUND))
        (claim-id (var-get next-claim-id))
    )
        (asserts! (is-eq (get borrower policy) tx-sender) ERR_UNAUTHORIZED)
        (asserts! (get active policy) ERR_POLICY_NOT_FOUND)
        (asserts! (<= claim-amount (get coverage-amount policy)) ERR_INVALID_AMOUNT)
        
        (map-set claims
            { claim-id: claim-id }
            {
                policy-id: policy-id,
                claimant: tx-sender,
                amount: claim-amount,
                status: "pending",
                filed-at: block-height
            }
        )
        (var-set next-claim-id (+ claim-id u1))
        (ok claim-id)
    )
)

;; Process claim (admin only)
(define-public (process-claim (claim-id uint) (approved bool))
    (let (
        (claim (unwrap! (map-get? claims { claim-id: claim-id }) ERR_POLICY_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        
        (if approved
            (begin
                (try! (as-contract (stx-transfer? (get amount claim) tx-sender (get claimant claim))))
                (map-set claims { claim-id: claim-id } (merge claim { status: "approved" }))
                (var-set insurance-pool (- (var-get insurance-pool) (get amount claim)))
            )
            (map-set claims { claim-id: claim-id } (merge claim { status: "denied" }))
        )
        (ok approved)
    )
)

;; Calculate premium based on risk factors
(define-private (calculate-premium (loan-amount uint) (coverage-amount uint) (duration uint))
    (let (
        (base-rate u5) ;; 5% base rate
        (risk-multiplier (/ coverage-amount loan-amount))
        (time-factor (/ duration u52560)) ;; blocks per year
    )
        (/ (* coverage-amount base-rate risk-multiplier time-factor) u10000)
    )
)

;; Read-only functions
(define-read-only (get-policy (policy-id uint))
    (map-get? insurance-policies { policy-id: policy-id })
)

(define-read-only (get-claim (claim-id uint))
    (map-get? claims { claim-id: claim-id })
)

(define-read-only (get-pool-balance)
    (var-get insurance-pool)
)
```
