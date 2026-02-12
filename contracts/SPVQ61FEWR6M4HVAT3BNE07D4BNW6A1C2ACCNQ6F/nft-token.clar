;; NFT Token Contract - SIP-009 Compliant
;; A fully-featured NFT contract with metadata, royalties, and collection management

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-exists (err u102))
(define-constant err-token-not-found (err u103))
(define-constant err-invalid-royalty (err u104))
(define-constant err-unauthorized (err u105))
(define-constant err-invalid-metadata (err u106))

;; Data Variables
(define-data-var last-token-id uint u0)
(define-data-var collection-name (string-ascii 64) "SNFT Collection")
(define-data-var collection-symbol (string-ascii 10) "SNFT")
(define-data-var base-uri (string-ascii 256) "ipfs://")
(define-data-var minting-enabled bool true)

;; Data Maps
(define-map token-owners uint principal)
(define-map token-metadata uint {
    uri: (string-ascii 256),
    creator: principal,
    royalty-percent: uint
})
(define-map token-approvals {token-id: uint, spender: principal} bool)
(define-map operator-approvals {owner: principal, operator: principal} bool)

;; NFT Trait Implementation (SIP-009)
(define-non-fungible-token snft-token uint)

;; Read-only functions

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
    (ok (some (get uri (default-to 
        {uri: "", creator: contract-owner, royalty-percent: u0}
        (map-get? token-metadata token-id)))))
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? snft-token token-id))
)

(define-read-only (get-token-metadata (token-id uint))
    (ok (map-get? token-metadata token-id))
)

(define-read-only (get-token-creator (token-id uint))
    (ok (get creator (default-to 
        {uri: "", creator: contract-owner, royalty-percent: u0}
        (map-get? token-metadata token-id))))
)

(define-read-only (get-token-royalty (token-id uint))
    (ok (get royalty-percent (default-to 
        {uri: "", creator: contract-owner, royalty-percent: u0}
        (map-get? token-metadata token-id))))
)

(define-read-only (get-collection-info)
    (ok {
        name: (var-get collection-name),
        symbol: (var-get collection-symbol),
        base-uri: (var-get base-uri),
        total-supply: (var-get last-token-id)
    })
)

(define-read-only (is-minting-enabled)
    (ok (var-get minting-enabled))
)

(define-read-only (is-approved-spender (token-id uint) (spender principal))
    (ok (default-to false (map-get? token-approvals {token-id: token-id, spender: spender})))
)

(define-read-only (is-approved-operator (owner principal) (operator principal))
    (ok (default-to false (map-get? operator-approvals {owner: owner, operator: operator})))
)

;; Private functions

(define-private (check-token-owner (token-id uint) (sender principal))
    (match (nft-get-owner? snft-token token-id)
        owner (ok (is-eq sender owner))
        (err err-token-not-found)
    )
)

(define-private (is-sender-owner-or-approved (token-id uint) (sender principal))
    (let ((owner (unwrap! (nft-get-owner? snft-token token-id) false)))
        (or 
            (is-eq owner sender)
            (default-to false (map-get? token-approvals {token-id: token-id, spender: sender}))
            (default-to false (map-get? operator-approvals {owner: owner, operator: sender}))
        )
    )
)

;; Public functions

(define-public (mint (recipient principal) (metadata-uri (string-ascii 256)) (royalty-percent uint))
    (let 
        (
            (token-id (+ (var-get last-token-id) u1))
        )
        ;; Validations
        (asserts! (var-get minting-enabled) err-unauthorized)
        (asserts! (> (len metadata-uri) u0) err-invalid-metadata)
        (asserts! (<= royalty-percent u1000) err-invalid-royalty) ;; Max 10% (1000 basis points)
        
        ;; Mint NFT
        (try! (nft-mint? snft-token token-id recipient))
        
        ;; Store metadata
        (map-set token-metadata token-id {
            uri: metadata-uri,
            creator: tx-sender,
            royalty-percent: royalty-percent
        })
        
        ;; Update counter
        (var-set last-token-id token-id)
        
        (print {
            event: "mint",
            token-id: token-id,
            recipient: recipient,
            creator: tx-sender,
            metadata-uri: metadata-uri,
            royalty-percent: royalty-percent
        })
        
        (ok token-id)
    )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        ;; Validations
        (asserts! (is-sender-owner-or-approved token-id tx-sender) err-not-token-owner)
        (asserts! (is-eq sender (unwrap! (nft-get-owner? snft-token token-id) err-token-not-found)) err-not-token-owner)
        
        ;; Clear approvals
        (map-delete token-approvals {token-id: token-id, spender: tx-sender})
        
        ;; Transfer NFT
        (try! (nft-transfer? snft-token token-id sender recipient))
        
        (print {
            event: "transfer",
            token-id: token-id,
            from: sender,
            to: recipient
        })
        
        (ok true)
    )
)

(define-public (approve (token-id uint) (spender principal))
    (let ((owner (unwrap! (nft-get-owner? snft-token token-id) err-token-not-found)))
        (asserts! (is-eq tx-sender owner) err-not-token-owner)
        (map-set token-approvals {token-id: token-id, spender: spender} true)
        
        (print {
            event: "approval",
            token-id: token-id,
            owner: owner,
            spender: spender
        })
        
        (ok true)
    )
)

(define-public (revoke-approval (token-id uint) (spender principal))
    (let ((owner (unwrap! (nft-get-owner? snft-token token-id) err-token-not-found)))
        (asserts! (is-eq tx-sender owner) err-not-token-owner)
        (map-delete token-approvals {token-id: token-id, spender: spender})
        
        (print {
            event: "approval-revoked",
            token-id: token-id,
            owner: owner,
            spender: spender
        })
        
        (ok true)
    )
)

(define-public (set-approved-operator (operator principal) (approved bool))
    (begin
        (if approved
            (map-set operator-approvals {owner: tx-sender, operator: operator} true)
            (map-delete operator-approvals {owner: tx-sender, operator: operator})
        )
        
        (print {
            event: "operator-approval",
            owner: tx-sender,
            operator: operator,
            approved: approved
        })
        
        (ok true)
    )
)

;; Admin functions

(define-public (set-base-uri (new-base-uri (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set base-uri new-base-uri)
        (ok true)
    )
)

(define-public (set-collection-name (new-name (string-ascii 64)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set collection-name new-name)
        (ok true)
    )
)

(define-public (toggle-minting)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set minting-enabled (not (var-get minting-enabled)))
        (ok (var-get minting-enabled))
    )
)

(define-public (burn (token-id uint))
    (let ((owner (unwrap! (nft-get-owner? snft-token token-id) err-token-not-found)))
        (asserts! (is-eq tx-sender owner) err-not-token-owner)
        
        ;; Clean up metadata
        (map-delete token-metadata token-id)
        
        ;; Burn NFT
        (try! (nft-burn? snft-token token-id owner))
        
        (print {
            event: "burn",
            token-id: token-id,
            owner: owner
        })
        
        (ok true)
    )
)
