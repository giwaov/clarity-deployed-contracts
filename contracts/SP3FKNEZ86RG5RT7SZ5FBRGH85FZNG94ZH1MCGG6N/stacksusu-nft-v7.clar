;; StackSusu NFT v7
;; Membership badges and achievements

(define-constant CONTRACT-OWNER tx-sender)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u5000))
(define-constant ERR-NOT-FOUND (err u5001))
(define-constant ERR-ALREADY-MINTED (err u5002))
(define-constant ERR-INVALID-TYPE (err u5003))

;; NFT types
(define-constant TYPE-MEMBER-BADGE u1)
(define-constant TYPE-CIRCLE-COMPLETE u2)
(define-constant TYPE-TOP-CONTRIBUTOR u3)
(define-constant TYPE-EARLY-ADOPTER u4)
(define-constant TYPE-REPUTATION-TIER u5)

;; NFT counter
(define-data-var nft-counter uint u0)

;; NFT data
(define-map nfts
  uint  ;; token-id
  {
    owner: principal,
    nft-type: uint,
    metadata: (string-ascii 200),
    minted-at: uint,
    circle-id: (optional uint)
  }
)

;; Owner's NFTs
(define-map owner-nfts
  principal
  (list 50 uint)
)

;; Track minted badges per type per user
(define-map minted-badges
  { owner: principal, nft-type: uint }
  bool
)


;; ============================================
;; Mint Functions
;; ============================================

(define-public (mint-member-badge (member principal))
  (let
    (
      (token-id (+ (var-get nft-counter) u1))
      (already-minted (default-to false (map-get? minted-badges { owner: member, nft-type: TYPE-MEMBER-BADGE })))
    )
    (asserts! (not already-minted) ERR-ALREADY-MINTED)
    
    ;; Mint NFT
    (map-set nfts token-id {
      owner: member,
      nft-type: TYPE-MEMBER-BADGE,
      metadata: "StackSusu Member Badge",
      minted-at: block-height,
      circle-id: none
    })
    
    ;; Track ownership
    (map-set owner-nfts member 
      (unwrap! (as-max-len? (append (default-to (list) (map-get? owner-nfts member)) token-id) u50) ERR-NOT-AUTHORIZED))
    
    ;; Mark as minted
    (map-set minted-badges { owner: member, nft-type: TYPE-MEMBER-BADGE } true)
    
    (var-set nft-counter token-id)
    (ok token-id)
  )
)

(define-public (mint-circle-completion (member principal) (circle-id uint))
  (let
    (
      (token-id (+ (var-get nft-counter) u1))
    )
    ;; Mint NFT for completing a circle
    (map-set nfts token-id {
      owner: member,
      nft-type: TYPE-CIRCLE-COMPLETE,
      metadata: "Circle Completion Achievement",
      minted-at: block-height,
      circle-id: (some circle-id)
    })
    
    ;; Track ownership
    (map-set owner-nfts member 
      (unwrap! (as-max-len? (append (default-to (list) (map-get? owner-nfts member)) token-id) u50) ERR-NOT-AUTHORIZED))
    
    (var-set nft-counter token-id)
    (ok token-id)
  )
)

(define-public (mint-reputation-badge (member principal) (tier uint))
  (let
    (
      (token-id (+ (var-get nft-counter) u1))
      (tier-name (if (is-eq tier u5) "Legendary"
                  (if (is-eq tier u4) "Expert"
                    (if (is-eq tier u3) "Advanced"
                      (if (is-eq tier u2) "Intermediate" "Beginner")))))
    )
    ;; Mint tier badge
    (map-set nfts token-id {
      owner: member,
      nft-type: TYPE-REPUTATION-TIER,
      metadata: tier-name,
      minted-at: block-height,
      circle-id: none
    })
    
    ;; Track ownership
    (map-set owner-nfts member 
      (unwrap! (as-max-len? (append (default-to (list) (map-get? owner-nfts member)) token-id) u50) ERR-NOT-AUTHORIZED))
    
    (var-set nft-counter token-id)
    (ok token-id)
  )
)


;; ============================================
;; Transfer
;; ============================================

(define-public (transfer (token-id uint) (recipient principal))
  (let
    (
      (nft (unwrap! (map-get? nfts token-id) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get owner nft)) ERR-NOT-AUTHORIZED)
    
    ;; Update owner
    (map-set nfts token-id (merge nft { owner: recipient }))
    
    ;; Update ownership tracking
    (map-set owner-nfts recipient 
      (unwrap! (as-max-len? (append (default-to (list) (map-get? owner-nfts recipient)) token-id) u50) ERR-NOT-AUTHORIZED))
    
    (ok true)
  )
)


;; ============================================
;; Read Functions
;; ============================================

(define-read-only (get-nft (token-id uint))
  (map-get? nfts token-id)
)

(define-read-only (get-owner (token-id uint))
  (match (map-get? nfts token-id)
    nft (ok (some (get owner nft)))
    (ok none)
  )
)

(define-read-only (get-nft-count)
  (var-get nft-counter)
)

(define-read-only (get-owner-nfts (owner principal))
  (default-to (list) (map-get? owner-nfts owner))
)

(define-read-only (has-badge (owner principal) (nft-type uint))
  (default-to false (map-get? minted-badges { owner: owner, nft-type: nft-type }))
)
