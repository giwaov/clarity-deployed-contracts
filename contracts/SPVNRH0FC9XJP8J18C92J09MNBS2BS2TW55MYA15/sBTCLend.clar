;; BitStack - Bitcoin-Backed Lending Protocol
;; A DeFi lending platform built on Stacks

;; title: bit-stack
;; version:
;; summary:
;; description:
;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u2))
(define-constant ERR-LOAN-NOT-FOUND (err u3))
(define-constant ERR-LOAN-ALREADY-ACTIVE (err u4))
(define-constant ERR-INVALID-INPUT (err u5))
(define-constant ERR-INSUFFICIENT-EXCESS-COLLATERAL (err u6))
(define-constant ERR-LOAN-ALREADY-LIQUIDATED (err u7))

;; traits
;;
;; Liquidation-specific constants
(define-constant LIQUIDATION-THRESHOLD u125) ;; 125% collateralization ratio
(define-constant LIQUIDATION-PENALTY u110) ;; 10% penalty on liquidation
(define-constant COLLATERAL-RATIO u150) ;; 150% initial collateralization ratio
(define-constant MAX-LOAN-DURATION u2880) ;; ~20 days (144 blocks/day)
(define-constant MAX-INTEREST-RATE u1000) ;; 10% max interest rate

;; token definitions
;;
;; Data vars
(define-data-var minimum-collateral uint u100000) ;; in sats
(define-data-var protocol-fee uint u100) ;; basis points (1% = 100)
(define-data-var last-loan-id uint u0)

;; constants
;;
;; Data maps
(define-map loans
    { loan-id: uint }
    {
        borrower: principal,
        lender: principal,
        amount: uint,
        collateral: uint,
        interest-rate: uint,
        start-height: uint,
        end-height: uint,
        status: (string-ascii 20)
    }
)

;; data vars
;;
(define-map liquidations
    { loan-id: uint }
    {
        liquidator: principal,
        liquidation-height: uint,
        liquidation-amount: uint
    }
)

;; data maps
;;
(define-map user-loans
    principal
    (list 10 uint)
)




;; Read-only functions
(define-read-only (get-loan (loan-id uint))
    (map-get? loans { loan-id: loan-id })
)

(define-read-only (get-liquidation (loan-id uint))
    (map-get? liquidations { loan-id: loan-id })
)

(define-read-only (get-user-loans (user principal))
    (default-to (list) (map-get? user-loans user))
)





;;;;;;; Private functions;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input validation functions
(define-private (is-valid-input 
    (amount uint) 
    (collateral uint) 
    (interest-rate uint) 
    (loan-duration uint)
)
    (and
        ;; Amount and collateral must be positive
        (> amount u0)
        (> collateral u0)

        ;; Interest rate within bounds
        (<= interest-rate MAX-INTEREST-RATE)

        ;; Loan duration within reasonable limits
        (and (> loan-duration u0) (<= loan-duration MAX-LOAN-DURATION))

        ;; Validate collateral ratio
        (is-collateral-ratio-valid amount collateral)
    )
)


;; Collateral and liquidation helper functions
(define-private (is-collateral-ratio-valid (loan-amount uint) (collateral-amount uint))
    (let
        (
            (min-collateral (* loan-amount COLLATERAL-RATIO))
        )
        (>= (* collateral-amount u10000) min-collateral)
    )
)

(define-private (calculate-current-collateral-ratio (loan-amount uint) (collateral-amount uint))
    (/ (* collateral-amount u10000) loan-amount)
)


;; Existing helper function
(define-private (calculate-max-withdrawable-collateral 
    (current-collateral uint) 
    (loan-amount uint)
)
    (let
        (
            (min-required (/ (* loan-amount COLLATERAL-RATIO) u10000))
            ;; Add a small buffer to prevent risky withdrawals
            (safe-buffer (/ min-required u10))
        )
        (if (> current-collateral (+ min-required safe-buffer))
            (- current-collateral (+ min-required safe-buffer))
            u0
        )
    )
)

;; Existing helper functions (calculate-interest, get-next-loan-id, etc.)
(define-private (calculate-interest (principal uint) (rate uint) (blocks uint))
    (let
        (
            (interest-per-block (/ (* principal rate) (* u10000 u144))) ;; Assuming 144 blocks per day
        )
        (* interest-per-block blocks)
    )
)

(define-private (get-next-loan-id)
    (let
        (
            (current-id (var-get last-loan-id))
            (next-id (+ current-id u1))
        )
        (var-set last-loan-id next-id)
        next-id
    )
)



;;;;;;; PUBLIC FUNCTIONS ;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Existing functions from previous implementation
(define-public (create-loan 
    (amount uint) 
    (collateral uint) 
    (interest-rate uint) 
    (loan-duration uint)
)
    (let
        (
            (caller tx-sender)
            (loan-id (get-next-loan-id))
        )
        ;; Validate all inputs
        (asserts! 
            (is-valid-input amount collateral interest-rate loan-duration) 
            ERR-INVALID-INPUT
        )

        ;; Create loan entry
        (map-set loans 
            { loan-id: loan-id }
            {
                borrower: caller,
                lender: caller,
                amount: amount,
                collateral: collateral,
                interest-rate: interest-rate,
                start-height: stacks-block-height,
                end-height: (+ stacks-block-height loan-duration),
                status: "PENDING"
            }
        )

        ;; Update user's loan list
        (map-set user-loans
            caller
            (unwrap! 
                (as-max-len? 
                    (append 
                        (default-to (list) (map-get? user-loans caller)) 
                        loan-id
                    ) 
                    u10
                )
                ERR-NOT-AUTHORIZED
            )
        )

        (ok loan-id)
    )
)


(define-public (check-and-liquidate (loan-id uint))
    (let
        (
            (loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND))
            (caller tx-sender)
        )
        ;; Additional check for loan-id
        (asserts! (> loan-id u0) ERR-INVALID-INPUT)

        ;; Ensure loan is not already liquidated or repaid
        (asserts! (is-eq (get status loan) "ACTIVE") ERR-LOAN-NOT-FOUND)

        ;; Calculate current collateral ratio
        (let
            (
                (current-ratio 
                    (calculate-current-collateral-ratio 
                        (get amount loan) 
                        (get collateral loan)
                    )
                )
            )
            ;; Check if loan is below liquidation threshold
            (asserts! (< current-ratio LIQUIDATION-THRESHOLD) ERR-INSUFFICIENT-COLLATERAL)

            ;; Calculate liquidation amount with penalty
            (let
                (
                    (penalty-multiplier LIQUIDATION-PENALTY)
                    (liquidation-amount 
                        (/ 
                            (* (get amount loan) penalty-multiplier) 
                            u100
                        )
                    )
                )
                ;; Update loan status to liquidated
                (map-set loans
                    { loan-id: loan-id }
                    (merge loan {
                        status: "LIQUIDATED",
                        collateral: u0
                    })
                )

                ;; Record liquidation details
                (map-set liquidations
                    { loan-id: loan-id }
                    {
                        liquidator: caller,
                        liquidation-height: stacks-block-height,
                        liquidation-amount: liquidation-amount
                    }
                )

                (ok liquidation-amount)
            )
        )
    )
)

;; Partial collateral withdrawal function
(define-public (withdraw-excess-collateral 
    (loan-id uint) 
    (withdrawal-amount uint)
)
    (let
        (
            (loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND))
            (caller tx-sender)
        )
        ;; Additional check for loan-id
        (asserts! (> loan-id u0) ERR-INVALID-INPUT)

        ;; Validate inputs
        (asserts! (is-eq (get borrower loan) caller) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status loan) "ACTIVE") ERR-LOAN-NOT-FOUND)

        ;; Calculate maximum withdrawable amount
        (let
            (
                (max-withdrawable 
                    (calculate-max-withdrawable-collateral 
                        (get collateral loan) 
                        (get amount loan)
                    )
                )
            )
            ;; Ensure withdrawal amount is valid
            (asserts! (> withdrawal-amount u0) ERR-INVALID-INPUT)
            (asserts! (<= withdrawal-amount max-withdrawable) ERR-INSUFFICIENT-EXCESS-COLLATERAL)

            ;; Update loan with reduced collateral
            (map-set loans
                { loan-id: loan-id }
                (merge loan {
                    collateral: (- (get collateral loan) withdrawal-amount)
                })
            )

            ;; Transfer collateral back to borrower (placeholder)
            (ok withdrawal-amount)
        )
    )
)


(define-public (fund-loan (loan-id uint))
    (let
        (
            (loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND))
            (caller tx-sender)
        )
        ;; Additional validation for loan-id
        (asserts! (> loan-id u0) ERR-INVALID-INPUT)

        (asserts! (is-eq (get status loan) "PENDING") ERR-LOAN-ALREADY-ACTIVE)
        (asserts! (not (is-eq (get borrower loan) caller)) ERR-NOT-AUTHORIZED)

        ;; Update loan status and set lender
        (map-set loans
            { loan-id: loan-id }
            (merge loan {
                lender: caller,
                status: "ACTIVE"
            })
        )

        (ok true)
    )
)

(define-public (repay-loan (loan-id uint))
    (let
        (
            (loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND))
            (caller tx-sender)
        )
        ;; Additional validation for loan-id
        (asserts! (> loan-id u0) ERR-INVALID-INPUT)

        (asserts! (is-eq (get borrower loan) caller) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status loan) "ACTIVE") ERR-LOAN-NOT-FOUND)

        ;; Calculate repayment amount with interest
        (let
            (
                (interest-amount (calculate-interest
                    (get amount loan)
                    (get interest-rate loan)
                    (- stacks-block-height (get start-height loan))
                ))
                (total-repayment (+ (get amount loan) interest-amount))
            )

            ;; Update loan status
            (map-set loans
                { loan-id: loan-id }
                (merge loan {
                    status: "REPAID"
                })
            )

            (ok true)
        )
    )
)

