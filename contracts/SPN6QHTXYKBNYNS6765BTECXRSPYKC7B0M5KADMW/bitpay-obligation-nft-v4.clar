;; bitpay-obligation-nft
;; Obligation NFT - Tokenizes payment obligations for senders (transferable)
;; This allows senders to sell/transfer their payment obligations (invoice factoring)

;; Implement SIP-009 NFT trait
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Define the NFT
(define-non-fungible-token obligation-nft uint)

;; Data vars
(define-data-var last-token-id uint u0)
(define-data-var base-token-uri (string-ascii 256) "")

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_OWNER_ONLY (err u500))
(define-constant ERR_NOT_TOKEN_OWNER (err u501))
(define-constant ERR_TOKEN_NOT_FOUND (err u502))
(define-constant ERR_UNAUTHORIZED (err u503))
(define-constant ERR_STREAM_CANCELLED (err u504))

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
    (ok (nft-get-owner? obligation-nft token-id))
)

;; Transfer obligation NFT
;; NOTE: After transferring, the new owner must call bitpay-core.update-stream-sender
;; to sync the stream sender with the new NFT owner
;; @param token-id: ID of the token to transfer
;; @param sender: Current owner
;; @param recipient: New owner
;; @returns: (ok true) on success
;; #[allow(unchecked_data)]
(define-public (transfer
        (token-id uint)
        (sender principal)
        (recipient principal)
    )
    (let ((stream-id (unwrap! (map-get? token-to-stream token-id) ERR_TOKEN_NOT_FOUND)))
        (begin
            ;; Verify sender owns the NFT
            (asserts! (is-eq tx-sender sender) ERR_NOT_TOKEN_OWNER)

            ;; Transfer the NFT
            (try! (nft-transfer? obligation-nft token-id sender recipient))

            (print {
                event: "obligation-transferred",
                stream-id: stream-id,
                token-id: token-id,
                from: sender,
                to: recipient,
                note: "New owner must call update-stream-sender to complete transfer",
            })

            (ok true)
        )
    )
)

;; Custom functions for obligation NFT integration

;; Mint obligation NFT for a stream (called by bitpay-core)
;; SECURITY: Only bitpay-core can mint NFTs to prevent fake obligation NFTs
;; @param stream-id: ID of the stream to link
;; @param sender: Principal to receive the obligation NFT
;; @returns: (ok token-id) on success
;; #[allow(unchecked_data)]
(define-public (mint
        (stream-id uint)
        (sender principal)
    )
    (let ((token-id (+ (var-get last-token-id) u1)))
        ;; Only bitpay-core contract can mint obligation NFTs
        (asserts! (is-eq contract-caller .bitpay-core-v4) ERR_UNAUTHORIZED)

        (try! (nft-mint? obligation-nft token-id sender))
        (var-set last-token-id token-id)
        (map-set token-to-stream token-id stream-id)
        (map-set stream-to-token stream-id token-id)

        (print {
            event: "obligation-minted",
            stream-id: stream-id,
            token-id: token-id,
            owner: sender,
        })

        (ok token-id)
    )
)

;; Burn obligation NFT when stream is cancelled or fully paid
;; @param token-id: ID of the token to burn
;; @param owner: Current owner of the token
;; @returns: (ok true) on success
;; #[allow(unchecked_data)]
(define-public (burn
        (token-id uint)
        (owner principal)
    )
    (begin
        (asserts!
            (is-eq (some tx-sender) (nft-get-owner? obligation-nft token-id))
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
        (nft-burn? obligation-nft token-id owner)
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
