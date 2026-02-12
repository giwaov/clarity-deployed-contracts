;; title: privacy-management
;; version:
;; summary:
;; description:

;; title: PrivacyNetwork
;; version:
;; summary:
;; description:

;; ENHANCED PRIVACY RIGHTS MANAGEMENT SYSTEM (EPRMS)
;;
;; A next-generation blockchain-native privacy management platform that empowers
;; organizations to achieve comprehensive data protection compliance while providing
;; users with granular control over their personal information. This system enables
;; transparent consent management, automated privacy policy versioning, immutable
;; audit trails for data processing activities, and seamless implementation of
;; data subject rights as mandated by GDPR, CCPA, and other privacy regulations.
;;
;; Key Features:
;; - Immutable privacy policy versioning with cryptographic integrity
;; - Granular user consent management with automated verification
;; - Comprehensive audit logging for regulatory compliance
;; - Data subject rights automation (access, rectification, erasure)
;; - Emergency privacy controls and system lockdown capabilities
;; - Multi-jurisdictional compliance framework support

;; SYSTEM ERROR CODES AND CONSTANTS

(define-constant contract-administrator-address tx-sender)
(define-constant ERR-INSUFFICIENT-PRIVILEGES (err u100))
(define-constant ERR-PRIVACY-POLICY-NOT-FOUND (err u101))
(define-constant ERR-INVALID-POLICY-VERSION (err u102))
(define-constant ERR-CONSENT-RECORD-ALREADY-EXISTS (err u103))
(define-constant ERR-USER-CONSENT-RECORD-MISSING (err u104))
(define-constant ERR-DUPLICATE-POLICY-VERSION (err u105))
(define-constant ERR-INVALID-DATA-CATEGORY (err u106))
(define-constant ERR-INVALID-PROCESSING-PURPOSE (err u107))
(define-constant ERR-MALFORMED-INPUT-PARAMETERS (err u108))

;; GLOBAL SYSTEM STATE VARIABLES

(define-data-var current-active-policy-version-number uint u0)
(define-data-var total-privacy-policies-registered uint u0)
(define-data-var system-emergency-lockdown-status bool false)

;; PRIVACY POLICY REPOSITORY
;; Comprehensive storage for all privacy policy versions with metadata

(define-map privacy-policy-metadata-repository
  { privacy-policy-version-id: uint }
  {
    policy-document-name: (string-ascii 100),
    document-integrity-hash: (buff 32),
    policy-effective-date: uint,
    policy-expiration-date: (optional uint),
    policy-creator-address: principal,
    policy-active-status: bool,
  }
)

;; USER CONSENT RECORDS STORAGE
;; Individual consent tracking across policy versions

(define-map user-consent-records-database
  {
    user-wallet-address: principal,
    policy-version-id: uint,
  }
  {
    consent-timestamp: uint,
    consent-type: (string-ascii 20),
    permitted-processing-operations: (list 10 (string-ascii 50)),
    data-retention-period: uint,
    revocation-allowed: bool,
  }
)

;; PERSONAL PRIVACY CONFIGURATION STORE
;; User-specific privacy preferences and communication settings

(define-map personal-privacy-settings-registry
  { settings-owner-address: principal }
  {
    allow-marketing-communications: bool,
    allow-analytics-tracking: bool,
    permit-third-party-sharing: bool,
    custom-retention-period: uint,
    contact-method-preference: (string-ascii 20),
    settings-last-updated: uint,
  }
)

;; DATA PROCESSING ACTIVITIES LOG
;; Immutable audit trail for all data processing operations

(define-map data-processing-activities-ledger
  { activity-record-id: uint }
  {
    data-subject-address: principal,
    data-type-processed: (string-ascii 30),
    processing-purpose: (string-ascii 50),
    processing-timestamp: uint,
    legal-basis: (string-ascii 50),
    retention-expiry-date: uint,
  }
)

;; DATA ERASURE REQUESTS QUEUE
;; Management system for data subject deletion requests

(define-map data-erasure-requests-queue
  {
    requester-address: principal,
    erasure-request-id: uint,
  }
  {
    request-submission_date: uint,
    data-categories-to-delete: (list 10 (string-ascii 30)),
    request-status: (string-ascii 20),
    completion-date: (optional uint),
    processing-notes: (optional (string-ascii 200)),
  }
)

;; AUTO-INCREMENT COUNTERS

(define-data-var next-processing-activity-id uint u1)
(define-data-var next-erasure-request-id uint u1)

;; INPUT VALIDATION UTILITIES

(define-private (is-valid-policy-title (title (string-ascii 100)))
  (let ((title-character-count (len title)))
    (and (> title-character-count u0) (<= title-character-count u100))
  )
)

(define-private (is-valid-document-hash (hash (buff 32)))
  (is-eq (len hash) u32)
)

(define-private (is-valid-timestamp (timestamp uint))
  (and (> timestamp u0) (<= timestamp u4294967295))
)

(define-private (is-valid-retention-period (retention-blocks uint))
  (and (> retention-blocks u0) (<= retention-blocks u525600))
)

(define-private (is-valid-policy-version (version uint))
  (and (> version u0) (<= version u1000000))
)

(define-private (is-valid-text-content (content (string-ascii 50)))
  (let ((content-character-count (len content)))
    (and (> content-character-count u0) (<= content-character-count u50))
  )
)

(define-private (is-valid-data-category (category (string-ascii 30)))
  (or
    (is-eq category "personal-identifiers")
    (is-eq category "financial-data")
    (is-eq category "health-records")
    (is-eq category "behavioral-analytics")
    (is-eq category "technical-metadata")
  )
)

(define-private (is-valid-communication-method (method (string-ascii 20)))
  (or
    (is-eq method "email")
    (is-eq method "telephone")
    (is-eq method "postal-mail")
    (is-eq method "no-contact")
  )
)

(define-private (is-valid-consent-type (consent-type (string-ascii 20)))
  (or
    (is-eq consent-type "explicit-consent")
    (is-eq consent-type "implied-consent")
    (is-eq consent-type "consent-withdrawn")
  )
)

(define-private (is-valid-request-status (status (string-ascii 20)))
  (or
    (is-eq status "awaiting-review")
    (is-eq status "under-processing")
    (is-eq status "successfully-completed")
    (is-eq status "request-rejected")
  )
)

(define-private (is-valid-processing-list (operations (list 10 (string-ascii 50))))
  (and
    (> (len operations) u0)
    (<= (len operations) u10)
  )
)

(define-private (is-valid-categories-list (categories (list 10 (string-ascii 30))))
  (and
    (> (len categories) u0)
    (<= (len categories) u10)
  )
)

(define-private (is-valid-request-id (request-id uint))
  (and (> request-id u0) (<= request-id u1000000))
)

(define-private (is-valid-optional-timestamp (optional-timestamp (optional uint)))
  (match optional-timestamp
    timestamp-value (is-valid-timestamp timestamp-value)
    true
  )
)

(define-private (is-valid-user-address (user-address principal))
  (not (is-eq user-address 'SP000000000000000000002Q6VF78))
)

;; PUBLIC READ-ONLY QUERY FUNCTIONS

(define-read-only (get-active-policy-version)
  (var-get current-active-policy-version-number)
)

(define-read-only (get-policy-details-by-version (policy-version uint))
  (map-get? privacy-policy-metadata-repository { privacy-policy-version-id: policy-version })
)

(define-read-only (get-user-consent-for-policy
    (user-address principal)
    (policy-version uint)
  )
  (map-get? user-consent-records-database {
    user-wallet-address: user-address,
    policy-version-id: policy-version,
  })
)

(define-read-only (get-current-consent-status (user-address principal))
  (let ((active-policy (var-get current-active-policy-version-number)))
    (map-get? user-consent-records-database {
      user-wallet-address: user-address,
      policy-version-id: active-policy,
    })
  )
)

(define-read-only (get-privacy-preferences (user-address principal))
  (map-get? personal-privacy-settings-registry { settings-owner-address: user-address })
)

(define-read-only (verify-active-consent (user-address principal))
  (let (
      (active-policy-version (var-get current-active-policy-version-number))
      (user-consent-data (map-get? user-consent-records-database {
        user-wallet-address: user-address,
        policy-version-id: active-policy-version,
      }))
    )
    (match user-consent-data
      consent-details (and
        (not (is-eq (get consent-type consent-details) "consent-withdrawn"))
        (get revocation-allowed consent-details)
      )
      false
    )
  )
)
