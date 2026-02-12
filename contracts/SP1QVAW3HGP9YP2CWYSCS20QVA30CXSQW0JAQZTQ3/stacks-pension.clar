;; title: stacks-pension
;; version:
;; summary:
;; description:

;; Pension Fund Smart Contract

;; Define constants
(define-constant contract-admin tx-sender)
(define-constant ERR-access-denied (err u100))
(define-constant ERR-invalid-deposit-amount (err u101))
(define-constant ERR-fund-balance-too-low (err u102))
(define-constant ERR-withdrawal-criteria-not-met (err u103))
(define-constant ERR-investment-option-not-found (err u104))
(define-constant ERR-employer-not-registered (err u105))
(define-constant ERR-invalid-config-value (err u106))
(define-constant ERR-employer-already-exists (err u107))
(define-constant fund-maturity-period-years u5) ;; 5 years vesting period
(define-constant early-withdrawal-fee-percent u10) ;; 10% penalty
(define-constant maximum-allowable-retirement-age u100)
(define-constant minimum-valid-birth-year u1900)
(define-constant maximum-valid-birth-year u2100)

;; Define variables
(define-data-var retirement-age-threshold uint u65)
(define-data-var next-investment-option-id uint u1)

;; Define data maps
(define-map member-account-balances 
  { account-owner: principal, fund-option-id: uint } 
  { gross-balance: uint, available-balance: uint }
)
(define-map member-profile-data 
  principal 
  { account-creation-block: uint, 
    member-birth-year: uint,
    member-company: (optional principal) }
)
(define-map authorized-employers principal bool)
(define-map available-fund-options uint { fund-display-name: (string-ascii 20), fund-risk-level: uint })

;; Private functions

(define-private (compute-available-withdrawal-amount (account-owner principal) (fund-option-id uint))
  (match (map-get? member-profile-data account-owner)
    member-profile 
      (let (
        (account-balance (default-to { gross-balance: u0, available-balance: u0 } 
                  (map-get? member-account-balances 
                    { account-owner: account-owner, fund-option-id: fund-option-id })))
        (account-age-in-years (/ (- stacks-block-height (get account-creation-block member-profile)) u52560))
      )
        (if (>= account-age-in-years fund-maturity-period-years)
          (get gross-balance account-balance)
          (get available-balance account-balance)
        )
      )
    u0  ;; Return 0 if the participant profile doesn't exist
  )
)

(define-private (validate-birth-year-input (birth-year uint))
  (and (>= birth-year minimum-valid-birth-year) (<= birth-year maximum-valid-birth-year))
)

(define-private (verify-fund-option-exists (fund-option-id uint))
  (is-some (map-get? available-fund-options fund-option-id))
)

;; Public functions

;; Function to create a new pension account
(define-public (create-pension-account (birth-year uint))
  (let ((account-owner tx-sender))
    (asserts! (is-none (map-get? member-profile-data account-owner)) ERR-access-denied)
    (asserts! (validate-birth-year-input birth-year) ERR-invalid-config-value)
    (ok (map-set member-profile-data 
      account-owner 
      { account-creation-block: stacks-block-height, member-birth-year: birth-year, member-company: none }
    ))
  )
)

;; Read-only functions

;; Get member's account balance
(define-read-only (get-account-balance (account-owner principal) (fund-option-id uint))
  (default-to { gross-balance: u0, available-balance: u0 } 
    (map-get? member-account-balances { account-owner: account-owner, fund-option-id: fund-option-id }))
)

;; Get member's profile information
(define-read-only (get-member-profile (account-owner principal))
  (map-get? member-profile-data account-owner)
)

;; Check if member is eligible for retirement
(define-read-only (check-retirement-eligibility (account-owner principal))
  (match (get-member-profile account-owner)
    member-profile 
      (>= (- stacks-block-height (get account-creation-block member-profile)) 
          (* (var-get retirement-age-threshold) u52560))
    false
  )
)

;; Get fund option details
(define-read-only (get-fund-details (fund-option-id uint))
  (map-get? available-fund-options fund-option-id)
)

;; Check if address is authorized employer
(define-read-only (is-employer-authorized (employer-address principal))
  (default-to false (map-get? authorized-employers employer-address))
)

;; Contract owner functions

;; Update retirement age threshold
(define-public (update-retirement-age (new-retirement-age uint))
  (begin
    (asserts! (is-eq tx-sender contract-admin) ERR-access-denied)
    (asserts! (<= new-retirement-age maximum-allowable-retirement-age) ERR-invalid-config-value)
    (ok (var-set retirement-age-threshold new-retirement-age))
  )
)

;; Add new investment option
(define-public (add-new-fund-option (fund-name (string-ascii 20)) (risk-level uint))
  (let ((fund-option-id (var-get next-investment-option-id)))
    (asserts! (is-eq tx-sender contract-admin) ERR-access-denied)
    (asserts! (<= risk-level u10) ERR-invalid-config-value)
    (asserts! (> (len fund-name) u0) ERR-invalid-config-value)
    (ok (begin
      (map-set available-fund-options fund-option-id 
        { fund-display-name: fund-name, fund-risk-level: risk-level })
      (var-set next-investment-option-id (+ fund-option-id u1))
      fund-option-id
    ))
  )
)

;; Register a new employer
(define-public (add-authorized-employer (employer-address principal))
  (begin
    (asserts! (is-eq tx-sender contract-admin) ERR-access-denied)
    (asserts! (is-none (map-get? authorized-employers employer-address)) ERR-employer-already-exists)
    (ok (map-set authorized-employers employer-address true))
  )
)

;; Update employee's employer information
(define-public (link-employee-to-employer (employee-account principal) (employer-address principal))
  (begin
    (asserts! (is-employer-authorized tx-sender) ERR-employer-not-registered)
    (asserts! (is-employer-authorized employer-address) ERR-employer-not-registered)
    (asserts! (is-some (map-get? member-profile-data employee-account)) ERR-access-denied)
    (ok (map-set member-profile-data 
      employee-account 
      (merge (unwrap-panic (map-get? member-profile-data employee-account))
             { member-company: (some employer-address) })
    ))
  )
)