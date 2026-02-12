;; ============================================
;; BITSIGN NFT - AI-Generated Bitcoin Personality NFTs
;; SIP-009 Compliant NFT with Dynamic Metadata
;; Clarity 4 Smart Contract
;; ============================================

(impl-trait .nft-trait.nft-trait)

(define-constant CONTRACT_OWNER tx-sender)

(define-constant ERR_NOT_OWNER (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_MINTED (err u409))
(define-constant ERR_INVALID_BLOCK (err u400))

(define-constant MINT_PRICE u5000000)

(define-non-fungible-token bitsign-nft uint)

(define-data-var last-token-id uint u0)
(define-data-var base-uri (string-ascii 200) "https://api.bitsigns.xyz/metadata/")

(define-map token-birth-blocks uint uint)
(define-map token-image-uris uint (string-ascii 200))
(define-map user-has-minted principal bool)

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (some (concat (var-get base-uri) (concat (int-to-ascii token-id) ".json"))))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? bitsign-nft token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_OWNER)
    (nft-transfer? bitsign-nft token-id sender recipient)
  )
)

(define-public (mint (birth-block uint))
  (let ((new-id (+ (var-get last-token-id) u1)))
    (asserts! (is-none (map-get? user-has-minted tx-sender)) ERR_ALREADY_MINTED)
    (asserts! (<= birth-block burn-block-height) ERR_INVALID_BLOCK)
    (try! (stx-transfer? MINT_PRICE tx-sender CONTRACT_OWNER))
    (try! (nft-mint? bitsign-nft new-id tx-sender))
    (map-set token-birth-blocks new-id birth-block)
    (map-set user-has-minted tx-sender true)
    (var-set last-token-id new-id)
    (ok new-id)
  )
)

(define-public (set-token-image (token-id uint) (image-uri (string-ascii 200)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    (map-set token-image-uris token-id image-uri)
    (ok true)
  )
)

(define-read-only (get-token-birth-block (token-id uint))
  (map-get? token-birth-blocks token-id)
)

(define-read-only (get-token-data (token-id uint))
  (let ((birth-block (unwrap! (map-get? token-birth-blocks token-id) ERR_NOT_FOUND)))
    (ok {
      token-id: token-id,
      owner: (nft-get-owner? bitsign-nft token-id),
      birth-block: birth-block,
      image-uri: (map-get? token-image-uris token-id)
    })
  )
)

(define-read-only (has-minted (user principal))
  (map-get? user-has-minted user)
)

(define-read-only (get-mint-price)
  (ok MINT_PRICE)
)

(define-public (set-base-uri (new-uri (string-ascii 200)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    (var-set base-uri new-uri)
    (ok true)
  )
)
