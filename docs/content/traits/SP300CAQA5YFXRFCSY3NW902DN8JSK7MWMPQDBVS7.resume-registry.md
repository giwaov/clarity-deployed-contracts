---
title: "Trait resume-registry"
draft: true
---
```
;; title: resume-registry
;; version:
;; summary:
;; description:

;; Professional Credentials Verification Contract
;; A decentralized system for verifying and managing professional credentials
;; including education degrees, employment history, and skill certifications.
;; Organizations can issue verifications, and individuals maintain verified profiles
;; that employers and recruiters can trust for hiring decisions.

;; Contract owner principal stored at deployment
(define-constant contract-owner tx-sender)

;; Error codes for various failure scenarios
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-UNAUTHORIZED-ACCESS (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))
(define-constant ERR-INVALID-DATA (err u104))
(define-constant ERR-CREDENTIAL-EXPIRED (err u105))
(define-constant ERR-INVALID-INPUT (err u106))

;; Sequence counters for generating unique credential identifiers
(define-data-var education-credential-counter uint u0)
(define-data-var employment-credential-counter uint u0)
(define-data-var skill-credential-counter uint u0)

;; Storage for registered organizations that can issue verifications
;; Maps organization identifier to organization details
(define-map registered-organizations
  { organization-identifier: (string-ascii 64) }
  {
    organization-name: (string-ascii 100),
    organization-domain: (string-ascii 64),
    is-verified: bool,
    authorized-principal: principal
  }
)

;; Storage for individual user profiles
;; Maps user principal to their profile information
(define-map user-profiles
  { user-address: principal }
  {
    full-name: (string-ascii 100),
    email-address: (string-ascii 100),
    profile-metadata-uri: (optional (string-utf8 256)),
    profile-created-at: uint,
    profile-updated-at: uint
  }
)

;; Storage for education credentials
;; Maps combination of user address and credential ID to education details
(define-map education-records
  { 
    holder-address: principal,
    record-identifier: (string-ascii 64)
  }
  {
    issuing-institution-id: (string-ascii 64),
    degree-title: (string-ascii 100),
    study-field: (string-ascii 100),
    education-start-date: uint,
    education-end-date: uint,
    is-verified: bool,
    verified-by: (optional principal),
    verified-at: (optional uint),
    additional-metadata-uri: (optional (string-utf8 256))
  }
)

;; Storage for employment credentials
;; Maps combination of user address and credential ID to employment details
(define-map employment-records
  { 
    holder-address: principal,
    record-identifier: (string-ascii 64)
  }
  {
    employer-organization-id: (string-ascii 64),
    job-title: (string-ascii 100),
    job-description: (string-utf8 500),
    employment-start-date: uint,
    employment-end-date: (optional uint),
    is-verified: bool,
    verified-by: (optional principal),
    verified-at: (optional uint),
    additional-metadata-uri: (optional (string-utf8 256))
  }
)

;; Storage for skill and certification credentials
;; Maps combination of user address and credential ID to skill details
(define-map skill-records
  { 
    holder-address: principal,
    record-identifier: (string-ascii 64)
  }
  {
    skill-title: (string-ascii 100),
    certification-issuer: (optional (string-ascii 64)),
    certification-issue-date: uint,
    certification-expiry-date: (optional uint),
    is-verified: bool,
    verified-by: (optional principal),
    verified-at: (optional uint),
    additional-metadata-uri: (optional (string-utf8 256))
  }
)

;; Validates that organization identifier meets length requirements
(define-private (validate-organization-id (org-id (string-ascii 64)))
  (and 
    (>= (len org-id) u1)
    (<= (len org-id) u64)
  )
)

;; Validates that credential identifier meets length requirements
(define-private (validate-record-id (record-id (string-ascii 64)))
  (and 
    (>= (len record-id) u1)
    (<= (len record-id) u64)
  )
)

;; Checks if the transaction sender is the contract owner
(define-private (check-is-contract-owner)
  (is-eq tx-sender contract-owner)
)

;; Checks if the transaction sender is authorized for a specific organization
(define-private (check-is-organization-authorized (org-id (string-ascii 64)))
  (if (validate-organization-id org-id)
    (match (map-get? registered-organizations { organization-identifier: org-id })
      organization-data (is-eq tx-sender (get authorized-principal organization-data))
      false
    )
    false
  )
)

;; Checks if transaction sender has verification rights for an organization
;; Either contract owner or organization's authorized principal
(define-private (check-verification-authorization (org-id (string-ascii 64)))
  (if (validate-organization-id org-id)
    (or (check-is-contract-owner) (check-is-organization-authorized org-id))
    false
  )
)

;; Checks if a user profile exists for given address
(define-private (check-profile-exists (user-addr principal))
  (is-some (map-get? user-profiles { user-address: user-addr }))
)

;; Checks if an organization is registered
(define-private (check-organization-exists (org-id (string-ascii 64)))
  (if (validate-organization-id org-id)
    (is-some (map-get? registered-organizations { organization-identifier: org-id }))
    false
  )
)

;; Checks if an education record exists
(define-private (check-education-record-exists (holder-addr principal) (record-id (string-ascii 64)))
  (if (validate-record-id record-id)
    (is-some (map-get? education-records { holder-address: holder-addr, record-identifier: record-id }))
    false
  )
)

;; Checks if an employment record exists
(define-private (check-employment-record-exists (holder-addr principal) (record-id (string-ascii 64)))
  (if (validate-record-id record-id)
    (is-some (map-get? employment-records { holder-address: holder-addr, record-identifier: record-id }))
    false
  )
)

;; Checks if a skill record exists
(define-private (check-skill-record-exists (holder-addr principal) (record-id (string-ascii 64)))
  (if (validate-record-id record-id)
    (is-some (map-get? skill-records { holder-address: holder-addr, record-identifier: record-id }))
    false
  )
)

;; Registers a new organization that can issue credential verifications
;; Organization starts as unverified and must be verified by contract owner
(define-public (register-organization 
    (org-id (string-ascii 64)) 
    (name (string-ascii 100)) 
    (domain (string-ascii 64)))
  (begin
    (asserts! (validate-organization-id org-id) ERR-INVALID-INPUT)
    (asserts! (>= (len name) u1) ERR-INVALID-INPUT)
    (asserts! (>= (len domain) u1) ERR-INVALID-INPUT)

    (let ((organization-data {
          organization-name: name,
          organization-domain: domain,
          is-verified: false,
          authorized-principal: tx-sender
        }))
      (if (check-organization-exists org-id)
        ERR-ALREADY-EXISTS
        (ok (map-set registered-organizations { organization-identifier: org-id } organization-data))
      )
    )
  )
)

;; Verifies an organization, allowing them to issue credential verifications
;; Only contract owner can verify organizations
(define-public (verify-organization (org-id (string-ascii 64)))
  (begin
    (asserts! (validate-organization-id org-id) ERR-INVALID-INPUT)
    (asserts! (check-is-contract-owner) ERR-OWNER-ONLY)

    (match (map-get? registered-organizations { organization-identifier: org-id })
      organization-data (ok (map-set registered-organizations 
                { organization-identifier: org-id } 
                (merge organization-data { is-verified: true })))
      ERR-NOT-FOUND
    )
  )
)

;; Updates organization information
;; Only the organization's authorized principal can update their info
(define-public (update-organization 
    (org-id (string-ascii 64)) 
    (name (string-ascii 100)) 
    (domain (string-ascii 64)))
  (begin
    (asserts! (validate-organization-id org-id) ERR-INVALID-INPUT)
    (asserts! (>= (len name) u1) ERR-INVALID-INPUT)
    (asserts! (>= (len domain) u1) ERR-INVALID-INPUT)
    (asserts! (check-is-organization-authorized org-id) ERR-UNAUTHORIZED-ACCESS)

    (match (map-get? registered-organizations { organization-identifier: org-id })
      organization-data (ok (map-set registered-organizations 
                { organization-identifier: org-id } 
                (merge organization-data { 
                  organization-name: name, 
                  organization-domain: domain 
                })))
      ERR-NOT-FOUND
    )
  )
)



;; Adds an education credential to user's profile
;; User must have a profile before adding credentials
(define-public (add-education-credential
    (institution-id (string-ascii 64))
    (degree (string-ascii 100))
    (field-of-study (string-ascii 100))
    (start-date uint)
    (end-date uint)
    (metadata-uri (optional (string-utf8 256))))
  (begin
    (asserts! (validate-organization-id institution-id) ERR-INVALID-INPUT)
    (asserts! (>= (len degree) u1) ERR-INVALID-INPUT)
    (asserts! (>= (len field-of-study) u1) ERR-INVALID-INPUT)
    (asserts! (check-profile-exists tx-sender) ERR-NOT-FOUND)
    (asserts! (<= start-date end-date) ERR-INVALID-DATA)

    (let ((current-counter (var-get education-credential-counter))
          (generated-record-id (unwrap-panic 
                          (as-max-len? 
                            (concat "EDU-" 
                                   (concat (unwrap-panic (as-max-len? institution-id u20)) 
                                           (concat "-" (unwrap-panic (as-max-len? degree u8)))))
                            u64)))
          (education-data {
            issuing-institution-id: institution-id,
            degree-title: degree,
            study-field: field-of-study,
            education-start-date: start-date,
            education-end-date: end-date,
            is-verified: false,
            verified-by: none,
            verified-at: none,
            additional-metadata-uri: metadata-uri
          }))
      (var-set education-credential-counter (+ current-counter u1))
      (asserts! (validate-record-id generated-record-id) ERR-INVALID-INPUT)

      (ok (map-set education-records 
            { holder-address: tx-sender, record-identifier: generated-record-id } 
            education-data))
    )
  )
)

;; Adds an employment credential to user's profile
;; End date is optional for current employment
(define-public (add-employment-credential
    (organization-id (string-ascii 64))
    (title (string-ascii 100))
    (description (string-utf8 500))
    (start-date uint)
    (end-date (optional uint))
    (metadata-uri (optional (string-utf8 256))))
  (begin
    (asserts! (validate-organization-id organization-id) ERR-INVALID-INPUT)
    (asserts! (>= (len title) u1) ERR-INVALID-INPUT)
    (asserts! (>= (len description) u1) ERR-INVALID-INPUT)
    (asserts! (check-profile-exists tx-sender) ERR-NOT-FOUND)

    (match end-date
      end-timestamp (asserts! (<= start-date end-timestamp) ERR-INVALID-DATA)
      true
    )

    (let ((current-counter (var-get employment-credential-counter))
          (generated-record-id (unwrap-panic 
                          (as-max-len? 
                            (concat "EMP-" 
                                   (concat (unwrap-panic (as-max-len? organization-id u20)) 
                                           (concat "-" (unwrap-panic (as-max-len? title u8)))))
                            u64)))
          (employment-data {
            employer-organization-id: organization-id,
            job-title: title,
            job-description: description,
            employment-start-date: start-date,
            employment-end-date: end-date,
            is-verified: false,
            verified-by: none,
            verified-at: none,
            additional-metadata-uri: metadata-uri
          }))
      (var-set employment-credential-counter (+ current-counter u1))
      (asserts! (validate-record-id generated-record-id) ERR-INVALID-INPUT)

      (ok (map-set employment-records 
            { holder-address: tx-sender, record-identifier: generated-record-id } 
            employment-data))
    )
  )
)

```
