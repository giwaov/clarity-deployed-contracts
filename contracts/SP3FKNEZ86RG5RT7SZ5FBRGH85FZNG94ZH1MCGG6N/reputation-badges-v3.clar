;; StackPulse Reputation Badges V3 (SIP-009 NFT)
;; NFT badges for achievements and milestones
;;
;; Badge Types:
;; 1 = Early Adopter (first 100 users)
;; 2 = Whale Watcher (detected 10 whale transfers)
;; 3 = Alert Master (created 25+ alerts)
;; 4 = Power User (Pro or Premium subscriber)
;; 5 = Referral Champion (referred 5+ users)
;; 6 = Year One (subscribed for 1 year)
;; 7 = Community Builder (participated in governance)
;; 8 = Bug Hunter (reported valid bugs)
;; 9 = StackPulse OG (original beta tester)

;; ============================================
;; SIP-009 NFT TRAIT
;; ============================================

(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-MINTED (err u102))
(define-constant ERR-INVALID-BADGE (err u103))

;; Base URI for metadata
(define-constant BASE-URI "https://stackpulse.vercel.app/api/badges/")

;; ============================================
;; NFT DEFINITION
;; ============================================

(define-non-fungible-token stackpulse-badge uint)

;; ============================================
;; DATA STORAGE
;; ============================================

(define-data-var last-token-id uint u0)
(define-data-var total-badges-minted uint u0)

;; Badge metadata
(define-map badge-data uint
  {
    badge-type: uint,
    name: (string-ascii 64),
    recipient: principal,
    minted-at: uint
  }
)

;; Track which badge types a user has
(define-map user-badges { user: principal, badge-type: uint } uint)

;; Badge type definitions
(define-map badge-definitions uint 
  {
    name: (string-ascii 64),
    description: (string-ascii 256),
    max-supply: uint,
    minted-count: uint
  }
)

;; Authorized minters (can be other contracts)
(define-map authorized-minters principal bool)

;; ============================================
;; INITIALIZATION
;; ============================================

;; Initialize badge definitions
(map-set badge-definitions u1 { name: "Early Adopter", description: "Among the first 100 StackPulse users", max-supply: u100, minted-count: u0 })
(map-set badge-definitions u2 { name: "Whale Watcher", description: "Detected 10+ whale transfers", max-supply: u0, minted-count: u0 })
(map-set badge-definitions u3 { name: "Alert Master", description: "Created 25+ alerts", max-supply: u0, minted-count: u0 })
(map-set badge-definitions u4 { name: "Power User", description: "Pro or Premium subscriber", max-supply: u0, minted-count: u0 })
(map-set badge-definitions u5 { name: "Referral Champion", description: "Referred 5+ users", max-supply: u0, minted-count: u0 })
(map-set badge-definitions u6 { name: "Year One", description: "Active for 1 year", max-supply: u0, minted-count: u0 })
(map-set badge-definitions u7 { name: "Community Builder", description: "Active in governance", max-supply: u0, minted-count: u0 })
(map-set badge-definitions u8 { name: "Bug Hunter", description: "Reported valid bugs", max-supply: u0, minted-count: u0 })
(map-set badge-definitions u9 { name: "StackPulse OG", description: "Original beta tester", max-supply: u50, minted-count: u0 })

;; ============================================
;; SIP-009 REQUIRED FUNCTIONS
;; ============================================

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (some (concat BASE-URI (uint-to-string token-id))))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? stackpulse-badge token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (nft-transfer? stackpulse-badge token-id sender recipient)
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-badge-data (token-id uint))
  (map-get? badge-data token-id)
)

(define-read-only (get-badge-definition (badge-type uint))
  (map-get? badge-definitions badge-type)
)

(define-read-only (has-badge (user principal) (badge-type uint))
  (is-some (map-get? user-badges { user: user, badge-type: badge-type }))
)

(define-read-only (get-user-badge-token (user principal) (badge-type uint))
  (map-get? user-badges { user: user, badge-type: badge-type })
)

(define-read-only (get-stats)
  {
    total-minted: (var-get total-badges-minted),
    last-id: (var-get last-token-id)
  }
)

(define-read-only (is-authorized-minter (minter principal))
  (default-to false (map-get? authorized-minters minter))
)

;; ============================================
;; PUBLIC FUNCTIONS
;; ============================================

;; Mint a badge to a user
(define-public (mint-badge (recipient principal) (badge-type uint))
  (let
    (
      (token-id (+ (var-get last-token-id) u1))
      (badge-def (unwrap! (map-get? badge-definitions badge-type) ERR-INVALID-BADGE))
    )
    ;; Check authorization
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) 
                  (is-authorized-minter tx-sender)) ERR-NOT-AUTHORIZED)
    
    ;; Check if user already has this badge type
    (asserts! (not (has-badge recipient badge-type)) ERR-ALREADY-MINTED)
    
    ;; Check max supply (0 = unlimited)
    (asserts! (or (is-eq (get max-supply badge-def) u0)
                  (< (get minted-count badge-def) (get max-supply badge-def))) 
              ERR-NOT-AUTHORIZED)
    
    ;; Mint NFT
    (try! (nft-mint? stackpulse-badge token-id recipient))
    
    ;; Store badge data
    (map-set badge-data token-id {
      badge-type: badge-type,
      name: (get name badge-def),
      recipient: recipient,
      minted-at: block-height
    })
    
    ;; Track user's badge
    (map-set user-badges { user: recipient, badge-type: badge-type } token-id)
    
    ;; Update badge definition minted count
    (map-set badge-definitions badge-type (merge badge-def {
      minted-count: (+ (get minted-count badge-def) u1)
    }))
    
    ;; Update counters
    (var-set last-token-id token-id)
    (var-set total-badges-minted (+ (var-get total-badges-minted) u1))
    
    (print {
      event: "badge-earned",
      token-id: token-id,
      recipient: recipient,
      badge-type: badge-type,
      badge-name: (get name badge-def),
      block: block-height
    })
    
    (ok token-id)
  )
)

;; Admin: Add authorized minter (for other contracts to mint)
(define-public (add-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-minters minter true)
    (ok true)
  )
)

;; Admin: Remove authorized minter
(define-public (remove-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-delete authorized-minters minter)
    (ok true)
  )
)

;; ============================================
;; UTILITY FUNCTIONS
;; ============================================

;; Helper to convert uint to string (renamed to avoid conflict with built-in)
(define-read-only (uint-to-string (value uint))
  (if (<= value u9)
    (unwrap-panic (element-at "0123456789" value))
    (get r (fold uint-to-string-iter
      (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9)
      { n: value, r: "" }))
  )
)

(define-private (uint-to-string-iter (idx uint) (state { n: uint, r: (string-ascii 10) }))
  (if (> (get n state) u0)
    {
      n: (/ (get n state) u10),
      r: (unwrap-panic (as-max-len? 
        (concat (unwrap-panic (element-at "0123456789" (mod (get n state) u10))) (get r state)) 
        u10))
    }
    state
  )
)
