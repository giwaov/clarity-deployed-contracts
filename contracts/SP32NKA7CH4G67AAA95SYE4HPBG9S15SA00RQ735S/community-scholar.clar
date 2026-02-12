;; title: community-scholar
;; version:
;; summary:
;; description:

;; Community Scholarship Fund Smart Contract
;; Handles scholarship applications, funding, and disbursement

;; Constants
(define-constant CONTRACT_ADMINISTRATOR tx-sender)
(define-constant ERROR_UNAUTHORIZED_ACCESS (err u1))
(define-constant ERROR_APPLICATION_EXISTS (err u2))
(define-constant ERROR_DONATION_BELOW_MINIMUM (err u3))
(define-constant ERROR_INSUFFICIENT_BALANCE (err u4))
(define-constant ERROR_RECIPIENT_NOT_ELIGIBLE (err u5))
(define-constant ERROR_APPLICATION_PERIOD_CLOSED (err u6))
(define-constant ERROR_INVALID_INPUT (err u7))
(define-constant MINIMUM_DONATION_AMOUNT u1000000) ;; in microSTX (1 STX)
(define-constant MAXIMUM_SCHOLARSHIP_AMOUNT u1000000000) ;; 1000 STX
(define-constant MAXIMUM_GPA u400) ;; 4.00 GPA * 100
(define-constant MAXIMUM_ACADEMIC_YEAR u8)

;; Data Variables
(define-data-var scholarship-pool-balance uint u0)
(define-data-var application-submission-deadline uint u0)
(define-data-var scholarship-disbursement-period uint u0)

;; Data Maps
(define-map DonorRegistry
  principal
  {
    cumulative-donation-amount: uint,
    most-recent-donation-block: uint,
  }
)

(define-map ScholarshipRecipients
  principal
  {
    recipient-status: (string-ascii 20),
    scholarship-amount: uint,
    academic-performance: uint,
    field-of-study: (string-ascii 50),
    academic-year: uint,
  }
)

(define-map ScholarshipApplications
  principal
  {
    applicant-full-name: (string-ascii 50),
    academic-performance: uint,
    field-of-study: (string-ascii 50),
    academic-year: uint,
    requested-scholarship-amount: uint,
    application-status: (string-ascii 20),
  }
)

;; Private Functions
(define-private (is-administrator)
  (is-eq tx-sender CONTRACT_ADMINISTRATOR)
)

(define-private (validate-donation-amount (donation-amount uint))
  (>= donation-amount MINIMUM_DONATION_AMOUNT)
)

(define-private (update-donor-records
    (donor-address principal)
    (donation-amount uint)
  )
  (let ((current-donor-info (default-to {
      cumulative-donation-amount: u0,
      most-recent-donation-block: u0,
    }
      (map-get? DonorRegistry donor-address)
    )))
    (map-set DonorRegistry donor-address {
      cumulative-donation-amount: (+ (get cumulative-donation-amount current-donor-info) donation-amount),
      most-recent-donation-block: stacks-block-height,
    })
  )
)

(define-private (validate-applicant-name (name (string-ascii 50)))
  (and (>= (len name) u1) (<= (len name) u50))
)

(define-private (validate-grade-point-average (gpa uint))
  (<= gpa MAXIMUM_GPA)
)

(define-private (validate-selected-major (major (string-ascii 50)))
  (and (>= (len major) u1) (<= (len major) u50))
)

(define-private (validate-current-year (year uint))
  (and (>= year u1) (<= year MAXIMUM_ACADEMIC_YEAR))
)

(define-private (validate-requested-amount (amount uint))
  (<= amount MAXIMUM_SCHOLARSHIP_AMOUNT)
)

(define-private (validate-and-sanitize-application
    (applicant-name (string-ascii 50))
    (grade-point-average uint)
    (selected-major (string-ascii 50))
    (current-year uint)
    (requested-amount uint)
  )
  (begin
    ;; Perform all validations first
    (asserts! (validate-applicant-name applicant-name) ERROR_INVALID_INPUT)
    (asserts! (validate-grade-point-average grade-point-average)
      ERROR_INVALID_INPUT
    )
    (asserts! (validate-selected-major selected-major) ERROR_INVALID_INPUT)
    (asserts! (validate-current-year current-year) ERROR_INVALID_INPUT)
    (asserts! (validate-requested-amount requested-amount) ERROR_INVALID_INPUT)

    ;; Return validated data structure
    (ok {
      applicant-name: applicant-name,
      grade-point-average: grade-point-average,
      selected-major: selected-major,
      current-year: current-year,
      requested-amount: requested-amount,
    })
  )
)

(define-private (validate-principal (address principal))
  (match (principal-destruct? address)
    success true
    error false
  )
)

(define-public (submit-scholarship-application
    (applicant-name (string-ascii 50))
    (grade-point-average uint)
    (selected-major (string-ascii 50))
    (current-year uint)
    (requested-amount uint)
  )
  (let ((existing-application (map-get? ScholarshipApplications tx-sender)))
    (if (is-some existing-application)
      ERROR_APPLICATION_EXISTS
      (if (> stacks-block-height (var-get application-submission-deadline))
        ERROR_APPLICATION_PERIOD_CLOSED
        (match (validate-and-sanitize-application applicant-name grade-point-average
          selected-major current-year requested-amount
        )
          validated-data (begin
            (map-set ScholarshipApplications tx-sender {
              applicant-full-name: (get applicant-name validated-data),
              academic-performance: (get grade-point-average validated-data),
              field-of-study: (get selected-major validated-data),
              academic-year: (get current-year validated-data),
              requested-scholarship-amount: (get requested-amount validated-data),
              application-status: "PENDING",
            })
            (ok true)
          )
          error ERROR_INVALID_INPUT
        )
      )
    )
  )
)

(define-public (evaluate-scholarship-application
    (applicant-address principal)
    (is-approved bool)
  )
  (begin
    (asserts! (is-administrator) ERROR_UNAUTHORIZED_ACCESS)
    (asserts! (validate-principal applicant-address) ERROR_INVALID_INPUT)
    (match (map-get? ScholarshipApplications applicant-address)
      current-application (begin
        (map-set ScholarshipApplications applicant-address
          (merge current-application { application-status: (if is-approved
            "APPROVED"
            "REJECTED"
          ) }
          ))
        (if is-approved
          (map-set ScholarshipRecipients applicant-address {
            recipient-status: "ACTIVE",
            scholarship-amount: (get requested-scholarship-amount current-application),
            academic-performance: (get academic-performance current-application),
            field-of-study: (get field-of-study current-application),
            academic-year: (get academic-year current-application),
          })
          true
        )
        (ok true)
      )
      (err u404)
    )
  )
)

;; Read-Only Functions
(define-read-only (get-scholarship-fund-balance)
  (ok (var-get scholarship-pool-balance))
)

(define-read-only (get-donor-details (donor-address principal))
  (ok (map-get? DonorRegistry donor-address))
)

(define-read-only (get-application-details (applicant-address principal))
  (ok (map-get? ScholarshipApplications applicant-address))
)

(define-read-only (get-recipient-details (recipient-address principal))
  (ok (map-get? ScholarshipRecipients recipient-address))
)

;; Administrative Functions
(define-public (update-application-deadline (new-deadline-block uint))
  (begin
    (asserts! (is-administrator) ERROR_UNAUTHORIZED_ACCESS)
    (asserts! (> new-deadline-block stacks-block-height) ERROR_INVALID_INPUT)
    (var-set application-submission-deadline new-deadline-block)
    (ok true)
  )
)

(define-public (update-disbursement-period (new-disbursement-block uint))
  (begin
    (asserts! (is-administrator) ERROR_UNAUTHORIZED_ACCESS)
    (asserts! (> new-disbursement-block stacks-block-height) ERROR_INVALID_INPUT)
    (var-set scholarship-disbursement-period new-disbursement-block)
    (ok true)
  )
)
