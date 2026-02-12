;; Notary Contract-inspired by ERC-5289 in the form of the Stacks Implementation
;; Reference: ERC-5289 Ethereum Notary Interface (https://eips.ethereum.org/EIPS/eip-5289)
;; 
;; This contract allows smart contracts to be legally binding by providing
;; IPFS links to legal documents and ensuring users have privity with the relevant
;; legal documents through cryptographic signatures.
;;
;; Clarity v4 Features Used:
;; - contract-hash?: Get the hash of a contract for verification
;; - restrict-assets?: Check if asset restrictions apply
;; - to-ascii?: Convert string-utf8 to string-ascii
;; - stacks-block-time: Get the current Stacks block time
;; - secp256r1-verify: Verify secp256r1 signatures (P-256/WebAuthn compatible)

;; ========================================
;; Constants
;; ========================================

(define-constant CONTRACT_OWNER tx-sender)

;; Error codes
(define-constant ERR_NOT_AUTHORIZED (err u1001))
(define-constant ERR_DOCUMENT_NOT_FOUND (err u1002))
(define-constant ERR_ALREADY_SIGNED (err u1003))
(define-constant ERR_NOT_SIGNED (err u1004))
(define-constant ERR_INVALID_DOCUMENT_ID (err u1005))
(define-constant ERR_INVALID_SIGNATURE (err u1006))
(define-constant ERR_DOCUMENT_INACTIVE (err u1007))
(define-constant ERR_ASSET_RESTRICTION (err u1008))
(define-constant ERR_CONVERSION_FAILED (err u1009))
(define-constant ERR_DOCUMENT_EXISTS (err u1010))
(define-constant ERR_SIGNATURE_REQUIRED (err u1011))

;; ========================================
;; Data Variables
;; ========================================

;; Counter for total documents registered
(define-data-var document-count uint u0)

;; Toggle for asset restrictions (using Clarity v4 concept)
(define-data-var assets-restricted bool false)

;; ========================================
;; Data Maps
;; ========================================

;; Legal documents registry
;; Maps document ID to document metadata
(define-map legal-documents
  uint
  {
    ;; IPFS link to the legal document (e.g., "ipfs://Qm...")
    document-uri: (string-utf8 256),
    ;; Title of the document
    title: (string-utf8 128),
    ;; Document version for tracking updates
    version: uint,
    ;; Document creator/owner
    creator: principal,
    ;; When the document was registered (using stacks-block-time)
    created-at: uint,
    ;; Whether the document is active for signing
    is-active: bool,
    ;; Hash of the document content for integrity verification
    content-hash: (buff 32),
    ;; Contract hash at the time of creation (Clarity v4)
    contract-hash-at-creation: (optional (buff 32)),
  }
)

;; Tracks which users have signed which documents
(define-map document-signatures
  { user: principal, document-id: uint }
  {
    ;; When the document was signed (using stacks-block-time)
    signed-at: uint,
    ;; The signature (secp256r1 compatible)
    signature: (buff 64),
    ;; Public key used for signing
    public-key: (buff 33),
    ;; Stacks block height at signing
    block-height: uint,
  }
)

;; Map to track signature count per document
(define-map document-signature-count
  uint
  uint
)

;; Map to track which contracts require which documents
(define-map required-documents
  principal  ;; contract address
  (list 10 uint)  ;; list of required document IDs
)

;; ========================================
;; Events (using print)
;; ========================================

;; Event: Document Registered
(define-private (emit-document-registered (document-id uint) (creator principal) (document-uri (string-utf8 256)))
  (print {
    event: "DocumentRegistered",
    document-id: document-id,
    creator: creator,
    document-uri: document-uri,
    timestamp: stacks-block-time,
  })
)

;; Event: Document Signed
(define-private (emit-document-signed (signer principal) (document-id uint))
  (print {
    event: "DocumentSigned",
    signer: signer,
    document-id: document-id,
    timestamp: stacks-block-time,
    block-height: stacks-block-height,
  })
)

;; ========================================
;; Read-Only Functions
;; ========================================

;; Get the legal document URI by document ID
;; Equivalent to ERC-5289's legalDocument function
(define-read-only (get-legal-document (document-id uint))
  (match (map-get? legal-documents document-id)
    doc (ok (get document-uri doc))
    ERR_DOCUMENT_NOT_FOUND
  )
)

;; Get full document details
(define-read-only (get-document-details (document-id uint))
  (map-get? legal-documents document-id)
)

;; Check if a user has signed a document
;; Equivalent to ERC-5289's documentSigned function
(define-read-only (document-signed (user principal) (document-id uint))
  (is-some (map-get? document-signatures { user: user, document-id: document-id }))
)

;; Get when a user signed a document
;; Equivalent to ERC-5289's documentSignedAt function
(define-read-only (document-signed-at (user principal) (document-id uint))
  (match (map-get? document-signatures { user: user, document-id: document-id })
    sig-data (ok (get signed-at sig-data))
    ERR_NOT_SIGNED
  )
)

;; Get the signature details for a document
(define-read-only (get-signature-details (user principal) (document-id uint))
  (map-get? document-signatures { user: user, document-id: document-id })
)

;; Get total document count
(define-read-only (get-document-count)
  (var-get document-count)
)

;; Get signature count for a document
(define-read-only (get-document-signature-count (document-id uint))
  (default-to u0 (map-get? document-signature-count document-id))
)

;; Get document title as ASCII (using Clarity v4 to-ascii?)
(define-read-only (get-document-title-ascii (document-id uint))
  (match (map-get? legal-documents document-id)
    doc (ok (unwrap-panic (to-ascii? (get title doc))))
    ERR_DOCUMENT_NOT_FOUND
  )
)

;; Get document URI as ASCII (using Clarity v4 to-ascii?)
(define-read-only (get-document-uri-ascii (document-id uint))
  (match (map-get? legal-documents document-id)
    doc (ok (unwrap-panic (to-ascii? (get document-uri doc))))
    ERR_DOCUMENT_NOT_FOUND
  )
)

;; Get current Stacks block time (Clarity v4)
(define-read-only (get-current-time)
  stacks-block-time
)

;; Get contract hash (Clarity v4)
(define-read-only (get-contract-hash)
  (contract-hash? tx-sender)
)

;; Get contract hash for a specific principal
(define-read-only (get-principal-contract-hash (target principal))
  (contract-hash? target)
)

;; Check if assets are restricted
(define-read-only (are-assets-restricted)
  (var-get assets-restricted)
)

;; Verify a secp256r1 signature (Clarity v4)
;; This allows verification of WebAuthn/FIDO2 compatible signatures
(define-read-only (verify-signature 
    (message-hash (buff 32)) 
    (signature (buff 64)) 
    (public-key (buff 33))
  )
  (secp256r1-verify message-hash signature public-key)
)

;; Check if a user has signed all required documents for a contract
(define-read-only (has-signed-required-documents (user principal) (contract-principal principal))
  (match (map-get? required-documents contract-principal)
    doc-list (fold check-document-signed doc-list { user: user, all-signed: true })
    { user: user, all-signed: true }
  )
)

;; Helper function to check if a document is signed
(define-private (check-document-signed (doc-id uint) (acc { user: principal, all-signed: bool }))
  (if (get all-signed acc)
    { 
      user: (get user acc), 
      all-signed: (document-signed (get user acc) doc-id) 
    }
    acc
  )
)

;; Get notary contract info
(define-read-only (get-notary-info)
  {
    contract-hash: (get-contract-hash),
    owner: CONTRACT_OWNER,
    document-count: (var-get document-count),
    assets-restricted: (var-get assets-restricted),
    current-time: stacks-block-time,
    block-height: stacks-block-height,
  }
)

;; ========================================
;; Public Functions
;; ========================================

;; Register a new legal document
(define-public (register-document 
    (document-uri (string-utf8 256))
    (title (string-utf8 128))
    (content-hash (buff 32))
  )
  (let (
    (new-id (+ (var-get document-count) u1))
  )
    ;; Check asset restrictions
    (asserts! (not (var-get assets-restricted)) ERR_ASSET_RESTRICTION)
    
    ;; Create the document entry
    (map-set legal-documents new-id {
      document-uri: document-uri,
      title: title,
      version: u1,
      creator: tx-sender,
      created-at: stacks-block-time,
      is-active: true,
      content-hash: content-hash,
      contract-hash-at-creation: (match (get-contract-hash) hash (some hash) err-val none),
    })
    
    ;; Initialize signature count
    (map-set document-signature-count new-id u0)
    
    ;; Update document counter
    (var-set document-count new-id)
    
    ;; Emit event
    (emit-document-registered new-id tx-sender document-uri)
    
    (ok new-id)
  )
)

;; Sign a document (basic version)
;; Equivalent to ERC-5289's signDocument function
(define-public (sign-document (document-id uint))
  (let (
    (doc (unwrap! (map-get? legal-documents document-id) ERR_DOCUMENT_NOT_FOUND))
  )
    ;; Check asset restrictions
    (asserts! (not (var-get assets-restricted)) ERR_ASSET_RESTRICTION)
    ;; Check document is active
    (asserts! (get is-active doc) ERR_DOCUMENT_INACTIVE)
    ;; Check not already signed
    (asserts! (not (document-signed tx-sender document-id)) ERR_ALREADY_SIGNED)
    
    ;; Record the signature (without cryptographic signature)
    (map-set document-signatures 
      { user: tx-sender, document-id: document-id }
      {
        signed-at: stacks-block-time,
        signature: 0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000,
        public-key: 0x000000000000000000000000000000000000000000000000000000000000000000,
        block-height: stacks-block-height,
      }
    )
    
    ;; Increment signature count
    (map-set document-signature-count 
      document-id 
      (+ (get-document-signature-count document-id) u1)
    )
    
    ;; Emit event
    (emit-document-signed tx-sender document-id)
    
    (ok true)
  )
)

;; Sign a document with secp256r1 signature verification (Clarity v4)
;; This is useful for WebAuthn/FIDO2/Passkey authentication
(define-public (sign-document-with-signature
    (document-id uint)
    (signature (buff 64))
    (public-key (buff 33))
    (message-hash (buff 32))
  )
  (let (
    (doc (unwrap! (map-get? legal-documents document-id) ERR_DOCUMENT_NOT_FOUND))
  )
    ;; Check asset restrictions
    (asserts! (not (var-get assets-restricted)) ERR_ASSET_RESTRICTION)
    ;; Check document is active
    (asserts! (get is-active doc) ERR_DOCUMENT_INACTIVE)
    ;; Check not already signed
    (asserts! (not (document-signed tx-sender document-id)) ERR_ALREADY_SIGNED)
    ;; Verify secp256r1 signature (Clarity v4)
    (asserts! (secp256r1-verify message-hash signature public-key) ERR_INVALID_SIGNATURE)
    
    ;; Record the signature with cryptographic proof
    (map-set document-signatures 
      { user: tx-sender, document-id: document-id }
      {
        signed-at: stacks-block-time,
        signature: signature,
        public-key: public-key,
        block-height: stacks-block-height,
      }
    )
    
    ;; Increment signature count
    (map-set document-signature-count 
      document-id 
      (+ (get-document-signature-count document-id) u1)
    )
    
    ;; Emit event
    (emit-document-signed tx-sender document-id)
    
    (ok true)
  )
)

;; Deactivate a document (only creator can do this)
(define-public (deactivate-document (document-id uint))
  (let (
    (doc (unwrap! (map-get? legal-documents document-id) ERR_DOCUMENT_NOT_FOUND))
  )
    ;; Only creator can deactivate
    (asserts! (is-eq tx-sender (get creator doc)) ERR_NOT_AUTHORIZED)
    
    ;; Update document status
    (map-set legal-documents document-id (merge doc { is-active: false }))
    
    (print {
      event: "DocumentDeactivated",
      document-id: document-id,
      deactivated-by: tx-sender,
      timestamp: stacks-block-time,
    })
    
    (ok true)
  )
)

;; Reactivate a document (only creator can do this)
(define-public (reactivate-document (document-id uint))
  (let (
    (doc (unwrap! (map-get? legal-documents document-id) ERR_DOCUMENT_NOT_FOUND))
  )
    ;; Only creator can reactivate
    (asserts! (is-eq tx-sender (get creator doc)) ERR_NOT_AUTHORIZED)
    
    ;; Update document status
    (map-set legal-documents document-id (merge doc { is-active: true }))
    
    (print {
      event: "DocumentReactivated",
      document-id: document-id,
      reactivated-by: tx-sender,
      timestamp: stacks-block-time,
    })
    
    (ok true)
  )
)

;; Update document version (creates new version, keeps history through events)
(define-public (update-document 
    (document-id uint)
    (new-document-uri (string-utf8 256))
    (new-content-hash (buff 32))
  )
  (let (
    (doc (unwrap! (map-get? legal-documents document-id) ERR_DOCUMENT_NOT_FOUND))
    (new-version (+ (get version doc) u1))
  )
    ;; Only creator can update
    (asserts! (is-eq tx-sender (get creator doc)) ERR_NOT_AUTHORIZED)
    ;; Check asset restrictions
    (asserts! (not (var-get assets-restricted)) ERR_ASSET_RESTRICTION)
    
    ;; Update the document with new version
    (map-set legal-documents document-id 
      (merge doc {
        document-uri: new-document-uri,
        version: new-version,
        content-hash: new-content-hash,
      })
    )
    
    (print {
      event: "DocumentUpdated",
      document-id: document-id,
      new-version: new-version,
      new-uri: new-document-uri,
      updated-by: tx-sender,
      timestamp: stacks-block-time,
    })
    
    (ok new-version)
  )
)

;; Set required documents for a contract (only contract owner can do this)
(define-public (set-required-documents (contract-principal principal) (document-ids (list 10 uint)))
  (begin
    ;; Only contract owner can set required documents
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    (map-set required-documents contract-principal document-ids)
    
    (print {
      event: "RequiredDocumentsSet",
      contract: contract-principal,
      document-ids: document-ids,
      set-by: tx-sender,
      timestamp: stacks-block-time,
    })
    
    (ok true)
  )
)

;; Toggle asset restrictions (owner only)
(define-public (set-asset-restrictions (restricted bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
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

;; ========================================
;; Require Signature Helper
;; ========================================

;; Function that other contracts can call to require document signing
;; This is similar to ERC-5289's signal mechanism
(define-public (require-document-signed (user principal) (document-id uint))
  (begin
    ;; Check if document exists
    (asserts! (is-some (map-get? legal-documents document-id)) ERR_DOCUMENT_NOT_FOUND)
    ;; Check if user has signed
    (asserts! (document-signed user document-id) ERR_SIGNATURE_REQUIRED)
    (ok true)
  )
)

;; Batch check if user has signed all specified documents
(define-public (require-documents-signed (user principal) (document-ids (list 10 uint)))
  (let ((result (fold require-document-signed-fold document-ids { user: user, result: (ok true) })))
    (get result result)
  )
)

;; Helper for batch checking
(define-private (require-document-signed-fold (doc-id uint) (acc { user: principal, result: (response bool uint) }))
  (match (get result acc)
    success-val 
      (if (document-signed (get user acc) doc-id)
        acc
        { user: (get user acc), result: ERR_SIGNATURE_REQUIRED }
      )
    err-val acc
  )
)

;; ========================================
;; Verification Functions
;; ========================================

;; Verify document integrity by comparing content hash
(define-read-only (verify-document-integrity (document-id uint) (expected-hash (buff 32)))
  (match (map-get? legal-documents document-id)
    doc (is-eq (get content-hash doc) expected-hash)
    false
  )
)

;; Verify a signature for a specific document and user
(define-read-only (verify-document-signature 
    (user principal) 
    (document-id uint) 
    (message-hash (buff 32))
  )
  (match (map-get? document-signatures { user: user, document-id: document-id })
    sig-data 
      (let (
        (sig (get signature sig-data))
        (pub-key (get public-key sig-data))
      )
        ;; If signature is all zeros, it was signed without cryptographic proof
        (if (is-eq sig 0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000)
          false
          (secp256r1-verify message-hash sig pub-key)
        )
      )
    false
  )
)
