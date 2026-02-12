;; Identity Registry Contract - Inspired by ERC-7812: ZK Identity Registry
;; A singleton registry system for storing abstract private provable statements on Stacks.
;; 
;; This contract implements an on-chain registry system for storing and proving abstract
;; statements. Users can store commitments to their private data and later prove its 
;; validity and authenticity via zero knowledge, without disclosing the data itself.
;;
;; Reference: https://eips.ethereum.org/EIPS/eip-7812
;; 
;; Clarity v4 Functions Used:
;; - contract-hash?: Get the hash of a contract for verification
;; - restrict-assets?: Check asset restriction status
;; - to-ascii?: Convert UTF-8 strings to ASCII
;; - stacks-block-time: Get current Stacks block timestamp
;; - secp256r1-verify: Verify secp256r1 (P-256) signatures for identity attestations

;; ==============================
;; Constants
;; ==============================

;; Contract owner for administrative functions
(define-constant CONTRACT_OWNER tx-sender)

;; Error codes following ERC-7812 patterns
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_KEY_ALREADY_EXISTS (err u1002))
(define-constant ERR_KEY_DOES_NOT_EXIST (err u1003))
(define-constant ERR_INVALID_KEY (err u1004))
(define-constant ERR_INVALID_VALUE (err u1005))
(define-constant ERR_INVALID_SIGNATURE (err u1006))
(define-constant ERR_ROOT_NOT_FOUND (err u1007))
(define-constant ERR_ASSET_RESTRICTED (err u1008))
(define-constant ERR_CONVERSION_FAILED (err u1009))
(define-constant ERR_REGISTRAR_NOT_AUTHORIZED (err u1010))
(define-constant ERR_STATEMENT_EXPIRED (err u1011))
(define-constant ERR_INVALID_PROOF (err u1012))

;; Statement expiration period (approximately 1 year in seconds)
(define-constant STATEMENT_EXPIRATION_PERIOD u31536000)

;; Maximum size for Merkle proof siblings (analogous to SMT height of 80 in ERC-7812)
(define-constant MAX_PROOF_HEIGHT u80)

;; ==============================
;; Data Variables
;; ==============================

;; Current Merkle root of the evidence database
(define-data-var current-root (buff 32) 0x0000000000000000000000000000000000000000000000000000000000000000)

;; Root version counter
(define-data-var root-version uint u0)

;; Total number of statements in the registry
(define-data-var statement-count uint u0)

;; Asset restriction flag (using Clarity v4's restrict-assets? concept)
(define-data-var assets-restricted bool false)

;; ==============================
;; Data Maps
;; ==============================

;; Evidence Database: Stores statements (key -> value) with isolated namespacing per registrar
;; Following ERC-7812's EvidenceDB pattern
(define-map evidence-db
  { isolated-key: (buff 32) }
  {
    value: (buff 32),
    registrar: principal,
    created-at: uint,
    updated-at: uint,
    exists: bool,
  }
)

;; Root history: Maps historical roots to their timestamps
;; As per ERC-7812: "The EvidenceRegistry MUST maintain the linear history of EvidenceDB roots"
(define-map root-timestamps
  { root: (buff 32) }
  { timestamp: uint, version: uint }
)

;; Authorized registrars: Contracts authorized to add/update/remove statements
;; Following ERC-7812's Registrar pattern
(define-map authorized-registrars
  principal
  {
    name: (string-utf8 64),
    authorized-at: uint,
    statement-count: uint,
    active: bool,
  }
)

;; Identity commitments: Links principals to their identity commitments
;; Implements the "commitment" concept from ERC-7812
(define-map identity-commitments
  principal
  {
    commitment: (buff 32),
    created-at: uint,
    signature-verified: bool,
    public-key: (buff 33),
  }
)

;; Statement metadata: Additional metadata for statements
(define-map statement-metadata
  { isolated-key: (buff 32) }
  {
    statement-type: (string-utf8 32),
    description: (string-utf8 256),
    ascii-description: (optional (string-ascii 256)),
  }
)

;; Merkle proofs: Store inclusion/exclusion proof data
;; Following ERC-7812's Proof struct pattern
(define-map merkle-proofs
  { key: (buff 32) }
  {
    root: (buff 32),
    existence: bool,
    aux-key: (optional (buff 32)),
    aux-value: (optional (buff 32)),
    verified-at: uint,
  }
)

;; ==============================
;; Clarity v4 Functions - Contract Info
;; ==============================

;; Get the hash of this contract using Clarity v4's contract-hash?
;; This allows verification of contract integrity
;; Note: contract-hash? returns (response (buff 32) uint)
(define-read-only (get-contract-hash)
  (contract-hash? tx-sender)
)

;; Get the hash of a specific contract for cross-contract verification
(define-read-only (get-registrar-contract-hash (registrar principal))
  (contract-hash? registrar)
)

;; ==============================
;; Clarity v4 Functions - Time
;; ==============================

;; Get current Stacks block time using Clarity v4's stacks-block-time
(define-read-only (get-current-block-time)
  stacks-block-time
)

;; Check if a statement has expired based on stacks-block-time
(define-read-only (is-statement-expired (created-at uint))
  (> stacks-block-time (+ created-at STATEMENT_EXPIRATION_PERIOD))
)

;; ==============================
;; Clarity v4 Functions - ASCII Conversion
;; ==============================

;; Convert a UTF-8 statement type to ASCII using to-ascii?
(define-read-only (statement-type-to-ascii (statement-type (string-utf8 32)))
  (to-ascii? statement-type)
)

;; Get statement description as ASCII if possible
(define-read-only (get-statement-ascii-description (isolated-key (buff 32)))
  (match (map-get? statement-metadata { isolated-key: isolated-key })
    metadata (get ascii-description metadata)
    none
  )
)

;; ==============================
;; Clarity v4 Functions - Signature Verification
;; ==============================

;; Verify a secp256r1 signature for identity attestation
;; This uses Clarity v4's secp256r1-verify for WebAuthn/passkey compatibility
(define-read-only (verify-identity-signature 
    (message-hash (buff 32))
    (signature (buff 64))
    (public-key (buff 33))
  )
  (secp256r1-verify message-hash signature public-key)
)

;; ==============================
;; Asset Restriction (Clarity v4)
;; ==============================

;; Check if operations are currently restricted
(define-read-only (are-operations-restricted)
  (var-get assets-restricted)
)

;; Toggle asset/operation restrictions (owner only)
(define-public (set-asset-restrictions (restricted bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set assets-restricted restricted)
    (print {
      event: "AssetRestrictionsUpdated",
      restricted: restricted,
      updated-by: tx-sender,
      timestamp: stacks-block-time,
    })
    (ok restricted)
  )
)

;; ==============================
;; Key Isolation (ERC-7812 Core Function)
;; ==============================

;; Build isolated key from source (registrar) and original key
;; Following ERC-7812: "isolatedKey = hash(msg.sender, key)"
(define-read-only (get-isolated-key (source principal) (key (buff 32)))
  (keccak256 (concat (unwrap-panic (to-consensus-buff? source)) key))
)

;; ==============================
;; Registrar Management
;; ==============================

;; Authorize a new registrar
(define-public (authorize-registrar (registrar principal) (name (string-utf8 64)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (var-get assets-restricted)) ERR_ASSET_RESTRICTED)
    (map-set authorized-registrars registrar {
      name: name,
      authorized-at: stacks-block-time,
      statement-count: u0,
      active: true,
    })
    (print {
      event: "RegistrarAuthorized",
      registrar: registrar,
      name: name,
      authorized-at: stacks-block-time,
      contract-hash: (contract-hash? registrar),
    })
    (ok true)
  )
)

;; Revoke a registrar's authorization
(define-public (revoke-registrar (registrar principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? authorized-registrars registrar)
      registrar-data
        (begin
          (map-set authorized-registrars registrar (merge registrar-data { active: false }))
          (print {
            event: "RegistrarRevoked",
            registrar: registrar,
            revoked-at: stacks-block-time,
          })
          (ok true)
        )
      ERR_REGISTRAR_NOT_AUTHORIZED
    )
  )
)

;; Check if a principal is an authorized registrar
(define-read-only (is-authorized-registrar (registrar principal))
  (match (map-get? authorized-registrars registrar)
    data (get active data)
    false
  )
)

;; Get registrar information
(define-read-only (get-registrar-info (registrar principal))
  (map-get? authorized-registrars registrar)
)

;; ==============================
;; Evidence Registry Core Functions (ERC-7812)
;; ==============================

;; Private function to update root and emit event
(define-private (update-root (new-root (buff 32)))
  (let (
    (prev-root (var-get current-root))
    (new-version (+ (var-get root-version) u1))
  )
    ;; Store previous root timestamp
    (map-set root-timestamps 
      { root: prev-root }
      { timestamp: stacks-block-time, version: (var-get root-version) }
    )
    ;; Update current root
    (var-set current-root new-root)
    (var-set root-version new-version)
    ;; Emit RootUpdated event (following ERC-7812)
    (print {
      event: "RootUpdated",
      prev-root: prev-root,
      curr-root: new-root,
      version: new-version,
      timestamp: stacks-block-time,
    })
    new-root
  )
)

;; Add a new statement to the Evidence DB
;; Following ERC-7812's addStatement function
(define-public (add-statement (key (buff 32)) (value (buff 32)))
  (let (
    (isolated-key (get-isolated-key tx-sender key))
  )
    ;; Check restrictions
    (asserts! (not (var-get assets-restricted)) ERR_ASSET_RESTRICTED)
    ;; Check if key already exists (ERC-7812 requirement)
    (asserts! (is-none (map-get? evidence-db { isolated-key: isolated-key })) ERR_KEY_ALREADY_EXISTS)
    
    ;; Store the statement
    (map-set evidence-db { isolated-key: isolated-key } {
      value: value,
      registrar: tx-sender,
      created-at: stacks-block-time,
      updated-at: stacks-block-time,
      exists: true,
    })
    
    ;; Update statement count
    (var-set statement-count (+ (var-get statement-count) u1))
    
    ;; Update registrar statement count if authorized
    (match (map-get? authorized-registrars tx-sender)
      registrar-data 
        (map-set authorized-registrars tx-sender 
          (merge registrar-data { statement-count: (+ (get statement-count registrar-data) u1) }))
      true
    )
    
    ;; Compute new root (simplified - in production would use proper Merkle tree)
    (let ((new-root (keccak256 (concat (var-get current-root) (concat isolated-key value)))))
      (update-root new-root)
      
      (print {
        event: "StatementAdded",
        key: key,
        isolated-key: isolated-key,
        registrar: tx-sender,
        timestamp: stacks-block-time,
      })
      
      (ok isolated-key)
    )
  )
)

;; Remove a statement from the Evidence DB
;; Following ERC-7812's removeStatement function
(define-public (remove-statement (key (buff 32)))
  (let (
    (isolated-key (get-isolated-key tx-sender key))
  )
    ;; Check restrictions
    (asserts! (not (var-get assets-restricted)) ERR_ASSET_RESTRICTED)
    
    ;; Check if key exists and belongs to caller
    (match (map-get? evidence-db { isolated-key: isolated-key })
      statement-data
        (begin
          ;; Verify ownership
          (asserts! (is-eq (get registrar statement-data) tx-sender) ERR_UNAUTHORIZED)
          
          ;; Mark as deleted (soft delete for auditability)
          (map-set evidence-db { isolated-key: isolated-key }
            (merge statement-data { exists: false, updated-at: stacks-block-time }))
          
          ;; Update statement count
          (var-set statement-count (- (var-get statement-count) u1))
          
          ;; Compute new root
          (let ((new-root (keccak256 (concat (var-get current-root) isolated-key))))
            (update-root new-root)
            
            (print {
              event: "StatementRemoved",
              key: key,
              isolated-key: isolated-key,
              registrar: tx-sender,
              timestamp: stacks-block-time,
            })
            
            (ok true)
          )
        )
      ERR_KEY_DOES_NOT_EXIST
    )
  )
)

;; Update a statement in the Evidence DB
;; Following ERC-7812's updateStatement function
(define-public (update-statement (key (buff 32)) (new-value (buff 32)))
  (let (
    (isolated-key (get-isolated-key tx-sender key))
  )
    ;; Check restrictions
    (asserts! (not (var-get assets-restricted)) ERR_ASSET_RESTRICTED)
    
    ;; Check if key exists and belongs to caller
    (match (map-get? evidence-db { isolated-key: isolated-key })
      statement-data
        (begin
          ;; Verify ownership and existence
          (asserts! (is-eq (get registrar statement-data) tx-sender) ERR_UNAUTHORIZED)
          (asserts! (get exists statement-data) ERR_KEY_DOES_NOT_EXIST)
          
          ;; Check expiration
          (asserts! (not (is-statement-expired (get created-at statement-data))) ERR_STATEMENT_EXPIRED)
          
          ;; Update the statement
          (map-set evidence-db { isolated-key: isolated-key }
            (merge statement-data { value: new-value, updated-at: stacks-block-time }))
          
          ;; Compute new root
          (let ((new-root (keccak256 (concat (var-get current-root) (concat isolated-key new-value)))))
            (update-root new-root)
            
            (print {
              event: "StatementUpdated",
              key: key,
              isolated-key: isolated-key,
              registrar: tx-sender,
              timestamp: stacks-block-time,
            })
            
            (ok true)
          )
        )
      ERR_KEY_DOES_NOT_EXIST
    )
  )
)

;; ==============================
;; Identity Commitment Functions
;; ==============================

;; Register an identity commitment with secp256r1 signature verification
;; This enables WebAuthn/passkey-based identity registration
(define-public (register-identity-commitment
    (commitment (buff 32))
    (signature (buff 64))
    (public-key (buff 33))
    (commitment-hash (buff 32))
  )
  (begin
    ;; Check restrictions
    (asserts! (not (var-get assets-restricted)) ERR_ASSET_RESTRICTED)
    
    ;; Verify secp256r1 signature using Clarity v4
    (asserts! (secp256r1-verify commitment-hash signature public-key) ERR_INVALID_SIGNATURE)
    
    ;; Store identity commitment
    (map-set identity-commitments tx-sender {
      commitment: commitment,
      created-at: stacks-block-time,
      signature-verified: true,
      public-key: public-key,
    })
    
    ;; Also add as a statement in the evidence db
    (let ((isolated-key (get-isolated-key tx-sender commitment)))
      (map-set evidence-db { isolated-key: isolated-key } {
        value: commitment,
        registrar: tx-sender,
        created-at: stacks-block-time,
        updated-at: stacks-block-time,
        exists: true,
      })
      
      ;; Update root
      (let ((new-root (keccak256 (concat (var-get current-root) (concat isolated-key commitment)))))
        (update-root new-root)
        
        (print {
          event: "IdentityCommitmentRegistered",
          principal: tx-sender,
          commitment: commitment,
          signature-verified: true,
          timestamp: stacks-block-time,
          contract-hash: (get-contract-hash),
        })
        
        (ok isolated-key)
      )
    )
  )
)

;; Get identity commitment for a principal
(define-read-only (get-identity-commitment (user principal))
  (map-get? identity-commitments user)
)

;; Verify identity using stored commitment and signature
(define-read-only (verify-identity 
    (user principal)
    (message-hash (buff 32))
    (signature (buff 64))
  )
  (match (map-get? identity-commitments user)
    commitment-data
      (if (secp256r1-verify message-hash signature (get public-key commitment-data))
        (ok { verified: true, commitment: (get commitment commitment-data) })
        (ok { verified: false, commitment: (get commitment commitment-data) })
      )
    ERR_KEY_DOES_NOT_EXIST
  )
)

;; ==============================
;; Statement with Metadata
;; ==============================

;; Add a statement with metadata including ASCII description
(define-public (add-statement-with-metadata
    (key (buff 32))
    (value (buff 32))
    (statement-type (string-utf8 32))
    (description (string-utf8 256))
  )
  (let (
    (isolated-key (get-isolated-key tx-sender key))
    ;; to-ascii? returns (response string-ascii uint), convert to optional
    (ascii-desc (match (to-ascii? description)
                  success (some success)
                  error none))
  )
    ;; First add the statement
    (try! (add-statement key value))
    
    ;; Then add metadata
    (map-set statement-metadata { isolated-key: isolated-key } {
      statement-type: statement-type,
      description: description,
      ascii-description: ascii-desc,
    })
    
    (print {
      event: "StatementMetadataAdded",
      isolated-key: isolated-key,
      statement-type: statement-type,
      ascii-description: ascii-desc,
      timestamp: stacks-block-time,
    })
    
    (ok isolated-key)
  )
)

;; ==============================
;; Proof Functions (ERC-7812 Pattern)
;; ==============================

;; Store a Merkle proof for a key
(define-public (store-proof
    (key (buff 32))
    (root (buff 32))
    (existence bool)
    (aux-key (optional (buff 32)))
    (aux-value (optional (buff 32)))
  )
  (begin
    ;; Verify the root exists in history or is current
    (asserts! 
      (or 
        (is-eq root (var-get current-root))
        (is-some (map-get? root-timestamps { root: root }))
      )
      ERR_ROOT_NOT_FOUND
    )
    
    (map-set merkle-proofs { key: key } {
      root: root,
      existence: existence,
      aux-key: aux-key,
      aux-value: aux-value,
      verified-at: stacks-block-time,
    })
    
    (print {
      event: "ProofStored",
      key: key,
      root: root,
      existence: existence,
      timestamp: stacks-block-time,
    })
    
    (ok true)
  )
)

;; Get stored proof for a key
(define-read-only (get-proof (key (buff 32)))
  (map-get? merkle-proofs { key: key })
)

;; ==============================
;; Read Functions (ERC-7812 Pattern)
;; ==============================

;; Get current root
(define-read-only (get-root)
  (var-get current-root)
)

;; Get root version
(define-read-only (get-root-version)
  (var-get root-version)
)

;; Get root timestamp - returns 0 for non-existent roots, current time for latest root
;; Following ERC-7812's getRootTimestamp specification
(define-read-only (get-root-timestamp (root (buff 32)))
  (if (is-eq root (var-get current-root))
    stacks-block-time
    (match (map-get? root-timestamps { root: root })
      data (get timestamp data)
      u0
    )
  )
)

;; Get total statement count
(define-read-only (get-statement-count)
  (var-get statement-count)
)

;; Get a statement value by its isolated key
(define-read-only (get-value (isolated-key (buff 32)))
  (match (map-get? evidence-db { isolated-key: isolated-key })
    data 
      (if (get exists data)
        (some (get value data))
        none
      )
    none
  )
)

;; Get full statement data
(define-read-only (get-statement (isolated-key (buff 32)))
  (map-get? evidence-db { isolated-key: isolated-key })
)

;; Get statement by original key and registrar
(define-read-only (get-statement-by-key (registrar principal) (key (buff 32)))
  (get-statement (get-isolated-key registrar key))
)

;; Get statement metadata
(define-read-only (get-metadata (isolated-key (buff 32)))
  (map-get? statement-metadata { isolated-key: isolated-key })
)

;; ==============================
;; Contract Information
;; ==============================

;; Get comprehensive contract information using Clarity v4 features
(define-read-only (get-registry-info)
  {
    contract-hash: (get-contract-hash),
    current-root: (var-get current-root),
    root-version: (var-get root-version),
    statement-count: (var-get statement-count),
    current-block-time: stacks-block-time,
    assets-restricted: (var-get assets-restricted),
    owner: CONTRACT_OWNER,
    expiration-period: STATEMENT_EXPIRATION_PERIOD,
    max-proof-height: MAX_PROOF_HEIGHT,
  }
)

;; Verify contract integrity by checking hash
;; Returns true if expected-hash matches the actual contract hash
(define-read-only (verify-contract-integrity (expected-hash (buff 32)))
  (match (get-contract-hash)
    actual-hash (is-eq expected-hash actual-hash)
    err-code false
  )
)
