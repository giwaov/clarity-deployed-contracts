;; template-access-nft.clar
;; SIP-009 NFT for Template Access Control
;; Clarity 4 features: stacks-block-time

;; Use local trait for development (use mainnet trait for production deployment)
(impl-trait .sip-009-nft-trait.nft-trait)

;; Define NFT
(define-non-fungible-token access-template uint)

;; Data vars
(define-data-var last-id uint u0)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MINT_PRICE u100000) ;; 0.1 STX
(define-constant MAX_TEMPLATES u50)

;; Error codes
(define-constant ERR_SOLD_OUT (err u1))
(define-constant ERR_INSUFFICIENT (err u2))
(define-constant ERR_INVALID_ID (err u3))
(define-constant ERR_NOT_OWNER (err u4))
(define-constant ERR_ALREADY_MINTED (err u5))

;; SIP-009: Get last token ID
(define-read-only (get-last-token-id)
  (ok (var-get last-id)))

;; SIP-009: Get owner of token
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? access-template token-id)))

;; SIP-009: Get token URI (metadata)
(define-read-only (get-token-uri (token-id uint))
  (ok (some "https://clarity-template-hub.com/metadata/{id}")))

;; SIP-009: Transfer token
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_OWNER)
    (nft-transfer? access-template token-id sender recipient)))

;; Public: Mint access NFT for a template
;; User pays MINT_PRICE STX to mint template access
(define-public (mint (template-id uint))
  (begin
    ;; Validate template-id (1-50)
    (asserts! (and (>= template-id u1) (<= template-id MAX_TEMPLATES)) ERR_INVALID_ID)
    
    ;; Check if already minted
    (asserts! (is-none (nft-get-owner? access-template template-id)) ERR_ALREADY_MINTED)
    
    ;; Transfer STX to contract owner
    (try! (stx-transfer? MINT_PRICE tx-sender CONTRACT_OWNER))
    
    ;; Mint NFT
    (try! (nft-mint? access-template template-id tx-sender))
    
    ;; Update last-id if needed
    (if (> template-id (var-get last-id))
      (var-set last-id template-id)
      true)
    
    ;; Clarity 4: Log with stacks-block-time
    (print {
      event: "template-access-mint",
      user: tx-sender,
      template-id: template-id,
      time: stacks-block-time,
      price: MINT_PRICE
    })
    
    (ok template-id)
  ))

;; Read-only: Check if user owns a specific template
(define-read-only (has-access (user principal) (template-id uint))
  (is-eq (some user) (nft-get-owner? access-template template-id)))

;; Read-only: Get template owner
(define-read-only (get-template-owner (template-id uint))
  (nft-get-owner? access-template template-id))

;; Read-only: Get mint price
(define-read-only (get-mint-price)
  (ok MINT_PRICE))
