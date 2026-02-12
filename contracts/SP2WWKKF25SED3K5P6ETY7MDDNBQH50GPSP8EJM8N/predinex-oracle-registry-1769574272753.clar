;; ============================================
;; PREDINEX ORACLE REGISTRY
;; ============================================
;; Manages oracle providers and data submissions
;; Language: Clarity 2
;; ============================================

;; Constants & Errors
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED u401)
(define-constant ERR-ORACLE-NOT-FOUND u430)
(define-constant ERR-ORACLE-INACTIVE u431)
(define-constant ERR-INVALID-DATA-TYPE u432)
(define-constant ERR-ORACLE-ALREADY-EXISTS u433)
(define-constant ERR-INSUFFICIENT-CONFIDENCE u434)
(define-constant ERR-ORACLE-SUBMISSION-NOT-FOUND u435)

;; Data Structures
(define-map oracle-providers
  { provider-id: uint }
  {
    provider-address: principal,
    reliability-score: uint,
    total-resolutions: uint,
    successful-resolutions: uint,
    average-response-time: uint,
    is-active: bool,
    registered-at: uint,
    last-activity: uint
  }
)

(define-map oracle-address-to-id
  { provider-address: principal }
  uint
)

(define-map oracle-data-types
  { provider-id: uint, data-type: (string-ascii 32) }
  bool
)

(define-map oracle-submissions
  { submission-id: uint }
  {
    provider-id: uint,
    pool-id: uint,
    data-value: (string-ascii 256),
    data-type: (string-ascii 32),
    timestamp: uint,
    confidence-score: uint,
    is-processed: bool
  }
)

;; State Variables
(define-data-var oracle-provider-counter uint u0)
(define-data-var oracle-submission-counter uint u0)

(define-map admins
  { admin: principal }
  bool
)

;; Read-only helpers
(define-read-only (is-admin (user principal))
  (default-to false (map-get? admins { admin: user }))
)

(define-read-only (get-provider-id-by-address (provider-address principal))
  (map-get? oracle-address-to-id { provider-address: provider-address })
)

(define-read-only (get-provider-details (provider-id uint))
  (map-get? oracle-providers { provider-id: provider-id })
)

(define-read-only (oracle-supports-data-type (provider-id uint) (data-type (string-ascii 32)))
  (default-to false (map-get? oracle-data-types { provider-id: provider-id, data-type: data-type }))
)

(define-read-only (get-submission (submission-id uint))
  (map-get? oracle-submissions { submission-id: submission-id })
)

;; Private helper
(define-private (register-data-type-for-provider (data-type (string-ascii 32)) (provider-id uint))
  (begin
    (map-insert oracle-data-types
      { provider-id: provider-id, data-type: data-type }
      true
    )
    provider-id
  )
)

;; Administrative
(define-public (set-admin (admin principal) (status bool))
  (if (is-eq tx-sender CONTRACT-OWNER)
      (begin
        (map-set admins { admin: admin } status)
        (ok true)
      )
      (err ERR-UNAUTHORIZED)
  )
)

;; Public Functions

(define-public (register-oracle-provider (provider-address principal) (supported-data-types (list 10 (string-ascii 32))))
  (let ((provider-id (var-get oracle-provider-counter)))
    (if (or (is-eq tx-sender CONTRACT-OWNER) (is-admin tx-sender))
        (if (is-none (get-provider-id-by-address provider-address))
            (begin
              (map-insert oracle-providers
                { provider-id: provider-id }
                {
                  provider-address: provider-address,
                  reliability-score: u100,
                  total-resolutions: u0,
                  successful-resolutions: u0,
                  average-response-time: u0,
                  is-active: true,
                  registered-at: burn-block-height,
                  last-activity: burn-block-height
                }
              )
              (map-insert oracle-address-to-id { provider-address: provider-address } provider-id)
              (fold register-data-type-for-provider supported-data-types provider-id)
              (var-set oracle-provider-counter (+ provider-id u1))
              (ok provider-id)
            )
            (err ERR-ORACLE-ALREADY-EXISTS)
        )
        (err ERR-UNAUTHORIZED)
    )
  )
)

(define-public (deactivate-oracle-provider (provider-id uint))
  (match (map-get? oracle-providers { provider-id: provider-id })
    provider (if (or (is-eq tx-sender CONTRACT-OWNER) (is-admin tx-sender))
                 (begin
                   (map-set oracle-providers { provider-id: provider-id } (merge provider { is-active: false }))
                   (ok true)
                 )
                 (err ERR-UNAUTHORIZED))
    (err ERR-ORACLE-NOT-FOUND)
  )
)

(define-public (reactivate-oracle-provider (provider-id uint))
  (match (map-get? oracle-providers { provider-id: provider-id })
    provider (if (or (is-eq tx-sender CONTRACT-OWNER) (is-admin tx-sender))
                 (begin
                   (map-set oracle-providers { provider-id: provider-id } (merge provider { is-active: true, last-activity: burn-block-height }))
                   (ok true)
                 )
                 (err ERR-UNAUTHORIZED))
    (err ERR-ORACLE-NOT-FOUND)
  )
)

(define-public (submit-oracle-data (pool-id uint) (data-value (string-ascii 256)) (data-type (string-ascii 32)) (confidence-score uint))
  (match (get-provider-id-by-address tx-sender)
    provider-id (match (map-get? oracle-providers { provider-id: provider-id })
      provider (let ((submission-id (var-get oracle-submission-counter)))
                 (if (get is-active provider)
                     (if (oracle-supports-data-type provider-id data-type)
                         (if (<= confidence-score u100)
                             (begin
                               ;; Note: Pool existence check removed to decouple.
                               (map-insert oracle-submissions
                                 { submission-id: submission-id }
                                 {
                                   provider-id: provider-id,
                                   pool-id: pool-id,
                                   data-value: data-value,
                                   data-type: data-type,
                                   timestamp: burn-block-height,
                                   confidence-score: confidence-score,
                                   is-processed: false
                                 }
                               )
                               (var-set oracle-submission-counter (+ submission-id u1))
                               (ok submission-id)
                             )
                             (err ERR-INSUFFICIENT-CONFIDENCE)
                         )
                         (err ERR-INVALID-DATA-TYPE)
                     )
                     (err ERR-ORACLE-INACTIVE)
                 )
               )
      (err ERR-ORACLE-NOT-FOUND)
    )
    (err ERR-ORACLE-NOT-FOUND)
  )
)
