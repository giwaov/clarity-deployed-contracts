;; ============================================
;; SCredence - Service Verification Contract
;; Bitcoin-Anchored Verification for Professional Service
;; ============================================

;; ============================================
;; Error Constants
;; ============================================
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ISSUER_NOT_AUTHORIZED (err u101))
(define-constant ERR_ISSUER_ALREADY_EXISTS (err u102))
;; ERR_PROOF_ALREADY_EXISTS removed as unused
(define-constant ERR_PROOF_NOT_FOUND (err u104))
(define-constant ERR_INVALID_SERVICE_TYPE (err u105))
(define-constant ERR_INVALID_DURATION (err u106))
(define-constant ERR_INVALID_NAME (err u107))
(define-constant ERR_INVALID_ORG_TYPE (err u108))
(define-constant ERR_INVALID_PARTICIPANT (err u109))
(define-constant ERR_INVALID_HASH (err u110))
(define-constant ERR_INVALID_URI (err u111))
(define-constant ERR_PROOF_REVOKED (err u112))
(define-constant ERR_PROOF_EXPIRED (err u113))

;; ============================================
;; Service Type Constants
;; ============================================
(define-constant SERVICE_TYPE_INTERNSHIP u1)
(define-constant SERVICE_TYPE_NYSC u2)
(define-constant SERVICE_TYPE_VOLUNTEERING u3)
(define-constant SERVICE_TYPE_APPRENTICESHIP u4)
(define-constant SERVICE_TYPE_TRAINING u5)
(define-constant SERVICE_TYPE_CDS u6)

;; ============================================
;; Data Variables
;; ============================================
(define-constant CONTRACT_OWNER tx-sender)
(define-data-var total-issuers uint u0)
(define-data-var total-proofs uint u0)

;; ============================================
;; Data Maps
;; ============================================

;; Authorized issuers (organizations, employers, institutions)
(define-map authorized-issuers
  principal
  {
    name: (string-ascii 100),
    organization-type: (string-ascii 50),
    authorized-at: uint,
    authorized-by: principal,
    is-active: bool
  }
)

;; Service proofs
(define-map service-proofs
  { proof-id: uint }
  {
    participant: principal,
    issuer: principal,
    service-type: uint,
    credential-hash: (buff 32),
    start-date: uint,
    end-date: uint,
    duration-days: uint,
    issued-at: uint,
    expiry-date: (optional uint),
    metadata-uri: (optional (string-ascii 256))
  }
)

;; Participant's proof index (for easy lookup)
(define-map participant-proofs
  { participant: principal, index: uint }
  uint  ;; proof-id
)

;; Track number of proofs per participant
(define-map participant-proof-count
  principal
  uint
)

;; Revoked proofs tracking
(define-map revoked-proofs
  uint  ;; proof-id
  {
    revoked-at: uint,
    reason: (string-ascii 100)
  }
)

;; ============================================
;; Read-Only Functions
;; ============================================

;; Get contract owner
(define-read-only (get-contract-owner)
  (ok CONTRACT_OWNER)
)

;; Check if an address is an authorized issuer
(define-read-only (is-authorized-issuer (issuer principal))
  (match (map-get? authorized-issuers issuer)
    issuer-data (get is-active issuer-data)
    false
  )
)

;; Get issuer details
(define-read-only (get-issuer-details (issuer principal))
  (ok (map-get? authorized-issuers issuer))
)

;; Get service proof by ID
(define-read-only (get-service-proof (proof-id uint))
  (ok (map-get? service-proofs { proof-id: proof-id }))
)

;; Get participant's proof count
(define-read-only (get-participant-proof-count (participant principal))
  (ok (default-to u0 (map-get? participant-proof-count participant)))
)

;; Get participant's proof by index
(define-read-only (get-participant-proof-by-index (participant principal) (index uint))
  (match (map-get? participant-proofs { participant: participant, index: index })
    proof-id (get-service-proof proof-id)
    (ok none)
  )
)

;; Check if a proof is revoked
(define-read-only (is-proof-revoked (proof-id uint))
  (is-some (map-get? revoked-proofs proof-id))
)

;; Check if a proof is expired
(define-read-only (is-proof-expired (proof-id uint))
  (match (map-get? service-proofs { proof-id: proof-id })
    proof-data (match (get expiry-date proof-data)
      exp (< exp stacks-block-time)
      false
    )
    false
  )
)

;; Get revocation details if any
(define-read-only (get-revocation-details (proof-id uint))
  (map-get? revoked-proofs proof-id)
)

;; Get total statistics
(define-read-only (get-statistics)
  (ok {
    total-issuers: (var-get total-issuers),
    total-proofs: (var-get total-proofs)
  })
)

;; Verify a service proof
(define-read-only (verify-proof (proof-id uint) (expected-hash (buff 32)))
  (match (map-get? service-proofs { proof-id: proof-id })
    proof-data
      (ok {
        is-valid: (and 
          (is-eq (get credential-hash proof-data) expected-hash)
          (not (is-proof-revoked proof-id))
          (not (is-proof-expired proof-id))
        ),
        participant: (get participant proof-data),
        issuer: (get issuer proof-data),
        service-type: (get service-type proof-data),
        issued-at: (get issued-at proof-data),
        is-revoked: (is-proof-revoked proof-id),
        is-expired: (is-proof-expired proof-id)
      })
    ERR_PROOF_NOT_FOUND
  )
)

;; ============================================
;; Public Functions - Admin
;; ============================================

;; Register a new authorized issuer (only contract owner)
(define-public (register-issuer 
  (issuer principal)
  (name (string-ascii 100))
  (organization-type (string-ascii 50))
)
  (begin
    ;; Only contract owner can register issuers
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    ;; Validate inputs
    (asserts! (> (len name) u0) ERR_INVALID_NAME)
    (asserts! (> (len organization-type) u0) ERR_INVALID_ORG_TYPE)
    
    ;; Check if issuer already exists
    (asserts! (is-none (map-get? authorized-issuers issuer)) ERR_ISSUER_ALREADY_EXISTS)
    
    ;; Register the issuer
    (map-set authorized-issuers issuer {
      name: name,
      organization-type: organization-type,
      authorized-at: stacks-block-time,
      authorized-by: tx-sender,
      is-active: true
    })
    
    ;; Increment total issuers
    (var-set total-issuers (+ (var-get total-issuers) u1))
    
    (ok true)
  )
)

;; Revoke issuer authorization (only contract owner)
(define-public (revoke-issuer (issuer principal))
  (begin
    ;; Only contract owner can revoke issuers
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq issuer CONTRACT_OWNER)) ERR_UNAUTHORIZED) ;; Cannot revoke owner (validation)
    
    ;; Get existing issuer data
    (match (map-get? authorized-issuers issuer)
      issuer-data
        (begin
          ;; Update issuer status to inactive
          (map-set authorized-issuers issuer
            (merge issuer-data { is-active: false })
          )
          (ok true)
        )
      ERR_ISSUER_NOT_AUTHORIZED
    )
  )
)

;; ============================================
;; Public Functions - Issuer
;; ============================================

;; Issue a service proof (only authorized issuers)
(define-public (issue-service-proof
  (participant principal)
  (service-type uint)
  (credential-hash (buff 32))
  (start-date uint)
  (end-date uint)
  (duration-days uint)
  (expiry-date (optional uint))
  (metadata-uri (optional (string-ascii 256)))
)
  (let
    (
      (proof-id (+ (var-get total-proofs) u1))
      (participant-count (default-to u0 (map-get? participant-proof-count participant)))
    )
    ;; Only authorized issuers can issue proofs
    (asserts! (is-authorized-issuer tx-sender) ERR_ISSUER_NOT_AUTHORIZED)
    
    ;; Validate inputs
    (asserts! (not (is-eq participant tx-sender)) ERR_INVALID_PARTICIPANT) ;; Issuer cannot issue to self
    (asserts! (is-eq (len credential-hash) u32) ERR_INVALID_HASH)
    (asserts! (match metadata-uri uri (> (len uri) u0) true) ERR_INVALID_URI)
    
    ;; Validate service type
    (asserts! 
      (or
        (is-eq service-type SERVICE_TYPE_INTERNSHIP)
        (is-eq service-type SERVICE_TYPE_NYSC)
        (is-eq service-type SERVICE_TYPE_VOLUNTEERING)
        (is-eq service-type SERVICE_TYPE_APPRENTICESHIP)
        (is-eq service-type SERVICE_TYPE_TRAINING)
        (is-eq service-type SERVICE_TYPE_CDS)
      )
      ERR_INVALID_SERVICE_TYPE
    )
    
    ;; Validate duration
    (asserts! (> duration-days u0) ERR_INVALID_DURATION)
    (asserts! (> end-date start-date) ERR_INVALID_DURATION)

    ;; Validate expiry
    (match expiry-date exp (asserts! (> exp end-date) ERR_INVALID_DURATION) true)
    
    ;; Create the service proof
    (map-set service-proofs { proof-id: proof-id } {
      participant: participant,
      issuer: tx-sender,
      service-type: service-type,
      credential-hash: credential-hash,
      start-date: start-date,
      end-date: end-date,
      duration-days: duration-days,
      issued-at: stacks-block-time,
      expiry-date: expiry-date,
      metadata-uri: metadata-uri
    })
    
    ;; Add to participant's proof index
    (map-set participant-proofs 
      { participant: participant, index: participant-count }
      proof-id
    )
    
    ;; Update participant proof count
    (map-set participant-proof-count participant (+ participant-count u1))
    
    ;; Increment total proofs
    (var-set total-proofs proof-id)
    
    ;; Print event for indexing
    (print {
      event: "service-proof-issued",
      proof-id: proof-id,
      participant: participant,
      issuer: tx-sender,
      service-type: service-type,
      issued-at: stacks-block-time
    })
    
    (ok proof-id)
  )
)

;; Revoke a service proof (only by the original issuer)
(define-public (revoke-service-proof (proof-id uint) (reason (string-ascii 100)))
  (let
    (
      (proof-data (unwrap! (map-get? service-proofs { proof-id: proof-id }) ERR_PROOF_NOT_FOUND))
    )
    ;; Only the original issuer can revoke the proof
    (asserts! (is-eq (get issuer proof-data) tx-sender) ERR_UNAUTHORIZED)
    
    ;; Check if already revoked
    (asserts! (is-none (map-get? revoked-proofs proof-id)) ERR_PROOF_REVOKED)
    
    ;; Add to revoked-proofs map
    (map-set revoked-proofs proof-id {
      revoked-at: stacks-block-time,
      reason: reason
    })
    
    ;; Print event for indexing
    (print {
      event: "service-proof-revoked",
      proof-id: proof-id,
      issuer: tx-sender,
      revoked-at: stacks-block-time,
      reason: reason
    })
    
    (ok true)
  )
)

;; Renew an existing service proof (only by original issuer)
(define-public (renew-service-proof (proof-id uint) (new-expiry uint))
  (let
    (
      (proof-data (unwrap! (map-get? service-proofs { proof-id: proof-id }) ERR_PROOF_NOT_FOUND))
    )
    ;; Only the original issuer can renew the proof
    (asserts! (is-eq (get issuer proof-data) tx-sender) ERR_UNAUTHORIZED)
    
    ;; Check if revoked
    (asserts! (not (is-proof-revoked proof-id)) ERR_PROOF_REVOKED)

    ;; Validate new expiry is in the future
    (asserts! (> new-expiry stacks-block-time) ERR_INVALID_DURATION)
    
    ;; Update the service proof with new expiry
    (map-set service-proofs { proof-id: proof-id } 
      (merge proof-data { expiry-date: (some new-expiry) })
    )
    
    ;; Print event for indexing
    (print {
      event: "service-proof-renewed",
      proof-id: proof-id,
      issuer: tx-sender,
      new-expiry: new-expiry,
      renewed-at: stacks-block-time
    })
    
    (ok true)
  )
)

;; Get all proofs for a participant (returns list of proof IDs)
(define-read-only (get-participant-proofs (participant principal))
  (ok {
    count: (default-to u0 (map-get? participant-proof-count participant)),
    participant: participant
  })
)

;; ============================================
;; Initialization
;; ============================================

;; Contract initialization
;; The deployer becomes the contract owner and can register issuers
