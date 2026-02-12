;; ============================================
;; ACHIEVEMENT NFT - Badges of Inaction
;; SIP-009 Compliant
;; Clarity 2 Smart Contract
;; ============================================

(impl-trait .nft-trait.nft-trait)

(define-constant ERR_NOT_ELIGIBLE (err u403))
(define-constant ERR_ALREADY_CLAIMED (err u409))

(define-non-fungible-token achievement-badge uint)
(define-data-var last-token-id uint u0)

(define-map user-badges { user: principal, type: uint } bool)

;; Badge Types
(define-constant BADGE-BEGINNER u1) ;; 1 day
(define-constant BADGE-EXPERT u2)   ;; 7 days
(define-constant BADGE-MASTER u3)   ;; 30 days

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (begin
    token-id
    (ok none)
  )
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? achievement-badge token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) (err u401))
    (nft-transfer? achievement-badge token-id sender recipient)
  )
)

(define-public (claim-badge (badge-type uint))
  (let
    (
      (user tx-sender)
      (streak-blocks (unwrap-panic (contract-call? .streak-tracker get-streak-blocks user)))
      (threshold (get-threshold badge-type))
      (new-id (+ (var-get last-token-id) u1))
    )
    (asserts! (>= streak-blocks threshold) ERR_NOT_ELIGIBLE)
    (asserts! (is-none (map-get? user-badges { user: user, type: badge-type })) ERR_ALREADY_CLAIMED)
    
    (try! (nft-mint? achievement-badge new-id user))
    (map-set user-badges { user: user, type: badge-type } true)
    (var-set last-token-id new-id)
    (ok new-id)
  )
)

(define-read-only (get-threshold (badge-type uint))
  (if (is-eq badge-type BADGE-BEGINNER) u144
    (if (is-eq badge-type BADGE-EXPERT) u1008
      (if (is-eq badge-type BADGE-MASTER) u4320
        u999999
      )
    )
  )
)
