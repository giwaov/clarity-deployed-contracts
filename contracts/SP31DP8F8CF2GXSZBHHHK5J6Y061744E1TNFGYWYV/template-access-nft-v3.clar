;; template-access-nft-v3.clar
;; SIP-009 NFT for Template Access Control
;; FIXED: Multiple users can mint the same template
;; Each mint gets a unique NFT ID, template access tracked separately

(impl-trait .sip-009-nft-trait.nft-trait)

;; Define NFT with auto-incrementing IDs
(define-non-fungible-token access-template uint)

;; Data vars
(define-data-var last-nft-id uint u0)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MINT_PRICE u100000) ;; 0.1 STX
(define-constant MAX_TEMPLATES u50)

;; Error codes
(define-constant ERR_INVALID_TEMPLATE (err u1))
(define-constant ERR_NOT_OWNER (err u2))
(define-constant ERR_ALREADY_HAS_ACCESS (err u3))

;; Maps
;; Track which templates each user has access to
(define-map user-template-access 
  { user: principal, template-id: uint } 
  { nft-id: uint, minted-at: uint })

;; Track which template each NFT represents
(define-map nft-template-map uint uint)

;; SIP-009: Get last token ID
(define-read-only (get-last-token-id)
  (ok (var-get last-nft-id)))

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
    
    ;; Get the template ID for this NFT
    (let ((template-id (unwrap! (map-get? nft-template-map token-id) ERR_INVALID_TEMPLATE)))
      ;; Remove access from sender
      (map-delete user-template-access { user: sender, template-id: template-id })
      
      ;; Grant access to recipient
      (map-set user-template-access 
        { user: recipient, template-id: template-id }
        { nft-id: token-id, minted-at: stacks-block-height })
      
      ;; Transfer the NFT
      (nft-transfer? access-template token-id sender recipient))))

;; Public: Mint access NFT for a template
;; Multiple users can mint the same template
;; Each mint creates a unique NFT with auto-incrementing ID
(define-public (mint (template-id uint))
  (let
    (
      (new-nft-id (+ (var-get last-nft-id) u1))
      (minter tx-sender)
    )
    ;; Validate template-id (1-50)
    (asserts! (and (>= template-id u1) (<= template-id MAX_TEMPLATES)) ERR_INVALID_TEMPLATE)
    
    ;; Check if user already has access to this template
    (asserts! (is-none (map-get? user-template-access { user: minter, template-id: template-id })) 
              ERR_ALREADY_HAS_ACCESS)
    
    ;; Transfer STX to contract owner
    (try! (stx-transfer? MINT_PRICE minter CONTRACT_OWNER))
    
    ;; Mint NFT with unique ID
    (try! (nft-mint? access-template new-nft-id minter))
    
    ;; Update last-nft-id
    (var-set last-nft-id new-nft-id)
    
    ;; Track template access
    (map-set user-template-access 
      { user: minter, template-id: template-id }
      { nft-id: new-nft-id, minted-at: stacks-block-height })
    
    ;; Map NFT to template
    (map-set nft-template-map new-nft-id template-id)
    
    ;; Log event
    (print {
      event: "template-access-mint",
      user: minter,
      template-id: template-id,
      nft-id: new-nft-id,
      block-height: stacks-block-height,
      price: MINT_PRICE
    })
    
    (ok new-nft-id)
  ))

;; Read-only: Check if user has access to a specific template
(define-read-only (has-access (user principal) (template-id uint))
  (is-some (map-get? user-template-access { user: user, template-id: template-id })))

;; Read-only: Get user's NFT ID for a template
(define-read-only (get-user-nft-for-template (user principal) (template-id uint))
  (map-get? user-template-access { user: user, template-id: template-id }))

;; Read-only: Get template ID for an NFT
(define-read-only (get-template-for-nft (nft-id uint))
  (map-get? nft-template-map nft-id))

;; Read-only: Get mint price
(define-read-only (get-mint-price)
  (ok MINT_PRICE))
