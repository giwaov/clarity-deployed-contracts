;; Simple NFT Mint Contract
;; Allows users to mint NFTs with metadata
;; clarity-version: 3

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-MAX-SUPPLY-REACHED (err u410))
(define-constant ERR-INSUFFICIENT-FUNDS (err u411))
(define-constant ERR-INVALID-INPUT (err u413))

;; NFT definition
(define-non-fungible-token BitcoinStamp uint)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant MAX-SUPPLY u10000)
(define-constant MINT-PRICE u1000000) ;; 1 STX (1,000,000 micro-STX)

;; Data variables
(define-data-var last-token-id uint u0)
(define-data-var mint-enabled bool true)
(define-data-var base-uri (string-ascii 256) "ipfs://")

;; Data maps
(define-map token-metadata
    uint
    {
        name: (string-ascii 256),
        uri: (string-ascii 256),
        minted-at: uint,
    }
)

;; Private functions

;; Get next token ID and increment
(define-private (get-next-token-id)
    (let (
            (current-id (var-get last-token-id))
            (next-id (+ current-id u1))
        )
        (asserts! (<= next-id MAX-SUPPLY) ERR-MAX-SUPPLY-REACHED)
        (var-set last-token-id next-id)
        (ok next-id)
    )
)

;; Public functions

;; Mint NFT with metadata (paid)
(define-public (mint
        (name (string-ascii 256))
        (uri (string-ascii 256))
    )
    (let (
            (token-id (unwrap! (get-next-token-id) ERR-MAX-SUPPLY-REACHED))
            (minter tx-sender)
        )
        ;; Validate inputs
        (asserts! (> (len name) u0) ERR-INVALID-INPUT)
        (asserts! (> (len uri) u0) ERR-INVALID-INPUT)

        ;; Check if minting is enabled
        (asserts! (var-get mint-enabled) ERR-NOT-AUTHORIZED)

        ;; Transfer STX from minter to contract owner
        (unwrap! (stx-transfer? MINT-PRICE minter contract-owner)
            ERR-INSUFFICIENT-FUNDS
        )

        ;; Mint the NFT
        (unwrap! (nft-mint? BitcoinStamp token-id minter) ERR-ALREADY-EXISTS)

        ;; Store metadata
        (map-set token-metadata token-id {
            name: name,
            uri: uri,
            minted-at: stacks-block-height,
        })

        (ok token-id)
    )
)

;; Free mint for everyone (unlimited per wallet)
(define-public (free-mint
        (name (string-ascii 256))
        (uri (string-ascii 256))
    )
    (let (
            (token-id (unwrap! (get-next-token-id) ERR-MAX-SUPPLY-REACHED))
            (minter tx-sender)
        )
        ;; Validate inputs
        (asserts! (> (len name) u0) ERR-INVALID-INPUT)
        (asserts! (> (len uri) u0) ERR-INVALID-INPUT)

        ;; Check if minting is enabled
        (asserts! (var-get mint-enabled) ERR-NOT-AUTHORIZED)

        ;; Mint the NFT
        (unwrap! (nft-mint? BitcoinStamp token-id minter) ERR-ALREADY-EXISTS)

        ;; Store metadata
        (map-set token-metadata token-id {
            name: name,
            uri: uri,
            minted-at: stacks-block-height,
        })

        (ok token-id)
    )
)

;; Owner free mint to any recipient
(define-public (owner-mint
        (recipient principal)
        (name (string-ascii 256))
        (uri (string-ascii 256))
    )
    (let ((token-id (unwrap! (get-next-token-id) ERR-MAX-SUPPLY-REACHED)))
        ;; Only contract owner can use this
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)

        ;; Validate inputs
        (asserts! (> (len name) u0) ERR-INVALID-INPUT)
        (asserts! (> (len uri) u0) ERR-INVALID-INPUT)

        ;; Mint the NFT
        (unwrap! (nft-mint? BitcoinStamp token-id recipient) ERR-ALREADY-EXISTS)

        ;; Store metadata
        (map-set token-metadata token-id {
            name: name,
            uri: uri,
            minted-at: stacks-block-height,
        })

        (ok token-id)
    )
)

;; Transfer NFT
(define-public (transfer
        (token-id uint)
        (sender principal)
        (recipient principal)
    )
    (begin
        ;; Check ownership
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        ;; Transfer the NFT
        (ok (unwrap! (nft-transfer? BitcoinStamp token-id sender recipient)
            ERR-NOT-FOUND
        ))
    )
)

;; Burn NFT
(define-public (burn (token-id uint))
    (let ((owner (unwrap! (nft-get-owner? BitcoinStamp token-id) ERR-NOT-FOUND)))
        ;; Check ownership
        (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
        ;; Burn the NFT
        (ok (unwrap! (nft-burn? BitcoinStamp token-id owner) ERR-NOT-FOUND))
    )
)

;; Admin functions

;; Toggle minting
(define-public (toggle-mint-enabled)
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (var-set mint-enabled (not (var-get mint-enabled)))
        (ok true)
    )
)

;; Update base URI
(define-public (set-base-uri (new-uri (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (var-set base-uri new-uri)
        (ok true)
    )
)

;; Read-only functions

;; Get token owner
(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? BitcoinStamp token-id))
)

;; Get token metadata
(define-read-only (get-token-metadata (token-id uint))
    (ok (map-get? token-metadata token-id))
)

;; Get token URI
(define-read-only (get-token-uri (token-id uint))
    (match (map-get? token-metadata token-id)
        data (ok (some (get uri data)))
        (ok none)
    )
)

;; Get last minted token ID
(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

;; Get total supply
(define-read-only (get-total-supply)
    (ok (var-get last-token-id))
)

;; Check if minting is enabled
(define-read-only (is-mint-enabled)
    (ok (var-get mint-enabled))
)

;; Get mint price
(define-read-only (get-mint-price)
    (ok MINT-PRICE)
)

;; Get max supply
(define-read-only (get-max-supply)
    (ok MAX-SUPPLY)
)

;; Get base URI
(define-read-only (get-base-uri)
    (ok (var-get base-uri))
)

;; Get contract owner
(define-read-only (get-contract-owner)
    (ok contract-owner)
)
