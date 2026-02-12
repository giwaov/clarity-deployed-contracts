;; Non-Fungible Token Royalty Standard - ERC-3525 Inspired
;; Implements semi-fungible tokens with slots, values, and royalty mechanisms
;; Using Clarity v4 features

;; Error constants
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-INVALID-VALUE (err u400))
(define-constant ERR-INSUFFICIENT-VALUE (err u402))
(define-constant ERR-SAME-TOKEN (err u403))
(define-constant ERR-INVALID-SLOT (err u405))
(define-constant ERR-RESTRICTED-ASSET (err u406))
(define-constant ERR-INVALID-SIGNATURE (err u407))
(define-constant ERR-CONTRACT-MISMATCH (err u408))

;; Token data structure (ERC-3525 inspired)
(define-non-fungible-token semi-fungible-token uint)

;; Token metadata with slot and value
(define-map token-data
    { token-id: uint }
    {
        slot: uint,
        value: uint,
        owner: principal,
        approved: (optional principal),
        metadata-uri: (optional (string-ascii 256))
    }
)

;; Slot metadata
(define-map slot-data
    { slot: uint }
    {
        name: (string-ascii 64),
        description: (string-ascii 256),
        image-uri: (optional (string-ascii 256)),
        royalty-rate: uint,  ;; Basis points (e.g., 250 = 2.5%)
        royalty-recipient: principal,
        restricted: bool,
        creator: principal,
        created-at: uint
    }
)

;; Value approval for transfers between tokens
(define-map value-approvals
    { owner: principal, token-id: uint, spender: principal }
    { approved-value: uint }
)

;; Contract configuration
(define-data-var contract-owner principal tx-sender)
(define-data-var next-token-id uint u1)
(define-data-var next-slot-id uint u1)
(define-data-var contract-uri (optional (string-ascii 256)) none)
(define-data-var royalty-enabled bool true)

;; Asset restriction configuration
(define-data-var asset-restrictions-enabled bool false)
(define-map restricted-contracts principal bool)

;; Signature verification for secure operations
(define-map verified-operations
    { operation-hash: (buff 32) }
    { verified: bool, timestamp: uint }
)

;; Contract hash verification using Clarity v4
(define-read-only (get-contract-hash (contract principal))
    (contract-hash? contract)
)

;; Asset restriction check using Clarity v4
(define-read-only (check-asset-restrictions (asset-contract principal))
    (if (var-get asset-restrictions-enabled)
        (default-to false (map-get? restricted-contracts asset-contract))
        false
    )
)

;; Create a new slot with royalty information
(define-public (create-slot (name (string-ascii 64))
                           (description (string-ascii 256))
                           (image-uri (optional (string-ascii 256)))
                           (royalty-rate uint)
                           (royalty-recipient principal)
                           (restricted bool))
    (let ((slot-id (var-get next-slot-id)))
        (asserts! (> royalty-rate u0) ERR-INVALID-VALUE)
        (asserts! (<= royalty-rate u10000) ERR-INVALID-VALUE) ;; Max 100%
        (asserts! (not (check-asset-restrictions tx-sender)) ERR-RESTRICTED-ASSET)
        
        (map-set slot-data
            { slot: slot-id }
            {
                name: name,
                description: description,
                image-uri: image-uri,
                royalty-rate: royalty-rate,
                royalty-recipient: royalty-recipient,
                restricted: restricted,
                creator: tx-sender,
                created-at: stacks-block-time
            }
        )
        
        (var-set next-slot-id (+ slot-id u1))
        (ok slot-id)
    )
)

;; Mint a new token in a specific slot with value
(define-public (mint (to principal) (slot uint) (value uint) (metadata-uri (optional (string-ascii 256))))
    (let ((token-id (var-get next-token-id))
          (slot-info (unwrap! (map-get? slot-data { slot: slot }) ERR-NOT-FOUND)))
        (asserts! (> value u0) ERR-INVALID-VALUE)
        (asserts! (not (check-asset-restrictions tx-sender)) ERR-RESTRICTED-ASSET)
        
        ;; Check if slot is restricted and verify permissions
        (if (get restricted slot-info)
            (asserts! (is-eq tx-sender (get creator slot-info)) ERR-UNAUTHORIZED)
            true
        )
        
        (try! (nft-mint? semi-fungible-token token-id to))
        
        (map-set token-data
            { token-id: token-id }
            {
                slot: slot,
                value: value,
                owner: to,
                approved: none,
                metadata-uri: metadata-uri
            }
        )
        
        (var-set next-token-id (+ token-id u1))
        (ok token-id)
    )
)

;; Transfer value between tokens in the same slot
(define-public (transfer-value (from-token-id uint) (to-token-id uint) (value uint))
    (let ((from-token (unwrap! (map-get? token-data { token-id: from-token-id }) ERR-NOT-FOUND))
          (to-token (unwrap! (map-get? token-data { token-id: to-token-id }) ERR-NOT-FOUND)))
        
        (asserts! (not (is-eq from-token-id to-token-id)) ERR-SAME-TOKEN)
        (asserts! (is-eq (get slot from-token) (get slot to-token)) ERR-INVALID-SLOT)
        (asserts! (>= (get value from-token) value) ERR-INSUFFICIENT-VALUE)
        (asserts! (> value u0) ERR-INVALID-VALUE)
        
        ;; Check authorization
        (asserts! (or 
            (is-eq tx-sender (get owner from-token))
            (is-some (get approved from-token))
            (is-authorized-value-transfer from-token-id value)
        ) ERR-UNAUTHORIZED)
        
        ;; Update token values
        (map-set token-data
            { token-id: from-token-id }
            (merge from-token { value: (- (get value from-token) value) })
        )
        
        (map-set token-data
            { token-id: to-token-id }
            (merge to-token { value: (+ (get value to-token) value) })
        )
        
        (ok true)
    )
)

;; Approve value transfer using secp256r1 signature verification
(define-public (approve-value-with-signature (token-id uint) 
                                           (spender principal) 
                                           (approved-value uint)
                                           (signature (buff 64))
                                           (public-key (buff 33)))
    (let ((token (unwrap! (map-get? token-data { token-id: token-id }) ERR-NOT-FOUND))
          (message-hash (sha256 (concat 
            (unwrap-panic (as-max-len? (unwrap-panic (to-consensus-buff? token-id)) u16))
            (unwrap-panic (as-max-len? (unwrap-panic (to-consensus-buff? approved-value)) u16))
          ))))
        
        (asserts! (is-eq tx-sender (get owner token)) ERR-UNAUTHORIZED)
        
        ;; Verify signature using Clarity v4 secp256r1-verify
        (asserts! (secp256r1-verify message-hash signature public-key) ERR-INVALID-SIGNATURE)
        
        ;; Store verified operation
        (map-set verified-operations
            { operation-hash: message-hash }
            { verified: true, timestamp: stacks-block-time }
        )
        
        (map-set value-approvals
            { owner: tx-sender, token-id: token-id, spender: spender }
            { approved-value: approved-value }
        )
        
        (ok true)
    )
)

;; Split a token into two tokens with specified values
(define-public (split-token (token-id uint) (new-value uint))
    (let ((token (unwrap! (map-get? token-data { token-id: token-id }) ERR-NOT-FOUND))
          (new-token-id (var-get next-token-id)))
        
        (asserts! (is-eq tx-sender (get owner token)) ERR-UNAUTHORIZED)
        (asserts! (> new-value u0) ERR-INVALID-VALUE)
        (asserts! (> (get value token) new-value) ERR-INSUFFICIENT-VALUE)
        
        ;; Update original token value
        (map-set token-data
            { token-id: token-id }
            (merge token { value: (- (get value token) new-value) })
        )
        
        ;; Create new token with split value
        (try! (nft-mint? semi-fungible-token new-token-id (get owner token)))
        
        (map-set token-data
            { token-id: new-token-id }
            {
                slot: (get slot token),
                value: new-value,
                owner: (get owner token),
                approved: none,
                metadata-uri: (get metadata-uri token)
            }
        )
        
        (var-set next-token-id (+ new-token-id u1))
        (ok new-token-id)
    )
)

;; Merge two tokens of the same slot
(define-public (merge-tokens (token-id-1 uint) (token-id-2 uint))
    (let ((token1 (unwrap! (map-get? token-data { token-id: token-id-1 }) ERR-NOT-FOUND))
          (token2 (unwrap! (map-get? token-data { token-id: token-id-2 }) ERR-NOT-FOUND)))
        
        (asserts! (is-eq tx-sender (get owner token1)) ERR-UNAUTHORIZED)
        (asserts! (is-eq tx-sender (get owner token2)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get slot token1) (get slot token2)) ERR-INVALID-SLOT)
        (asserts! (not (is-eq token-id-1 token-id-2)) ERR-SAME-TOKEN)
        
        ;; Merge values into token1
        (map-set token-data
            { token-id: token-id-1 }
            (merge token1 { value: (+ (get value token1) (get value token2)) })
        )
        
        ;; Burn token2
        (try! (nft-burn? semi-fungible-token token-id-2 tx-sender))
        (map-delete token-data { token-id: token-id-2 })
        
        (ok token-id-1)
    )
)

;; Calculate royalty for a given value and slot
(define-read-only (calculate-royalty (slot uint) (sale-price uint))
    (match (map-get? slot-data { slot: slot })
        slot-info
        (if (var-get royalty-enabled)
            (let ((royalty-amount (/ (* sale-price (get royalty-rate slot-info)) u10000)))
                (ok {
                    recipient: (get royalty-recipient slot-info),
                    amount: royalty-amount
                })
            )
            (ok { recipient: (var-get contract-owner), amount: u0 })
        )
        ERR-NOT-FOUND
    )
)

;; Contract administration
(define-public (set-contract-uri (uri (optional (string-ascii 256))))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (var-set contract-uri uri)
        (ok true)
    )
)

(define-public (set-asset-restrictions (enabled bool))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (var-set asset-restrictions-enabled enabled)
        (ok true)
    )
)

(define-public (restrict-contract (contract principal) (restricted bool))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (map-set restricted-contracts contract restricted)
        (ok true)
    )
)

;; Helper functions
(define-private (is-authorized-value-transfer (token-id uint) (value uint))
    (match (map-get? value-approvals { owner: tx-sender, token-id: token-id, spender: contract-caller })
        approval (>= (get approved-value approval) value)
        false
    )
)

;; Read-only functions
(define-read-only (get-last-token-id)
    (- (var-get next-token-id) u1)
)

(define-read-only (get-token-uri (token-id uint))
    (match (map-get? token-data { token-id: token-id })
        token (get metadata-uri token)
        none
    )
)

(define-read-only (get-owner (token-id uint))
    (match (map-get? token-data { token-id: token-id })
        token (ok (some (get owner token)))
        (ok none)
    )
)

(define-read-only (get-token-info (token-id uint))
    (map-get? token-data { token-id: token-id })
)

(define-read-only (get-slot-info (slot uint))
    (map-get? slot-data { slot: slot })
)

(define-read-only (get-approved (token-id uint))
    (match (map-get? token-data { token-id: token-id })
        token (get approved token)
        none
    )
)

(define-read-only (value-of (token-id uint))
    (match (map-get? token-data { token-id: token-id })
        token (get value token)
        u0
    )
)

(define-read-only (slot-of (token-id uint))
    (match (map-get? token-data { token-id: token-id })
        token (get slot token)
        u0
    )
)

;; Convert uint to ASCII using Clarity v4
(define-read-only (uint-to-ascii (value uint))
    (to-ascii? value)
)

;; Get current block time using Clarity v4
(define-read-only (get-current-time)
    stacks-block-time
)

;; Transfer function (NFT trait compliance)
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (let ((token (unwrap! (map-get? token-data { token-id: token-id }) ERR-NOT-FOUND)))
        (asserts! (is-eq tx-sender sender) ERR-UNAUTHORIZED)
        (asserts! (is-eq sender (get owner token)) ERR-UNAUTHORIZED)
        
        (try! (nft-transfer? semi-fungible-token token-id sender recipient))
        
        (map-set token-data
            { token-id: token-id }
            (merge token { 
                owner: recipient,
                approved: none
            })
        )
        
        (ok true)
    )
)
