---
title: "Trait course-monetization"
draft: true
---
```
;; title: course-monetization
;; Educational Content Marketplace Smart Contract
;; A decentralized platform enabling educators to monetize digital learning materials
;; through blockchain-based transactions. Features include automated royalty splits,
;; time-based access management, and transparent commission handling.

(define-constant platform-administrator tx-sender)

;; Error codes for operation failures
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-RESOURCE-NOT-FOUND (err u101))
(define-constant ERR-DUPLICATE-ENTRY (err u102))
(define-constant ERR-PERMISSION-DENIED (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-INVALID-PRICE (err u105))
(define-constant ERR-CONTENT-UNAVAILABLE (err u106))
(define-constant ERR-INVALID-INPUT (err u107))

;; Platform configuration constants
(define-constant maximum-items-per-educator u100)
(define-constant access-duration-in-blocks u90000)
(define-constant percentage-calculation-base u10000)
(define-constant maximum-commission-percentage u2500)

;; Primary storage for educational content metadata
(define-map educational-materials
  { material-identifier: uint }
  {
    educator-principal: principal,
    material-title: (string-ascii 100),
    material-summary: (string-utf8 500),
    cost-in-microstacks: uint,
    subject-area: (string-ascii 50),
    creation-block-height: uint,
    is-active: bool
  }
)

;; Index mapping educators to their published material identifiers
(define-map educator-portfolio
  { educator-principal: principal }
  { material-identifiers: (list 100 uint) }
)

;; Records of learner purchases and access timestamps
(define-map learner-purchases
  { learner-principal: principal, material-identifier: uint }
  { purchase-block-height: uint, expiration-block-height: uint }
)

;; Index mapping learners to their acquired material identifiers
(define-map learner-library
  { learner-principal: principal }
  { acquired-material-identifiers: (list 100 uint) }
)

;; Platform revenue percentage stored in basis points
(define-data-var platform-fee-percentage uint u250)

;; Sequential counter for material identification
(define-data-var next-available-identifier uint u1)

;; Generates next unique identifier and increments counter
(define-private (generate-material-identifier)
  (let
    ((identifier-to-assign (var-get next-available-identifier)))
    (begin
      (var-set next-available-identifier (+ identifier-to-assign u1))
      identifier-to-assign
    )
  )
)

;; Computes platform commission from total transaction amount
(define-private (compute-platform-commission (transaction-total uint))
  (/ (* transaction-total (var-get platform-fee-percentage)) percentage-calculation-base)
)

;; Appends identifier to list with length validation
(define-private (append-to-identifier-list (identifier uint) (existing-list (list 100 uint)))
  (if (>= (len existing-list) u99)
    existing-list
    (unwrap! (as-max-len? (append existing-list identifier) u100) existing-list)
  )
)

;; Verifies title string meets length requirements
(define-private (is-valid-title (title-string (string-ascii 100)))
  (and
    (> (len title-string) u0)
    (<= (len title-string) u100)
  )
)

;; Verifies description string meets length requirements
(define-private (is-valid-description (description-string (string-utf8 500)))
  (and
    (> (len description-string) u0)
    (<= (len description-string) u500)
  )
)

;; Verifies category string meets length requirements
(define-private (is-valid-category (category-string (string-ascii 50)))
  (and
    (> (len category-string) u0)
    (<= (len category-string) u50)
  )
)

;; Confirms identifier exists within valid range
(define-private (is-valid-identifier (identifier uint))
  (and
    (> identifier u0)
    (< identifier (var-get next-available-identifier))
  )
)

;; Checks if learner has purchased specific material
(define-read-only (has-purchased-material (learner-principal principal) (material-identifier uint))
  (is-some (map-get? learner-purchases { learner-principal: learner-principal, material-identifier: material-identifier }))
)

;; Determines if material is available for purchase
(define-read-only (is-material-available (material-identifier uint))
  (match (map-get? educational-materials { material-identifier: material-identifier })
    material-data (get is-active material-data)
    false
  )
)

;; Retrieves complete material information
(define-read-only (get-material-details (material-identifier uint))
  (map-get? educational-materials { material-identifier: material-identifier })
)

;; Retrieves all materials published by educator
(define-read-only (get-educator-materials (educator-principal principal))
  (map-get? educator-portfolio { educator-principal: educator-principal })
)

;; Retrieves all materials acquired by learner
(define-read-only (get-learner-materials (learner-principal principal))
  (map-get? learner-library { learner-principal: learner-principal })
)

;; Retrieves purchase details for specific transaction
(define-read-only (get-purchase-information (learner-principal principal) (material-identifier uint))
  (map-get? learner-purchases { learner-principal: learner-principal, material-identifier: material-identifier })
)

;; Validates if learner has current access to material
(define-read-only (has-active-access (learner-principal principal) (material-identifier uint))
  (let
    ((purchase-record (map-get? learner-purchases { learner-principal: learner-principal, material-identifier: material-identifier })))

    (match purchase-record
      access-data (>= (get expiration-block-height access-data) stacks-block-height)
      false)
  )
)

;; Publishes new educational material to marketplace
(define-public (publish-material 
                (title-string (string-ascii 100)) 
                (description-string (string-utf8 500)) 
                (price-amount uint) 
                (category-string (string-ascii 50)))
  (let
    (
      (assigned-identifier (generate-material-identifier))
    )
    ;; Validate all input parameters
    (asserts! (is-valid-title title-string) ERR-INVALID-INPUT)
    (asserts! (is-valid-description description-string) ERR-INVALID-INPUT)
    (asserts! (is-valid-category category-string) ERR-INVALID-INPUT)
    (asserts! (> price-amount u0) ERR-INVALID-PRICE)

    ;; Store material metadata
    (map-set educational-materials
      { material-identifier: assigned-identifier }
      {
        educator-principal: tx-sender,
        material-title: title-string,
        material-summary: description-string,
        cost-in-microstacks: price-amount,
        subject-area: category-string,
        creation-block-height: stacks-block-height,
        is-active: true
      }
    )

    ;; Update educator's portfolio index
    (match (map-get? educator-portfolio { educator-principal: tx-sender })
      current-portfolio (map-set educator-portfolio 
                      { educator-principal: tx-sender }
                      { material-identifiers: (append-to-identifier-list assigned-identifier (get material-identifiers current-portfolio)) })
      (map-set educator-portfolio
        { educator-principal: tx-sender }
        { material-identifiers: (list assigned-identifier) })
    )

    (ok assigned-identifier)
  )
)

;; Updates metadata for existing material
(define-public (modify-material 
                (material-identifier uint) 
                (updated-title (string-ascii 100)) 
                (updated-description (string-utf8 500)) 
                (updated-price uint) 
                (updated-category (string-ascii 50)))
  (let
    ((current-material (map-get? educational-materials { material-identifier: material-identifier })))

    ;; Validate inputs and existence
    (asserts! (is-valid-identifier material-identifier) ERR-INVALID-INPUT)
    (asserts! (is-valid-title updated-title) ERR-INVALID-INPUT)
    (asserts! (is-valid-description updated-description) ERR-INVALID-INPUT)
    (asserts! (is-valid-category updated-category) ERR-INVALID-INPUT)
    (asserts! (> updated-price u0) ERR-INVALID-PRICE)
    (asserts! (is-some current-material) ERR-RESOURCE-NOT-FOUND)

    (let ((material-data (unwrap-panic current-material)))
      ;; Verify caller is material creator
      (asserts! (is-eq (get educator-principal material-data) tx-sender) ERR-PERMISSION-DENIED)

      ;; Update material with new metadata
      (map-set educational-materials
        { material-identifier: material-identifier }
        {
          educator-principal: (get educator-principal material-data),
          material-title: updated-title,
          material-summary: updated-description,
          cost-in-microstacks: updated-price,
          subject-area: updated-category,
          creation-block-height: (get creation-block-height material-data),
          is-active: (get is-active material-data)
        })

      (ok true)
    )
  )
)

;; Removes material from active marketplace listings
(define-public (remove-material (material-identifier uint))
  (let
    ((current-material (map-get? educational-materials { material-identifier: material-identifier })))

    (asserts! (is-valid-identifier material-identifier) ERR-INVALID-INPUT)
    (asserts! (is-some current-material) ERR-RESOURCE-NOT-FOUND)

    (let ((material-data (unwrap-panic current-material)))
      ;; Allow creator or administrator to deactivate
      (asserts! (or 
                  (is-eq (get educator-principal material-data) tx-sender)
                  (is-eq tx-sender platform-administrator)
                ) 
                ERR-PERMISSION-DENIED)

      ;; Mark material as inactive
      (map-set educational-materials
        { material-identifier: material-identifier }
        {
          educator-principal: (get educator-principal material-data),
          material-title: (get material-title material-data),
          material-summary: (get material-summary material-data),
          cost-in-microstacks: (get cost-in-microstacks material-data),
          subject-area: (get subject-area material-data),
          creation-block-height: (get creation-block-height material-data),
          is-active: false
        })

      (ok true)
    )
  )
)

;; ;; Processes material purchase with payment distribution
;; (define-public (purchase-material (material-identifier uint))
;;   (let
;;     (
;;       (current-material (map-get? educational-materials { material-identifier: material-identifier }))
;;     )

;;     (asserts! (is-valid-identifier material-identifier) ERR-INVALID-INPUT)
;;     (asserts! (is-some current-material) ERR-RESOURCE-NOT-FOUND)

;;     (let 
;;       (
;;         (material-data (unwrap-panic current-material))
;;       )

;;       ;; Confirm material is available
;;       (asserts! (get is-active material-data) ERR-CONTENT-UNAVAILABLE)

;;       (let
;;         (
;;           (educator-address (get educator-principal material-data))
;;           (total-cost (get cost-in-microstacks material-data))
;;           (platform-commission (compute-platform-commission total-cost))
;;           (educator-payment (- total-cost platform-commission))
;;           (access-expiration (+ stacks-block-height access-duration-in-blocks))
;;         )

;;         ;; Transfer payment to educator
;;         (let ((educator-transfer-result (stx-transfer? educator-payment tx-sender educator-address)))
;;           (asserts! (is-ok educator-transfer-result) ERR-INSUFFICIENT-FUNDS)

;;           ;; Transfer commission to platform
;;           (let ((platform-transfer-result (stx-transfer? platform-commission tx-sender platform-administrator)))
;;             (asserts! (is-ok platform-transfer-result) ERR-INSUFFICIENT-FUNDS)

;;             ;; Record purchase with expiration
;;             (map-set learner-purchases
;;               { learner-principal: tx-sender, material-identifier: material-identifier }
;;               { purchase-block-height: stacks-block-height, expiration-block-height: access-expiration }
;;             )

;;             ;; Add to learner's library
;;             (match (map-get? learner-library { learner-principal: tx-sender })
;;               current-library (map-set learner-library 
;;                                 { learner-principal: tx-sender }
;;                                 { acquired-material-identifiers: (append-to-identifier-list material-identifier (get acquired-material-identifiers current-library)) })
;;               (map-set learner-library
;;                 { learner-principal: tx-sender }
;;                 { acquired-material-identifiers: (list material-identifier) })
;;             )

;;             (ok true)
;;           )
;;         )
;;       )
;;     )
;;   )
;; )

;; ;; Extends access period for owned material
;; (define-public (extend-material-access (material-identifier uint))
;;   (let
;;     (
;;       (current-purchase (map-get? learner-purchases { learner-principal: tx-sender, material-identifier: material-identifier }))
;;       (current-material (map-get? educational-materials { material-identifier: material-identifier }))
;;     )

;;     (asserts! (is-valid-identifier material-identifier) ERR-INVALID-INPUT)
;;     (asserts! (is-some current-purchase) ERR-RESOURCE-NOT-FOUND)
;;     (asserts! (is-some current-material) ERR-RESOURCE-NOT-FOUND)

;;     (let 
;;       (
;;         (purchase-data (unwrap-panic current-purchase))
;;         (material-data (unwrap-panic current-material))
;;       )

;;       ;; Verify material is still active
;;       (asserts! (get is-active material-data) ERR-CONTENT-UNAVAILABLE)

;;       (let
;;         (
;;           (educator-address (get educator-principal material-data))
;;           (extension-cost (get cost-in-microstacks material-data))
;;           (platform-commission (compute-platform-commission extension-cost))
;;           (educator-payment (- extension-cost platform-commission))
;;           (current-expiration (get expiration-block-height purchase-data))
;;           (updated-expiration (+ current-expiration access-duration-in-blocks))
;;         )

;;         ;; Process extension payment to educator
;;         (let ((educator-transfer-result (stx-transfer? educator-payment tx-sender educator-address)))
;;           (asserts! (is-ok educator-transfer-result) ERR-INSUFFICIENT-FUNDS)

;;           ;; Process extension commission to platform
;;           (let ((platform-transfer-result (stx-transfer? platform-commission tx-sender platform-administrator)))
;;             (asserts! (is-ok platform-transfer-result) ERR-INSUFFICIENT-FUNDS)

;;             ;; Update expiration date
;;             (map-set learner-purchases
;;               { learner-principal: tx-sender, material-identifier: material-identifier }
;;               { 
;;                 purchase-block-height: (get purchase-block-height purchase-data),
;;                 expiration-block-height: updated-expiration 
;;               }
;;             )

;;             (ok true)
;;           )
;;         )
;;       )
;;     )
;;   )
;; )

;; ;; Modifies platform commission percentage
;; (define-public (update-platform-fee (new-percentage-basis-points uint))
;;   (begin
;;     ;; Restrict to administrator only
;;     (asserts! (is-eq tx-sender platform-administrator) ERR-UNAUTHORIZED-ACCESS)
;;     (asserts! (<= new-percentage-basis-points maximum-commission-percentage) ERR-INVALID-PRICE)
;;     (var-set platform-fee-percentage new-percentage-basis-points)
;;     (ok true)
;;   )
;; )

;; ;; ;; Transfers accumulated platform fees to administrator
;; ;; (define-public (transfer-platform-revenue (transfer-amount uint))
;; ;;   (begin
;; ;;     ;; Verify administrator authorization
;; ;;     (asserts! (is-eq tx-sender platform-administrator) ERR-UNAUTHORIZED-ACCESS)
;; ;;     ;; Validate sufficient contract balance
;; ;;     (asserts! (<= transfer-amount (stx-get-balance (as-contract tx-sender))) ERR-INSUFFICIENT-FUNDS)
;; ;;     (as-contract (stx-transfer? transfer-amount tx-sender platform-administrator))
;; ;;   )
;; ;; )
```
