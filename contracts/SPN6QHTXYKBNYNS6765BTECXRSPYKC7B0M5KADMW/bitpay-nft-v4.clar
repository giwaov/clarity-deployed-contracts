;; bitpay-nft
;; Stream NFT - Tokenizes payment streams following SIP-009 NFT standard

;; Implement SIP-009 NFT trait
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Define the NFT
(define-non-fungible-token stream-nft uint)

;; Data vars
(define-data-var last-token-id uint u0)
(define-data-var base-token-uri (string-ascii 256) "")

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_OWNER_ONLY (err u400))
(define-constant ERR_NOT_TOKEN_OWNER (err u401))
(define-constant ERR_TOKEN_NOT_FOUND (err u402))
(define-constant ERR_UNAUTHORIZED (err u403))

;; Map token ID to stream ID
(define-map token-to-stream
    uint
    uint
)

;; Map stream ID to token ID
(define-map stream-to-token
    uint
    uint
)

;; SIP-009 required functions

;; Get the last minted token ID
;; @returns: (ok last-token-id)
(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

;; Get the token URI for metadata
;; @param token-id: ID of the token
;; @returns: (ok optional-uri)
(define-read-only (get-token-uri (token-id uint))
    (if (> (len (var-get base-token-uri)) u0)
        (ok (some (var-get base-token-uri)))
        (ok none)
    )
)

;; Get the owner of a token
;; @param token-id: ID of the token
;; @returns: (ok optional-owner)
(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? stream-nft token-id))
)

;; Transfer is DISABLED - Recipient NFTs are soul-bound (non-transferable)
;; They serve as proof of receipt and cannot be traded
;; @param token-id: ID of the token
;; @param sender: Current owner
;; @param recipient: Intended recipient
;; @returns: Always returns ERR_UNAUTHORIZED (transfers disabled)
;; #[allow(unchecked_data)]
(define-public (transfer
        (token-id uint)
        (sender principal)
        (recipient principal)
    )
    ;; Soul-bound: recipient NFTs cannot be transferred
    ERR_UNAUTHORIZED
)

;; Custom functions for stream NFT integration

;; Mint NFT for a stream (called by bitpay-core)
;; SECURITY: Only bitpay-core can mint NFTs to prevent fake stream NFTs
;; @param stream-id: ID of the stream to link
;; @param recipient: Principal to receive the NFT
;; @returns: (ok token-id) on success
;; #[allow(unchecked_data)]
(define-public (mint
        (stream-id uint)
        (recipient principal)
    )
    (let ((token-id (+ (var-get last-token-id) u1)))
        ;; Only bitpay-core contract can mint stream NFTs
        (asserts! (is-eq contract-caller .bitpay-core-v4) ERR_UNAUTHORIZED)

        (try! (nft-mint? stream-nft token-id recipient))
        (var-set last-token-id token-id)
        (map-set token-to-stream token-id stream-id)
        (map-set stream-to-token stream-id token-id)
        (ok token-id)
    )
)

;; Burn NFT when stream is fully withdrawn or cancelled
;; @param token-id: ID of the token to burn
;; @param owner: Current owner of the token
;; @returns: (ok true) on success
;; #[allow(unchecked_data)]
(define-public (burn
        (token-id uint)
        (owner principal)
    )
    (begin
        (asserts! (is-eq (some tx-sender) (nft-get-owner? stream-nft token-id))
            ERR_NOT_TOKEN_OWNER
        )
        ;; Get stream ID before deleting the mapping
        (match (map-get? token-to-stream token-id)
            stream-id (begin
                (map-delete token-to-stream token-id)
                (map-delete stream-to-token stream-id)
            )
            true
        )
        (nft-burn? stream-nft token-id owner)
    )
)

;; Get stream ID from token ID
;; @param token-id: ID of the token
;; @returns: (ok optional-stream-id)
(define-read-only (get-stream-id (token-id uint))
    (ok (map-get? token-to-stream token-id))
)

;; Get token ID from stream ID
;; @param stream-id: ID of the stream
;; @returns: (ok optional-token-id)
(define-read-only (get-token-id (stream-id uint))
    (ok (map-get? stream-to-token stream-id))
)

;; Set base token URI (owner only)
;; @param uri: Base URI for token metadata
;; @returns: (ok true) on success
;; #[allow(unchecked_data)]
(define-public (set-base-token-uri (uri (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
        (var-set base-token-uri uri)
        (ok true)
    )
)
