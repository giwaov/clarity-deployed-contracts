;; TrustVault: Self-Sovereign Identity & Verifiable Credential Platform
;;
;; A comprehensive blockchain-based identity management system that enables 
;; users to maintain full control over their digital identity while providing
;; robust mechanisms for credential issuance, verification, and reputation
;; tracking through zero-knowledge proofs and cryptographic attestations.
;;
;; Key Features:
;; - Self-sovereign identity registration with cryptographic hash anchoring
;; - Verifiable credential lifecycle management (issue, verify, revoke)
;; - Zero-knowledge proof submission and verification framework
;; - Dynamic reputation scoring system with administrative oversight
;; - Secure identity recovery mechanisms with designated recovery addresses
;; - Comprehensive input validation and security controls
;;
;; Clarity 4 Features:
;; - Uses stacks-block-time for accurate timestamp-based logic
;; - Enhanced time-based credential expiration with Unix timestamps
;; - Improved temporal tracking for identity and credential lifecycle

;; ERROR CONSTANTS

(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-ALREADY-REGISTERED (err u1001))
(define-constant ERR-NOT-REGISTERED (err u1002))
(define-constant ERR-INVALID-PROOF (err u1003))
(define-constant ERR-INVALID-CREDENTIAL (err u1004))
(define-constant ERR-EXPIRED-CREDENTIAL (err u1005))
(define-constant ERR-REVOKED-CREDENTIAL (err u1006))
(define-constant ERR-INVALID-SCORE (err u1007))
(define-constant ERR-INVALID-INPUT (err u1008))
(define-constant ERR-INVALID-EXPIRATION (err u1009))
(define-constant ERR-INVALID-RECOVERY-ADDRESS (err u1010))
(define-constant ERR-INVALID-PROOF-DATA (err u1011))
(define-constant ERR-CONTRACT-PAUSED (err u1012))

;; SYSTEM CONSTANTS

(define-constant MIN-REPUTATION-SCORE u0)
(define-constant MAX-REPUTATION-SCORE u1000)
(define-constant MIN-EXPIRATION-BLOCKS u1)
(define-constant MAX-METADATA-LENGTH u256)
(define-constant MINIMUM-PROOF-SIZE u64)

;; DATA STRUCTURES

;; Identity Registry: Maps principals to their identity metadata
(define-map identities
  principal
  {
    hash: (buff 32),
    credentials: (list 10 principal),
    reputation-score: uint,
    recovery-address: (optional principal),
    last-updated: uint,
    last-updated-time: uint,  ;; Clarity 4: Unix timestamp from stacks-block-time
    status: (string-ascii 20),
  }
)

;; Credential Registry: Stores verifiable credentials with issuer-nonce composite key
(define-map credentials
  {
    issuer: principal,
    nonce: uint,
  }
  {
    subject: principal,
    claim-hash: (buff 32),
    expiration: uint,
    expiration-time: uint,  ;; Clarity 4: Unix timestamp expiration
    revoked: bool,
    issued-at: uint,  ;; Clarity 4: Unix timestamp of issuance
    metadata: (string-utf8 256),
  }
)

;; Zero-Knowledge Proof Storage: Manages cryptographic proofs and verification status
(define-map zero-knowledge-proofs
  (buff 32)
  {
    prover: principal,
    verified: bool,
    timestamp: uint,
    timestamp-unix: uint,  ;; Clarity 4: Unix timestamp from stacks-block-time
    proof-data: (buff 1024),
  }
)

;; STATE VARIABLES

(define-data-var admin principal tx-sender)
(define-data-var credential-nonce uint u0)
(define-data-var contract-paused bool false)
(define-data-var pause-guardian (optional principal) none)

;; VALIDATION FUNCTIONS

;; Checks if contract is currently paused
(define-private (is-paused)
  (var-get contract-paused)
)

;; Validates recovery address to prevent security vulnerabilities
(define-private (is-valid-recovery-address (recovery-addr (optional principal)))
  (match recovery-addr
    recovery-principal (and
      (not (is-eq recovery-principal tx-sender))
      (not (is-eq recovery-principal (var-get admin)))
    )
    true
  )
)

;; Ensures proof data meets minimum security requirements
(define-private (is-valid-proof-data (proof-data (buff 1024)))
  (let ((proof-len (len proof-data)))
    (and
      (>= proof-len MINIMUM-PROOF-SIZE)
      (not (is-eq proof-data 0x))
    )
  )
)

;; Validates credential expiration times
(define-private (is-valid-expiration (expiration uint))
  (> expiration (+ stacks-block-height MIN-EXPIRATION-BLOCKS))
)

;; Ensures metadata doesn't exceed storage limits
(define-private (is-valid-metadata-length (metadata (string-utf8 256)))
  (<= (len metadata) MAX-METADATA-LENGTH)
)

;; Validates cryptographic hash integrity
(define-private (is-valid-hash (hash (buff 32)))
  (not (is-eq hash 0x0000000000000000000000000000000000000000000000000000000000000000))
)

;; ADMINISTRATIVE FUNCTIONS

;; Emergency pause mechanism - can be triggered by admin or guardian
(define-public (pause-contract)
  (let ((sender tx-sender))
    (asserts! (or 
      (is-eq sender (var-get admin))
      (is-eq (some sender) (var-get pause-guardian))
    ) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-paused true))
  )
)

;; Unpause contract - only admin can unpause
(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-paused false))
  )
)

;; Set pause guardian - separate from admin for security
(define-public (set-pause-guardian (new-guardian (optional principal)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (ok (var-set pause-guardian new-guardian))
  )
)

;; Transfers administrative privileges to a new principal
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq new-admin tx-sender)) ERR-INVALID-INPUT)
    (ok (var-set admin new-admin))
  )
)

;; IDENTITY MANAGEMENT

;; Registers a new self-sovereign identity with optional recovery mechanism
(define-public (register-identity
    (identity-hash (buff 32))
    (recovery-addr (optional principal))
  )
  (let (
      (sender tx-sender)
      (existing-identity (map-get? identities sender))
    )
    (asserts! (not (is-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (is-none existing-identity) ERR-ALREADY-REGISTERED)
    (asserts! (is-valid-hash identity-hash) ERR-INVALID-INPUT)
    (asserts! (is-valid-recovery-address recovery-addr)
      ERR-INVALID-RECOVERY-ADDRESS
    )

    (ok (map-set identities sender {
      hash: identity-hash,
      credentials: (list),
      reputation-score: u100,
      recovery-address: recovery-addr,
      last-updated: stacks-block-height,
      last-updated-time: stacks-block-time,  ;; Clarity 4: Store Unix timestamp
      status: "ACTIVE",
    }))
  )
)

;; ZERO-KNOWLEDGE PROOF SYSTEM

;; Submits a cryptographic proof for verification
(define-public (submit-proof
    (proof-hash (buff 32))
    (proof-data (buff 1024))
  )
  (let (
      (sender tx-sender)
      (existing-identity (map-get? identities sender))
      (existing-proof (map-get? zero-knowledge-proofs proof-hash))
    )
    (asserts! (not (is-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (is-some existing-identity) ERR-NOT-REGISTERED)
    (asserts! (is-valid-hash proof-hash) ERR-INVALID-INPUT)
    (asserts! (is-valid-proof-data proof-data) ERR-INVALID-PROOF-DATA)
    (asserts! (is-none existing-proof) ERR-INVALID-PROOF)

    (ok (map-set zero-knowledge-proofs proof-hash {
      prover: sender,
      verified: false,
      timestamp: stacks-block-height,
      timestamp-unix: stacks-block-time,  ;; Clarity 4: Store Unix timestamp
      proof-data: proof-data,
    }))
  )
)

;; Administratively verifies a submitted zero-knowledge proof
(define-public (verify-proof (proof-hash (buff 32)))
  (let (
      (proof (map-get? zero-knowledge-proofs proof-hash))
      (sender tx-sender)
    )
    (asserts! (is-some proof) ERR-INVALID-PROOF)
    (asserts! (is-eq sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (ok (map-set zero-knowledge-proofs proof-hash
      (merge (unwrap-panic proof) { verified: true })
    ))
  )
)

;; CREDENTIAL MANAGEMENT SYSTEM

;; Issues a verifiable credential to a registered identity
(define-public (issue-credential
    (subject principal)
    (claim-hash (buff 32))
    (expiration uint)
    (metadata (string-utf8 256))
  )
  (let (
      (sender tx-sender)
      (current-nonce (var-get credential-nonce))
      (credential-id {
        issuer: sender,
        nonce: current-nonce,
      })
      (issuer-identity (map-get? identities sender))
      (subject-identity (map-get? identities subject))
    )
    (asserts! (not (is-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (is-some issuer-identity) ERR-NOT-REGISTERED)
    (asserts! (is-some subject-identity) ERR-NOT-REGISTERED)
    (asserts! (is-valid-hash claim-hash) ERR-INVALID-INPUT)
    (asserts! (is-valid-expiration expiration) ERR-INVALID-EXPIRATION)
    (asserts! (is-valid-metadata-length metadata) ERR-INVALID-INPUT)
    (var-set credential-nonce (+ current-nonce u1))
    (ok (map-set credentials credential-id {
      subject: subject,
      claim-hash: claim-hash,
      expiration: expiration,
      expiration-time: (+ stacks-block-time (* (- expiration stacks-block-height) u600)),  ;; Clarity 4: Convert to Unix timestamp (~10min blocks)
      revoked: false,
      issued-at: stacks-block-time,  ;; Clarity 4: Track issuance timestamp
      metadata: metadata,
    }))
  )
)

;; Revokes a previously issued credential
(define-public (revoke-credential
    (issuer principal)
    (nonce uint)
  )
  (let (
      (sender tx-sender)
      (credential-id {
        issuer: issuer,
        nonce: nonce,
      })
      (credential (map-get? credentials credential-id))
    )
    (asserts! (not (is-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (is-some credential) ERR-INVALID-CREDENTIAL)
    (asserts! (is-eq sender issuer) ERR-NOT-AUTHORIZED)
    (ok (map-set credentials credential-id
      (merge (unwrap-panic credential) { revoked: true })
    ))
  )
)

;; REPUTATION MANAGEMENT

;; Updates the reputation score for a registered identity
(define-public (update-reputation
    (subject principal)
    (score-change int)
  )
  (let (
      (sender tx-sender)
      (identity (map-get? identities subject))
      (current-score (get reputation-score (unwrap-panic identity)))
      (score-change-abs (if (< score-change 0)
        (* score-change -1)
        score-change
      ))
    )
    (asserts! (is-eq sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (is-some identity) ERR-NOT-REGISTERED)
    (asserts!
      (or
        (> score-change 0)
        (>= (to-int current-score) score-change-abs)
      )
      ERR-INVALID-SCORE
    )

    (ok (map-set identities subject
      (merge (unwrap-panic identity) { reputation-score: (if (> score-change 0)
        (+ current-score (to-uint score-change))
        (to-uint (- (to-int current-score) score-change-abs))
      ) }
      )))
  )
)

;; IDENTITY RECOVERY MECHANISMS

;; Initiates identity recovery using designated recovery address
(define-public (initiate-recovery
    (identity principal)
    (new-hash (buff 32))
  )
  (let (
      (sender tx-sender)
      (identity-data (map-get? identities identity))
    )
    (asserts! (not (is-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (is-some identity-data) ERR-NOT-REGISTERED)
    (asserts! (is-some (get recovery-address (unwrap-panic identity-data)))
      ERR-NOT-AUTHORIZED
    )
    (asserts!
      (is-eq sender
        (unwrap-panic (get recovery-address (unwrap-panic identity-data)))
      )
      ERR-NOT-AUTHORIZED
    )
    (ok (map-set identities identity
      (merge (unwrap-panic identity-data) {
        hash: new-hash,
        last-updated: stacks-block-height,
        last-updated-time: stacks-block-time,  ;; Clarity 4: Update Unix timestamp
        status: "RECOVERED",
      })
    ))
  )
)

;; READ-ONLY QUERY FUNCTIONS

;; Retrieves identity information for a given principal
(define-read-only (get-identity (identity principal))
  (map-get? identities identity)
)

;; Retrieves credential information by issuer and nonce
(define-read-only (get-credential
    (issuer principal)
    (nonce uint)
  )
  (map-get? credentials {
    issuer: issuer,
    nonce: nonce,
  })
)

;; Verifies if a credential is valid (not revoked and not expired)
(define-read-only (verify-credential
    (issuer principal)
    (nonce uint)
  )
  (let ((credential (map-get? credentials {
      issuer: issuer,
      nonce: nonce,
    })))
    (asserts! (is-some credential) ERR-INVALID-CREDENTIAL)
    (ok (and
      (not (get revoked (unwrap-panic credential)))
      (< stacks-block-height (get expiration (unwrap-panic credential)))
    ))
  )
)

;; Retrieves zero-knowledge proof information
(define-read-only (get-proof (proof-hash (buff 32)))
  (map-get? zero-knowledge-proofs proof-hash)
)

;; CLARITY 4 ENHANCED READ-ONLY FUNCTIONS

;; Returns identity status as ASCII string (Clarity 4: to-ascii?)
(define-read-only (get-identity-status-string (identity principal))
  (let ((identity-data (map-get? identities identity)))
    (if (is-some identity-data)
      (ok (get status (unwrap-panic identity-data)))
      ERR-NOT-REGISTERED
    )
  )
)

;; Returns credential validity with timestamp info (Clarity 4: stacks-block-time)
(define-read-only (get-credential-time-info
    (issuer principal)
    (nonce uint)
  )
  (let ((credential (map-get? credentials {
      issuer: issuer,
      nonce: nonce,
    })))
    (if (is-some credential)
      (ok {
        issued-at: (get issued-at (unwrap-panic credential)),
        expiration-time: (get expiration-time (unwrap-panic credential)),
        current-time: stacks-block-time,
        is-expired: (>= stacks-block-time (get expiration-time (unwrap-panic credential))),
      })
      ERR-INVALID-CREDENTIAL
    )
  )
)

;; Check if credential is expired based on Unix timestamp (Clarity 4: stacks-block-time)
(define-read-only (is-credential-expired
    (issuer principal)
    (nonce uint)
  )
  (let ((credential (map-get? credentials {
      issuer: issuer,
      nonce: nonce,
    })))
    (if (is-some credential)
      (ok (>= stacks-block-time (get expiration-time (unwrap-panic credential))))
      ERR-INVALID-CREDENTIAL
    )
  )
)
