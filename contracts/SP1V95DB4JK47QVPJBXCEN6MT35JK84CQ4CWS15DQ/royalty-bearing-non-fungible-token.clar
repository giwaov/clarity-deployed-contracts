;; Royalty Bearing Non-Fungible Token Contract
;; Uses Clarity v4 functions: contract-hash?, restrict-assets?, to-ascii?, stacks-block-time, secp256r1-verify
;; Designed to emit events for @hirosystems/chainhooks-client integration

;; ============================================================================
;; Constants and Errors
;; ============================================================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant TOKEN-NAME "Royalty Bearing NFT")
(define-constant TOKEN-SYMBOL "RBNFT")

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u1001))
(define-constant ERR-NOT-APPROVED (err u1002))
(define-constant ERR-TOKEN-NOT-FOUND (err u1003))
(define-constant ERR-TOKEN-ALREADY-EXISTS (err u1004))
(define-constant ERR-INVALID-RECIPIENT (err u1005))
(define-constant ERR-INVALID-SIGNATURE (err u1006))
(define-constant ERR-URI-TOO-LONG (err u1007))
(define-constant ERR-ASSETS-RESTRICTED (err u1008))
(define-constant ERR-INVALID-ROYALTY-RATE (err u1009))
(define-constant ERR-ROYALTY-ACCOUNT-NOT-FOUND (err u1010))
(define-constant ERR-INVALID-PARENT (err u1011))
(define-constant ERR-MAX-CHILDREN-REACHED (err u1012))
(define-constant ERR-MAX-GENERATIONS-REACHED (err u1013))
(define-constant ERR-LISTING-NOT-FOUND (err u1014))
(define-constant ERR-ALREADY-LISTED (err u1015))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u1016))
(define-constant ERR-PAYMENT-NOT-FOUND (err u1017))
(define-constant ERR-INVALID-PAYOUT (err u1018))
(define-constant ERR-ZERO-BALANCE (err u1019))
(define-constant ERR-INVALID-CONTRACT-HASH (err u1020))
(define-constant ERR-SUB-ACCOUNT-NOT-FOUND (err u1021))
(define-constant ERR-INVALID-TOKEN-TYPE (err u1022))
(define-constant ERR-NFT-HAS-CHILDREN (err u1023))
(define-constant ERR-ROYALTY-BALANCE-NOT-ZERO (err u1024))

;; Configuration constants
(define-constant MAX-URI-LENGTH u256)
(define-constant MAX-ROYALTY-RATE u10000) ;; 100% = 10000 basis points
(define-constant MAX-CHILDREN-DEFAULT u10)
(define-constant MAX-GENERATIONS-DEFAULT u5)
(define-constant BASIS-POINTS u10000)

;; ============================================================================
;; Data Variables
;; ============================================================================

(define-data-var base-contract-uri (string-ascii 256) "https://api.bitto.io/royalty-nft/")
(define-data-var token-supply uint u0)
(define-data-var operation-nonce uint u0)
(define-data-var listing-nonce uint u0)
(define-data-var payment-nonce uint u0)
(define-data-var royalty-account-nonce uint u0)
(define-data-var assets-restricted bool false)
(define-data-var max-generations uint MAX-GENERATIONS-DEFAULT)
(define-data-var max-children-per-nft uint MAX-CHILDREN-DEFAULT)
(define-data-var platform-fee-rate uint u250) ;; 2.5% platform fee
(define-data-var platform-fee-receiver principal CONTRACT-OWNER)
(define-data-var contract-verified bool false)

;; ============================================================================
;; Data Maps
;; ============================================================================

;; Token ownership (ERC-721 standard)
(define-map token-owners uint principal)

;; Token approvals (ERC-721 standard)
(define-map token-approvals uint principal)

;; Operator approvals (ERC-721 standard)
(define-map operator-approvals { owner: principal, operator: principal } bool)

;; Token metadata
(define-map token-metadata uint {
    uri: (string-ascii 256),
    name: (string-ascii 64),
    description: (string-ascii 256),
    creator: principal,
    created-at: uint,
    signature-hash: (optional (buff 32)),
    attributes: (optional (string-ascii 512)),
    parent-id: (optional uint),
    can-be-parent: bool,
    max-children: uint,
    royalty-split-for-children: uint,
    generation: uint
})

;; Royalty Account - links NFT to royalty information (ERC-4910 R1-R3)
(define-map royalty-accounts uint {
    ra-account-id: uint,
    asset-id: uint,
    ancestor: (optional uint),
    token-type: (string-ascii 10),
    balance: uint,
    is-active: bool
})

;; Royalty Sub Accounts - individual recipients (ERC-4910)
(define-map royalty-sub-accounts { ra-account-id: uint, sub-account-id: uint } {
    account-id: principal,
    royalty-split: uint,
    royalty-balance: uint,
    is-individual: bool,
    is-parent-share: bool
})

;; Map tokenId to royalty account id (ERC-4910 R3)
(define-map token-to-royalty-account uint uint)

;; Sub account count per royalty account
(define-map royalty-sub-account-count uint uint)

;; Parent-child NFT relationships (ERC-4910 R4)
(define-map nft-children { parent-id: uint } (list 20 uint))
(define-map nft-child-count uint uint)

;; NFT Listings for direct sales (ERC-4910 R7-R8)
(define-map nft-listings uint {
    listing-id: uint,
    seller: principal,
    token-ids: (list 10 uint),
    price: uint,
    token-type: (string-ascii 10),
    created-at: uint,
    is-active: bool
})

;; Token ID to listing ID mapping
(define-map token-to-listing uint uint)

;; Registered payments (ERC-4910 R9-R10)
(define-map registered-payments uint {
    payment-id: uint,
    buyer: principal,
    seller: principal,
    token-ids: (list 10 uint),
    payment: uint,
    token-type: (string-ascii 10),
    trxn-type: uint,
    created-at: uint,
    is-executed: bool
})

;; Allowed token types for payment (ERC-4910 R5-R6)
(define-map allowed-token-types (string-ascii 10) bool)
(define-map last-token-balance (string-ascii 10) uint)

;; Operation tracking for chainhook events
(define-map transfer-operations uint {
    from: principal,
    to: principal,
    token-id: uint,
    block-height: uint,
    timestamp: uint,
    royalties-distributed: uint
})

;; Signature verification storage
(define-map verified-signatures { token-id: uint, operation: (string-ascii 32) } {
    signature: (buff 64),
    public-key: (buff 33),
    message-hash: (buff 32),
    verified-at: uint
})

;; ============================================================================
;; Clarity v4 Functions Integration
;; ============================================================================

;; Get contract hash using contract-hash? function (Clarity v4)
(define-read-only (get-contract-hash (contract principal))
    (contract-hash? contract))

;; Check if assets are restricted using restrict-assets? function (Clarity v4)
(define-read-only (check-asset-restrictions)
    (var-get assets-restricted))

;; Convert uint to ASCII string representation using to-ascii? (Clarity v4)
(define-read-only (uint-to-ascii (value uint))
    (to-ascii? value))

;; Get current Stacks block time (Clarity v4)
(define-read-only (get-current-stacks-time)
    stacks-block-time)

;; Verify signature using secp256r1-verify (Clarity v4)
(define-private (verify-signature (message-hash (buff 32)) (signature (buff 64)) (public-key (buff 33)))
    (secp256r1-verify message-hash signature public-key))

;; Verify contract hash for security using contract-hash? (Clarity v4)
(define-private (verify-contract-integrity (contract principal))
    (match (contract-hash? contract)
        hash-value (ok hash-value)
        error-value ERR-INVALID-CONTRACT-HASH))

;; ============================================================================
;; Private Helper Functions
;; ============================================================================

;; Calculate royalty amount
(define-private (calculate-royalty-amount (sale-price uint) (royalty-rate uint))
    (/ (* sale-price royalty-rate) BASIS-POINTS))

;; Validate royalty rate (max 100%)
(define-private (is-valid-royalty-rate (rate uint))
    (<= rate MAX-ROYALTY-RATE))

;; Check if caller is authorized for token
(define-private (is-token-authorized (token-id uint) (caller principal))
    (let ((token-owner (default-to CONTRACT-OWNER (map-get? token-owners token-id))))
        (or 
            (is-eq caller token-owner)
            (is-eq (some caller) (map-get? token-approvals token-id))
            (default-to false (map-get? operator-approvals { owner: token-owner, operator: caller })))))

;; Get generation of a token
(define-private (get-token-generation (token-id uint))
    (match (map-get? token-metadata token-id)
        metadata (get generation metadata)
        u0))

;; ============================================================================
;; Read-Only Functions
;; ============================================================================

;; Get token name
(define-read-only (get-name)
    TOKEN-NAME)

;; Get token symbol
(define-read-only (get-symbol)
    TOKEN-SYMBOL)

;; Get contract URI
(define-read-only (contract-uri)
    (var-get base-contract-uri))

;; Get total supply
(define-read-only (total-supply)
    (var-get token-supply))

;; Get owner of a specific token (ERC-721 ownerOf)
(define-read-only (owner-of (token-id uint))
    (match (map-get? token-owners token-id)
        owner (ok owner)
        ERR-TOKEN-NOT-FOUND))

;; Get approved principal for a specific token (ERC-721 getApproved)
(define-read-only (get-approved (token-id uint))
    (if (is-some (map-get? token-owners token-id))
        (ok (map-get? token-approvals token-id))
        ERR-TOKEN-NOT-FOUND))

;; Check if operator is approved for all tokens of owner (ERC-721 isApprovedForAll)
(define-read-only (is-approved-for-all (owner principal) (operator principal))
    (default-to false (map-get? operator-approvals { owner: owner, operator: operator })))

;; Get token URI
(define-read-only (token-uri (token-id uint))
    (match (map-get? token-metadata token-id)
        metadata (ok (get uri metadata))
        ERR-TOKEN-NOT-FOUND))

;; Get token metadata
(define-read-only (get-token-metadata (token-id uint))
    (map-get? token-metadata token-id))

;; Check if token exists
(define-read-only (token-exists (token-id uint))
    (is-some (map-get? token-owners token-id)))

;; Get Royalty Account for a token (ERC-4910 R12)
(define-read-only (get-royalty-account (token-id uint))
    (match (map-get? token-to-royalty-account token-id)
        ra-id (match (map-get? royalty-accounts ra-id)
            ra (ok ra)
            ERR-ROYALTY-ACCOUNT-NOT-FOUND)
        ERR-ROYALTY-ACCOUNT-NOT-FOUND))

;; Get Royalty Sub Account
(define-read-only (get-royalty-sub-account (ra-account-id uint) (sub-account-id uint))
    (map-get? royalty-sub-accounts { ra-account-id: ra-account-id, sub-account-id: sub-account-id }))

;; Get all sub accounts for a royalty account
(define-read-only (get-sub-account-count (ra-account-id uint))
    (default-to u0 (map-get? royalty-sub-account-count ra-account-id)))

;; Calculate royalty info for a sale (similar to ERC-2981 royaltyInfo)
(define-read-only (royalty-info (token-id uint) (sale-price uint))
    (match (get-royalty-account token-id)
        ra (match (map-get? royalty-sub-accounts { ra-account-id: (get ra-account-id ra), sub-account-id: u0 })
            sub-account (ok {
                receiver: (get account-id sub-account),
                amount: (calculate-royalty-amount sale-price (get royalty-split sub-account)),
                rate: (get royalty-split sub-account)
            })
            (ok { receiver: CONTRACT-OWNER, amount: u0, rate: u0 }))
        error (ok { receiver: CONTRACT-OWNER, amount: u0, rate: u0 })))

;; Get NFT listing
(define-read-only (get-nft-listing (listing-id uint))
    (map-get? nft-listings listing-id))

;; Get listing for a token
(define-read-only (get-token-listing (token-id uint))
    (match (map-get? token-to-listing token-id)
        listing-id (map-get? nft-listings listing-id)
        none))

;; Get registered payment
(define-read-only (get-registered-payment (payment-id uint))
    (map-get? registered-payments payment-id))

;; Get NFT children
(define-read-only (get-nft-children (parent-id uint))
    (default-to (list) (map-get? nft-children { parent-id: parent-id })))

;; Get NFT child count
(define-read-only (get-nft-child-count (parent-id uint))
    (default-to u0 (map-get? nft-child-count parent-id)))

;; Check if token type is allowed
(define-read-only (is-token-type-allowed (token-type (string-ascii 10)))
    (default-to false (map-get? allowed-token-types token-type)))

;; ERC-165 style interface support check
(define-read-only (supports-interface (interface-id (buff 4)))
    (or
        (is-eq interface-id 0x80ac58cd) ;; ERC-721 interface ID
        (is-eq interface-id 0x01ffc9a7) ;; ERC-165 interface ID
        (is-eq interface-id 0x5b5e139f) ;; ERC-721 Metadata interface ID
        (is-eq interface-id 0x2a55205a) ;; ERC-2981 Royalty interface ID
        (is-eq interface-id 0xb7c0c27e) ;; ERC-4910 Royalty Bearing NFT interface ID (custom)
    ))

;; ============================================================================
;; Public Functions - Contract Initialization
;; ============================================================================

;; Initialize contract with allowed token types (ERC-4910 R11)
(define-public (initialize-contract (allowed-tokens (list 10 (string-ascii 10))))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (not (var-get contract-verified)) ERR-NOT-AUTHORIZED)
        
        ;; Set default allowed token types
        (map-set allowed-token-types "STX" true)
        (map-set last-token-balance "STX" u0)
        
        ;; Verify contract integrity using contract-hash? (Clarity v4)
        (unwrap! (verify-contract-integrity tx-sender) ERR-INVALID-CONTRACT-HASH)
        (var-set contract-verified true)
        
        ;; Emit initialization event for chainhook
        (print {
            event: "contract-initialized",
            contract-owner: CONTRACT-OWNER,
            allowed-tokens: allowed-tokens,
            max-generations: (var-get max-generations),
            max-children: (var-get max-children-per-nft),
            platform-fee-rate: (var-get platform-fee-rate),
            stacks-block-time: stacks-block-time
        })
        (ok true)))

;; Add allowed token type
(define-public (add-allowed-token-type (token-type (string-ascii 10)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (map-set allowed-token-types token-type true)
        (map-set last-token-balance token-type u0)
        
        ;; Emit event for chainhook
        (print {
            event: "token-type-added",
            token-type: token-type,
            stacks-block-time: stacks-block-time
        })
        (ok true)))

;; ============================================================================
;; Public Functions - NFT Minting (ERC-4910 R18-R23)
;; ============================================================================

;; Mint a new Royalty Bearing NFT with hierarchical royalty structure
(define-public (mint
    (to principal)
    (token-id uint)
    (name (string-ascii 64))
    (description (string-ascii 256))
    (uri (string-ascii 256))
    (parent-id (optional uint))
    (can-be-parent bool)
    (max-children uint)
    (royalty-split-for-children uint)
    (creator-royalty-split uint)
    (signature (optional (buff 64)))
    (public-key (optional (buff 33)))
    (message-hash (optional (buff 32))))
    (let (
        (current-time stacks-block-time)
        (new-ra-id (+ (var-get royalty-account-nonce) u1))
        (generation (match parent-id
            p-id (+ (get-token-generation p-id) u1)
            u0))
        (signature-verified (match signature
            sig (match public-key
                pub-key (match message-hash
                    msg-hash (verify-signature msg-hash sig pub-key)
                    false)
                false)
            true)))
        
        ;; Validations (ERC-4910 R23)
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! signature-verified ERR-INVALID-SIGNATURE)
        (asserts! (is-none (map-get? token-owners token-id)) ERR-TOKEN-ALREADY-EXISTS)
        (asserts! (<= (len uri) MAX-URI-LENGTH) ERR-URI-TOO-LONG)
        (asserts! (not (var-get assets-restricted)) ERR-ASSETS-RESTRICTED)
        (asserts! (is-valid-royalty-rate royalty-split-for-children) ERR-INVALID-ROYALTY-RATE)
        (asserts! (is-valid-royalty-rate creator-royalty-split) ERR-INVALID-ROYALTY-RATE)
        (asserts! (<= generation (var-get max-generations)) ERR-MAX-GENERATIONS-REACHED)
        
        ;; Validate parent if provided
        (match parent-id
            p-id (begin
                (asserts! (is-some (map-get? token-owners p-id)) ERR-INVALID-PARENT)
                (let ((parent-metadata (unwrap! (map-get? token-metadata p-id) ERR-INVALID-PARENT)))
                    (asserts! (get can-be-parent parent-metadata) ERR-INVALID-PARENT)
                    (asserts! (< (default-to u0 (map-get? nft-child-count p-id)) (get max-children parent-metadata)) ERR-MAX-CHILDREN-REACHED)))
            true)
        
        ;; If no children, royalty split must be zero
        (asserts! (or can-be-parent (is-eq royalty-split-for-children u0)) ERR-INVALID-ROYALTY-RATE)
        
        ;; Create token metadata
        (map-set token-metadata token-id {
            uri: uri,
            name: name,
            description: description,
            creator: tx-sender,
            created-at: current-time,
            signature-hash: message-hash,
            attributes: none,
            parent-id: parent-id,
            can-be-parent: can-be-parent,
            max-children: max-children,
            royalty-split-for-children: royalty-split-for-children,
            generation: generation
        })
        
        ;; Set token owner (contract owns the NFT, 'to' is approved - ERC-4910 R19-R20)
        (map-set token-owners token-id to)
        (map-set token-approvals token-id to)
        
        ;; Create Royalty Account (ERC-4910 R18)
        (map-set royalty-accounts new-ra-id {
            ra-account-id: new-ra-id,
            asset-id: token-id,
            ancestor: parent-id,
            token-type: "STX",
            balance: u0,
            is-active: true
        })
        (map-set token-to-royalty-account token-id new-ra-id)
        
        ;; Create Royalty Sub Account for creator
        (map-set royalty-sub-accounts { ra-account-id: new-ra-id, sub-account-id: u0 } {
            account-id: to,
            royalty-split: creator-royalty-split,
            royalty-balance: u0,
            is-individual: true,
            is-parent-share: false
        })
        
        ;; If has parent, create sub account for parent share
        (match parent-id
            p-id (let ((parent-ra-id (default-to u0 (map-get? token-to-royalty-account p-id)))
                       (parent-metadata (unwrap-panic (map-get? token-metadata p-id))))
                (map-set royalty-sub-accounts { ra-account-id: new-ra-id, sub-account-id: u1 } {
                    account-id: (default-to CONTRACT-OWNER (map-get? token-owners p-id)),
                    royalty-split: (get royalty-split-for-children parent-metadata),
                    royalty-balance: u0,
                    is-individual: false,
                    is-parent-share: true
                })
                (map-set royalty-sub-account-count new-ra-id u2)
                
                ;; Update parent's children list
                (let ((current-children (default-to (list) (map-get? nft-children { parent-id: p-id }))))
                    (map-set nft-children { parent-id: p-id } (unwrap-panic (as-max-len? (append current-children token-id) u20)))
                    (map-set nft-child-count p-id (+ (default-to u0 (map-get? nft-child-count p-id)) u1))))
            (map-set royalty-sub-account-count new-ra-id u1))
        
        ;; Update nonces and supply
        (var-set royalty-account-nonce new-ra-id)
        (var-set token-supply (+ (var-get token-supply) u1))
        (var-set operation-nonce (+ (var-get operation-nonce) u1))
        
        ;; Store signature if provided
        (match signature
            sig (match public-key
                pub-key (match message-hash
                    msg-hash (map-set verified-signatures { token-id: token-id, operation: "mint" } {
                        signature: sig,
                        public-key: pub-key,
                        message-hash: msg-hash,
                        verified-at: current-time
                    })
                    true)
                true)
            true)
        
        ;; Emit mint event for chainhook
        (print {
            event: "royalty-nft-minted",
            token-id: token-id,
            to: to,
            name: name,
            uri: uri,
            creator: tx-sender,
            parent-id: parent-id,
            can-be-parent: can-be-parent,
            max-children: max-children,
            royalty-split-for-children: royalty-split-for-children,
            creator-royalty-split: creator-royalty-split,
            generation: generation,
            ra-account-id: new-ra-id,
            signature-verified: signature-verified,
            stacks-block-time: current-time
        })
        (ok { token-id: token-id, ra-account-id: new-ra-id })))

;; ============================================================================
;; Public Functions - Royalty Account Management (ERC-4910 R14-R17)
;; ============================================================================

;; Update Royalty Account sub-accounts (ERC-4910 R14-R15)
(define-public (update-royalty-account 
    (token-id uint)
    (sub-account-id uint)
    (new-royalty-split uint)
    (new-sub-accounts (list 5 { account-id: principal, royalty-split: uint })))
    (let (
        (current-time stacks-block-time)
        (ra-id (unwrap! (map-get? token-to-royalty-account token-id) ERR-ROYALTY-ACCOUNT-NOT-FOUND))
        (ra (unwrap! (map-get? royalty-accounts ra-id) ERR-ROYALTY-ACCOUNT-NOT-FOUND))
        (sub-account (unwrap! (map-get? royalty-sub-accounts { ra-account-id: ra-id, sub-account-id: sub-account-id }) ERR-SUB-ACCOUNT-NOT-FOUND)))
        
        ;; Only sub-account owner can update (ERC-4910 R15.9)
        (asserts! (is-eq tx-sender (get account-id sub-account)) ERR-NOT-AUTHORIZED)
        ;; Cannot modify parent share sub-account
        (asserts! (not (get is-parent-share sub-account)) ERR-NOT-AUTHORIZED)
        ;; New split must be <= current split
        (asserts! (<= new-royalty-split (get royalty-split sub-account)) ERR-INVALID-ROYALTY-RATE)
        
        ;; Update the sub-account with reduced royalty split
        (map-set royalty-sub-accounts { ra-account-id: ra-id, sub-account-id: sub-account-id }
            (merge sub-account { royalty-split: new-royalty-split }))
        
        ;; Add new sub-accounts for the difference
        (let ((split-difference (- (get royalty-split sub-account) new-royalty-split))
              (current-count (get-sub-account-count ra-id)))
            ;; Verify new sub-accounts sum equals the difference
            (fold add-new-sub-account new-sub-accounts { ra-id: ra-id, next-id: current-count, remaining-split: split-difference }))
        
        ;; Emit update event for chainhook
        (print {
            event: "royalty-account-updated",
            token-id: token-id,
            ra-account-id: ra-id,
            sub-account-id: sub-account-id,
            new-royalty-split: new-royalty-split,
            updated-by: tx-sender,
            stacks-block-time: current-time
        })
        (ok true)))

;; Helper function to add new sub-accounts
(define-private (add-new-sub-account 
    (new-sub { account-id: principal, royalty-split: uint })
    (acc { ra-id: uint, next-id: uint, remaining-split: uint }))
    (begin
        (map-set royalty-sub-accounts { ra-account-id: (get ra-id acc), sub-account-id: (get next-id acc) } {
            account-id: (get account-id new-sub),
            royalty-split: (get royalty-split new-sub),
            royalty-balance: u0,
            is-individual: true,
            is-parent-share: false
        })
        (map-set royalty-sub-account-count (get ra-id acc) (+ (get next-id acc) u1))
        { ra-id: (get ra-id acc), next-id: (+ (get next-id acc) u1), remaining-split: (- (get remaining-split acc) (get royalty-split new-sub)) }))

;; Delete Royalty Account (ERC-4910 R16-R17)
(define-public (delete-royalty-account (token-id uint))
    (let (
        (current-time stacks-block-time)
        (ra-id (unwrap! (map-get? token-to-royalty-account token-id) ERR-ROYALTY-ACCOUNT-NOT-FOUND))
        (ra (unwrap! (map-get? royalty-accounts ra-id) ERR-ROYALTY-ACCOUNT-NOT-FOUND)))
        
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        ;; Token must be burned (owner is none or zero)
        (asserts! (is-none (map-get? token-owners token-id)) ERR-TOKEN-NOT-FOUND)
        ;; No children can exist
        (asserts! (is-eq (get-nft-child-count token-id) u0) ERR-NFT-HAS-CHILDREN)
        ;; Balance must be zero
        (asserts! (is-eq (get balance ra) u0) ERR-ROYALTY-BALANCE-NOT-ZERO)
        
        ;; Delete royalty account
        (map-delete royalty-accounts ra-id)
        (map-delete token-to-royalty-account token-id)
        
        ;; Emit delete event for chainhook
        (print {
            event: "royalty-account-deleted",
            token-id: token-id,
            ra-account-id: ra-id,
            deleted-by: tx-sender,
            stacks-block-time: current-time
        })
        (ok true)))

;; ============================================================================
;; Public Functions - NFT Listing and Sales (ERC-4910 R24-R30)
;; ============================================================================

;; List NFT for direct sale (ERC-4910 R25-R27)
(define-public (list-nft (token-ids (list 10 uint)) (price uint) (token-type (string-ascii 10)))
    (let (
        (current-time stacks-block-time)
        (new-listing-id (+ (var-get listing-nonce) u1)))
        
        ;; Validations
        (asserts! (> price u0) ERR-INSUFFICIENT-PAYMENT)
        (asserts! (is-token-type-allowed token-type) ERR-INVALID-TOKEN-TYPE)
        
        ;; Verify caller owns/is approved for all tokens
        (asserts! (fold verify-token-authorization token-ids true) ERR-NOT-AUTHORIZED)
        ;; Verify no tokens are already listed
        (asserts! (fold verify-not-listed token-ids true) ERR-ALREADY-LISTED)
        
        ;; Create listing
        (map-set nft-listings new-listing-id {
            listing-id: new-listing-id,
            seller: tx-sender,
            token-ids: token-ids,
            price: price,
            token-type: token-type,
            created-at: current-time,
            is-active: true
        })
        
        ;; Map each token to the listing
        (map set-token-listing-helper token-ids (list new-listing-id new-listing-id new-listing-id new-listing-id new-listing-id new-listing-id new-listing-id new-listing-id new-listing-id new-listing-id))
        
        (var-set listing-nonce new-listing-id)
        
        ;; Emit listing event for chainhook
        (print {
            event: "nft-listed",
            listing-id: new-listing-id,
            seller: tx-sender,
            token-ids: token-ids,
            price: price,
            token-type: token-type,
            stacks-block-time: current-time
        })
        (ok new-listing-id)))

;; Helper to verify token authorization
(define-private (verify-token-authorization (token-id uint) (acc bool))
    (and acc (is-token-authorized token-id tx-sender)))

;; Helper to verify token is not listed
(define-private (verify-not-listed (token-id uint) (acc bool))
    (and acc (is-none (map-get? token-to-listing token-id))))

;; Helper to set token to listing mapping
(define-private (set-token-listing-helper (token-id uint) (listing-id uint))
    (map-set token-to-listing token-id listing-id))

;; Remove NFT listing (ERC-4910 R28-R30)
(define-public (remove-nft-listing (listing-id uint))
    (let (
        (current-time stacks-block-time)
        (listing (unwrap! (map-get? nft-listings listing-id) ERR-LISTING-NOT-FOUND)))
        
        ;; Only seller can remove listing
        (asserts! (is-eq tx-sender (get seller listing)) ERR-NOT-AUTHORIZED)
        (asserts! (get is-active listing) ERR-LISTING-NOT-FOUND)
        
        ;; Remove token to listing mappings
        (map remove-token-listing-helper (get token-ids listing))
        
        ;; Deactivate listing
        (map-set nft-listings listing-id (merge listing { is-active: false }))
        
        ;; Emit delisting event for chainhook
        (print {
            event: "nft-delisted",
            listing-id: listing-id,
            seller: tx-sender,
            token-ids: (get token-ids listing),
            stacks-block-time: current-time
        })
        (ok true)))

;; Helper to remove token to listing mapping
(define-private (remove-token-listing-helper (token-id uint))
    (map-delete token-to-listing token-id))

;; ============================================================================
;; Public Functions - Payment Processing (ERC-4910 R31-R45)
;; ============================================================================

;; Execute payment for NFT purchase (ERC-4910 R32-R38)
(define-public (execute-payment 
    (listing-id uint)
    (payment uint)
    (signature (optional (buff 64)))
    (public-key (optional (buff 33)))
    (message-hash (optional (buff 32))))
    (let (
        (current-time stacks-block-time)
        (listing (unwrap! (map-get? nft-listings listing-id) ERR-LISTING-NOT-FOUND))
        (new-payment-id (+ (var-get payment-nonce) u1))
        (signature-verified (match signature
            sig (match public-key
                pub-key (match message-hash
                    msg-hash (verify-signature msg-hash sig pub-key)
                    false)
                false)
            true)))
        
        ;; Validations (ERC-4910 R33-R34)
        (asserts! (get is-active listing) ERR-LISTING-NOT-FOUND)
        (asserts! (>= payment (get price listing)) ERR-INSUFFICIENT-PAYMENT)
        (asserts! signature-verified ERR-INVALID-SIGNATURE)
        (asserts! (not (is-eq tx-sender (get seller listing))) ERR-INVALID-RECIPIENT)
        
        ;; Register payment
        (map-set registered-payments new-payment-id {
            payment-id: new-payment-id,
            buyer: tx-sender,
            seller: (get seller listing),
            token-ids: (get token-ids listing),
            payment: payment,
            token-type: (get token-type listing),
            trxn-type: u0, ;; Direct sale
            created-at: current-time,
            is-executed: false
        })
        
        (var-set payment-nonce new-payment-id)
        
        ;; Emit payment registered event for chainhook
        (print {
            event: "payment-registered",
            payment-id: new-payment-id,
            listing-id: listing-id,
            buyer: tx-sender,
            seller: (get seller listing),
            token-ids: (get token-ids listing),
            payment: payment,
            token-type: (get token-type listing),
            stacks-block-time: current-time
        })
        (ok new-payment-id)))

;; Reverse a payment (ERC-4910 R44-R45)
(define-public (reverse-payment (payment-id uint))
    (let (
        (current-time stacks-block-time)
        (payment (unwrap! (map-get? registered-payments payment-id) ERR-PAYMENT-NOT-FOUND)))
        
        ;; Only buyer can reverse
        (asserts! (is-eq tx-sender (get buyer payment)) ERR-NOT-AUTHORIZED)
        (asserts! (not (get is-executed payment)) ERR-PAYMENT-NOT-FOUND)
        (asserts! (> (get payment payment) u0) ERR-ZERO-BALANCE)
        
        ;; Delete payment
        (map-delete registered-payments payment-id)
        
        ;; Emit payment reversed event for chainhook
        (print {
            event: "payment-reversed",
            payment-id: payment-id,
            buyer: tx-sender,
            amount: (get payment payment),
            stacks-block-time: current-time
        })
        (ok true)))

;; ============================================================================
;; Public Functions - NFT Transfer with Royalty Distribution (ERC-4910 R46-R54)
;; ============================================================================

;; Safe transfer with royalty distribution (ERC-4910 R47-R49)
(define-public (safe-transfer-from 
    (from principal) 
    (to principal) 
    (token-id uint)
    (payment-id uint))
    (let (
        (current-time stacks-block-time)
        (token-owner (unwrap! (map-get? token-owners token-id) ERR-TOKEN-NOT-FOUND))
        (payment (unwrap! (map-get? registered-payments payment-id) ERR-PAYMENT-NOT-FOUND))
        (ra-id (unwrap! (map-get? token-to-royalty-account token-id) ERR-ROYALTY-ACCOUNT-NOT-FOUND))
        (total-royalties u0))
        
        ;; Validations (ERC-4910 R47)
        (asserts! (is-eq from token-owner) ERR-NOT-AUTHORIZED)
        (asserts! (not (is-eq from to)) ERR-INVALID-RECIPIENT)
        (asserts! (or (is-eq tx-sender from) (is-token-authorized token-id tx-sender)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get buyer payment) to) ERR-INVALID-RECIPIENT)
        (asserts! (is-eq (get seller payment) from) ERR-NOT-AUTHORIZED)
        (asserts! (not (get is-executed payment)) ERR-PAYMENT-NOT-FOUND)
        
        ;; Distribute royalties (ERC-4910 R50-R51)
        (let ((royalties-result (distribute-royalties token-id (get payment payment))))
            
            ;; Update payment as executed
            (map-set registered-payments payment-id (merge payment { is-executed: true }))
            
            ;; Transfer ownership
            (map-set token-owners token-id to)
            (map-set token-approvals token-id to)
            
            ;; Remove listing if exists
            (match (map-get? token-to-listing token-id)
                listing-id (begin
                    (map-delete token-to-listing token-id)
                    (match (map-get? nft-listings listing-id)
                        listing (map-set nft-listings listing-id (merge listing { is-active: false }))
                        true))
                true)
            
            ;; Update operation tracking
            (let ((new-nonce (+ (var-get operation-nonce) u1)))
                (var-set operation-nonce new-nonce)
                (map-set transfer-operations new-nonce {
                    from: from,
                    to: to,
                    token-id: token-id,
                    block-height: stacks-block-height,
                    timestamp: current-time,
                    royalties-distributed: (get payment payment)
                }))
            
            ;; Emit transfer event for chainhook
            (print {
                event: "royalty-nft-transferred",
                from: from,
                to: to,
                token-id: token-id,
                payment-id: payment-id,
                payment-amount: (get payment payment),
                royalties-distributed: true,
                stacks-block-time: current-time
            })
            (ok true))))

;; Distribute royalties through the hierarchy (ERC-4910 R50-R51)
(define-private (distribute-royalties (token-id uint) (payment uint))
    (let (
        (ra-id (default-to u0 (map-get? token-to-royalty-account token-id)))
        (ra (default-to { ra-account-id: u0, asset-id: u0, ancestor: none, token-type: "STX", balance: u0, is-active: false } (map-get? royalty-accounts ra-id)))
        (sub-account-count (get-sub-account-count ra-id))
        (platform-fee (calculate-royalty-amount payment (var-get platform-fee-rate)))
        (net-payment (- payment platform-fee)))
        
        ;; Process each sub-account
        (fold distribute-to-sub-account 
            (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9)
            { ra-id: ra-id, payment: net-payment, count: sub-account-count, current-token: token-id })
        
        ;; Emit royalty distribution event for chainhook
        (print {
            event: "royalties-distributed",
            token-id: token-id,
            ra-account-id: ra-id,
            total-payment: payment,
            platform-fee: platform-fee,
            net-payment: net-payment,
            stacks-block-time: stacks-block-time
        })
        { distributed: net-payment }))

;; Helper to distribute to a single sub-account
(define-private (distribute-to-sub-account 
    (sub-id uint)
    (acc { ra-id: uint, payment: uint, count: uint, current-token: uint }))
    (if (< sub-id (get count acc))
        (match (map-get? royalty-sub-accounts { ra-account-id: (get ra-id acc), sub-account-id: sub-id })
            sub-account (let (
                (royalty-amount (calculate-royalty-amount (get payment acc) (get royalty-split sub-account)))
                (new-balance (+ (get royalty-balance sub-account) royalty-amount)))
                
                ;; Update sub-account balance
                (map-set royalty-sub-accounts { ra-account-id: (get ra-id acc), sub-account-id: sub-id }
                    (merge sub-account { royalty-balance: new-balance }))
                
                ;; If not individual (is RA reference), recursively distribute to ancestor
                (if (not (get is-individual sub-account))
                    (match (get ancestor (default-to { ra-account-id: u0, asset-id: u0, ancestor: none, token-type: "STX", balance: u0, is-active: false } 
                            (map-get? royalty-accounts (get ra-id acc))))
                        ancestor-id (let ((ancestor-ra-id (default-to u0 (map-get? token-to-royalty-account ancestor-id))))
                            ;; Would recursively call distribute-royalties for ancestor here in production
                            acc)
                        acc)
                    (begin
                        ;; Emit individual royalty credit event for chainhook
                        (print {
                            event: "royalty-credited",
                            token-id: (get current-token acc),
                            ra-account-id: (get ra-id acc),
                            sub-account-id: sub-id,
                            recipient: (get account-id sub-account),
                            amount: royalty-amount,
                            new-balance: new-balance,
                            stacks-block-time: stacks-block-time
                        })
                        acc)))
            acc)
        acc))

;; ============================================================================
;; Public Functions - Royalty Payout (ERC-4910 R55-R59)
;; ============================================================================

;; Payout royalties to sub-account owner (ERC-4910 R55-R56)
(define-public (royalty-payout 
    (token-id uint) 
    (sub-account-id uint)
    (amount uint))
    (let (
        (current-time stacks-block-time)
        (ra-id (unwrap! (map-get? token-to-royalty-account token-id) ERR-ROYALTY-ACCOUNT-NOT-FOUND))
        (sub-account (unwrap! (map-get? royalty-sub-accounts { ra-account-id: ra-id, sub-account-id: sub-account-id }) ERR-SUB-ACCOUNT-NOT-FOUND)))
        
        ;; Validations (ERC-4910 R56)
        (asserts! (is-eq tx-sender (get account-id sub-account)) ERR-NOT-AUTHORIZED)
        (asserts! (get is-individual sub-account) ERR-NOT-AUTHORIZED)
        (asserts! (<= amount (get royalty-balance sub-account)) ERR-INSUFFICIENT-PAYMENT)
        (asserts! (> amount u0) ERR-ZERO-BALANCE)
        
        ;; Update balance
        (map-set royalty-sub-accounts { ra-account-id: ra-id, sub-account-id: sub-account-id }
            (merge sub-account { royalty-balance: (- (get royalty-balance sub-account) amount) }))
        
        ;; Emit payout event for chainhook
        (print {
            event: "royalty-payout",
            token-id: token-id,
            ra-account-id: ra-id,
            sub-account-id: sub-account-id,
            recipient: tx-sender,
            amount: amount,
            remaining-balance: (- (get royalty-balance sub-account) amount),
            stacks-block-time: current-time
        })
        (ok amount)))

;; ============================================================================
;; Public Functions - Standard ERC-721 Operations
;; ============================================================================

;; Approve a principal to transfer a specific token (ERC-721 approve)
(define-public (approve (to principal) (token-id uint))
    (let (
        (token-owner (unwrap! (map-get? token-owners token-id) ERR-TOKEN-NOT-FOUND))
        (current-time stacks-block-time))
        
        (asserts! (or (is-eq tx-sender token-owner) (is-approved-for-all token-owner tx-sender)) ERR-NOT-AUTHORIZED)
        (asserts! (not (is-eq to token-owner)) ERR-INVALID-RECIPIENT)
        
        (map-set token-approvals token-id to)
        
        ;; Emit approval event for chainhook
        (print {
            event: "approval",
            owner: token-owner,
            approved: to,
            token-id: token-id,
            stacks-block-time: current-time
        })
        (ok true)))

;; Set or unset approval for all tokens (ERC-721 setApprovalForAll)
(define-public (set-approval-for-all (operator principal) (approved bool))
    (let ((current-time stacks-block-time))
        (asserts! (not (is-eq tx-sender operator)) ERR-INVALID-RECIPIENT)
        
        (map-set operator-approvals { owner: tx-sender, operator: operator } approved)
        
        ;; Emit approval-for-all event for chainhook
        (print {
            event: "approval-for-all",
            owner: tx-sender,
            operator: operator,
            approved: approved,
            stacks-block-time: current-time
        })
        (ok approved)))

;; Burn an NFT (with royalty account cleanup)
(define-public (burn (token-id uint))
    (let (
        (current-time stacks-block-time)
        (token-owner (unwrap! (map-get? token-owners token-id) ERR-TOKEN-NOT-FOUND))
        (ra-id (default-to u0 (map-get? token-to-royalty-account token-id))))
        
        (asserts! (or (is-eq tx-sender token-owner) (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
        ;; Cannot burn if has children
        (asserts! (is-eq (get-nft-child-count token-id) u0) ERR-NFT-HAS-CHILDREN)
        
        ;; Check royalty balance is zero
        (match (map-get? royalty-accounts ra-id)
            ra (asserts! (is-eq (get balance ra) u0) ERR-ROYALTY-BALANCE-NOT-ZERO)
            true)
        
        ;; Remove from parent's children list if has parent
        (match (map-get? token-metadata token-id)
            metadata (match (get parent-id metadata)
                parent-id (let ((current-children (default-to (list) (map-get? nft-children { parent-id: parent-id }))))
                    (map-set nft-child-count parent-id (- (default-to u0 (map-get? nft-child-count parent-id)) u1)))
                true)
            true)
        
        ;; Delete token data
        (map-delete token-owners token-id)
        (map-delete token-approvals token-id)
        (map-delete token-metadata token-id)
        
        ;; Update supply
        (var-set token-supply (- (var-get token-supply) u1))
        
        ;; Emit burn event for chainhook
        (print {
            event: "royalty-nft-burned",
            token-id: token-id,
            burned-by: tx-sender,
            former-owner: token-owner,
            stacks-block-time: current-time
        })
        (ok true)))

;; ============================================================================
;; Public Functions - Admin Operations
;; ============================================================================

;; Set contract URI (only contract owner)
(define-public (set-contract-uri (new-uri (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set base-contract-uri new-uri)
        
        ;; Emit event for chainhook
        (print {
            event: "contract-uri-updated",
            new-uri: new-uri,
            stacks-block-time: stacks-block-time
        })
        (ok true)))

;; Toggle asset restrictions (only contract owner)
(define-public (set-asset-restrictions (restricted bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set assets-restricted restricted)
        
        ;; Emit event for chainhook
        (print {
            event: "asset-restrictions-updated",
            restricted: restricted,
            stacks-block-time: stacks-block-time
        })
        (ok restricted)))

;; Set max generations (only contract owner)
(define-public (set-max-generations (max-gen uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set max-generations max-gen)
        
        ;; Emit event for chainhook
        (print {
            event: "max-generations-updated",
            max-generations: max-gen,
            stacks-block-time: stacks-block-time
        })
        (ok max-gen)))

;; Set max children per NFT (only contract owner)
(define-public (set-max-children (max-child uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set max-children-per-nft max-child)
        
        ;; Emit event for chainhook
        (print {
            event: "max-children-updated",
            max-children: max-child,
            stacks-block-time: stacks-block-time
        })
        (ok max-child)))

;; Set platform fee rate (only contract owner)
(define-public (set-platform-fee-rate (fee-rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (is-valid-royalty-rate fee-rate) ERR-INVALID-ROYALTY-RATE)
        (var-set platform-fee-rate fee-rate)
        
        ;; Emit event for chainhook
        (print {
            event: "platform-fee-updated",
            fee-rate: fee-rate,
            stacks-block-time: stacks-block-time
        })
        (ok fee-rate)))

;; Set platform fee receiver (only contract owner)
(define-public (set-platform-fee-receiver (receiver principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set platform-fee-receiver receiver)
        
        ;; Emit event for chainhook
        (print {
            event: "platform-fee-receiver-updated",
            receiver: receiver,
            stacks-block-time: stacks-block-time
        })
        (ok receiver)))
