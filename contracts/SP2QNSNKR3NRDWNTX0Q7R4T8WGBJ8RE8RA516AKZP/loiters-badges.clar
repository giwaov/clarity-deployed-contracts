;; Loiters Badges (NFT Achievement System)
;; SIP-009 Non-Fungible Token for achievement badges

(impl-trait .nft-trait.nft-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u3000))
(define-constant ERR-NOT-FOUND (err u3001))
(define-constant ERR-ALREADY-CLAIMED (err u3002))
(define-constant ERR-NOT-TRANSFERABLE (err u3003))
(define-constant ERR-CRITERIA-NOT-MET (err u3004))

;; Badge Types
(define-constant BADGE-EARLY-ADOPTER u1)
(define-constant BADGE-CHECKIN-10 u2)
(define-constant BADGE-CHECKIN-50 u3)
(define-constant BADGE-CHECKIN-100 u4)
(define-constant BADGE-CHECKIN-500 u5)
(define-constant BADGE-CHECKIN-1000 u6)
(define-constant BADGE-STREAK-7 u7)
(define-constant BADGE-STREAK-30 u8)
(define-constant BADGE-STREAK-90 u9)
(define-constant BADGE-STREAK-365 u10)
(define-constant BADGE-SOCIAL-BUTTERFLY-10 u11)
(define-constant BADGE-SOCIAL-BUTTERFLY-50 u12)
(define-constant BADGE-SOCIAL-BUTTERFLY-100 u13)
(define-constant BADGE-REPUTATION-BRONZE u14)
(define-constant BADGE-REPUTATION-SILVER u15)
(define-constant BADGE-REPUTATION-GOLD u16)
(define-constant BADGE-REPUTATION-PLATINUM u17)
(define-constant BADGE-REPUTATION-DIAMOND u18)

;; Data Variables
(define-data-var last-badge-id uint u0)
(define-data-var base-token-uri (string-ascii 256) "https://loiters.io/badges/")
(define-data-var early-adopter-count uint u0)
(define-data-var early-adopter-limit uint u1000)

;; NFT Definition
(define-non-fungible-token loiters-badge uint)

;; Data Maps

;; Badge metadata
(define-map badge-data
  uint
  {
    badge-type: uint,
    owner: principal,
    earned-at: uint,
    transferable: bool,
    metadata-uri: (string-ascii 256)
  }
)

;; User badges (for quick lookup)
(define-map user-badges
  {user: principal, badge-type: uint}
  uint ;; badge-id
)


;; Badge type info
(define-map badge-type-info
  uint
  {
    name: (string-utf8 64),
    description: (string-utf8 256),
    rarity: (string-utf8 32),
    transferable: bool
  }
)

;; Initialize badge type information
(map-set badge-type-info BADGE-EARLY-ADOPTER {
  name: u"Early Adopter",
  description: u"One of the first 1000 users to join Loiters",
  rarity: u"Legendary",
  transferable: false
})

(map-set badge-type-info BADGE-CHECKIN-10 {
  name: u"Explorer",
  description: u"Completed 10 check-ins",
  rarity: u"Common",
  transferable: false
})

(map-set badge-type-info BADGE-CHECKIN-100 {
  name: u"Adventurer",
  description: u"Completed 100 check-ins",
  rarity: u"Rare",
  transferable: false
})

(map-set badge-type-info BADGE-STREAK-30 {
  name: u"Dedicated",
  description: u"Maintained a 30-day check-in streak",
  rarity: u"Epic",
  transferable: false
})

(map-set badge-type-info BADGE-REPUTATION-DIAMOND {
  name: u"Diamond Elite",
  description: u"Reached Diamond reputation tier",
  rarity: u"Legendary",
  transferable: false
})

;; SIP-009 Functions

(define-read-only (get-last-token-id)
  (ok (var-get last-badge-id))
)

(define-read-only (get-token-uri (badge-id uint))
  (ok (some (get metadata-uri (unwrap! (map-get? badge-data badge-id) ERR-NOT-FOUND))))
)

(define-read-only (get-owner (badge-id uint))
  (ok (nft-get-owner? loiters-badge badge-id))
)

(define-public (transfer (badge-id uint) (sender principal) (recipient principal))
  (let
    (
      (badge-info (unwrap! (map-get? badge-data badge-id) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (asserts! (get transferable badge-info) ERR-NOT-TRANSFERABLE)
    (try! (nft-transfer? loiters-badge badge-id sender recipient))
    (map-set badge-data badge-id (merge badge-info {owner: recipient}))
    (ok true)
  )
)

;; Custom Functions

(define-read-only (get-badge-data (badge-id uint))
  (map-get? badge-data badge-id)
)

(define-read-only (get-badge-type-info (badge-type uint))
  (map-get? badge-type-info badge-type)
)

(define-read-only (has-badge (user principal) (badge-type uint))
  (is-some (map-get? user-badges {user: user, badge-type: badge-type}))
)

(define-read-only (get-user-badge-id (user principal) (badge-type uint))
  (map-get? user-badges {user: user, badge-type: badge-type})
)

;; Mint badge (called by authorized contracts or owner)
(define-public (mint-badge (recipient principal) (badge-type uint))
  (let
    (
      (new-badge-id (+ (var-get last-badge-id) u1))
      (badge-type-data (unwrap! (map-get? badge-type-info badge-type) ERR-NOT-FOUND))
      (metadata-uri (var-get base-token-uri)) ;; Simplified - just use base URI
    )
    ;; Check if user already has this badge
    (asserts! (not (has-badge recipient badge-type)) ERR-ALREADY-CLAIMED)
    
    ;; Special check for early adopter badge
    (if (is-eq badge-type BADGE-EARLY-ADOPTER)
      (begin
        (asserts! (< (var-get early-adopter-count) (var-get early-adopter-limit)) ERR-CRITERIA-NOT-MET)
        (var-set early-adopter-count (+ (var-get early-adopter-count) u1))
      )
      true
    )
    
    ;; Mint NFT
    (try! (nft-mint? loiters-badge new-badge-id recipient))
    
    ;; Store badge data
    (map-set badge-data new-badge-id {
      badge-type: badge-type,
      owner: recipient,
      earned-at: stacks-block-height,
      transferable: (get transferable badge-type-data),
      metadata-uri: metadata-uri
    })
    
    ;; Map user to badge
    (map-set user-badges {user: recipient, badge-type: badge-type} new-badge-id)
    
    ;; Update counter
    (var-set last-badge-id new-badge-id)
    
    (print {
      type: "badge-minted",
      badge-id: new-badge-id,
      badge-type: badge-type,
      recipient: recipient,
      timestamp: stacks-block-height
    })
    
    (ok new-badge-id)
  )
)

;; Claim badge based on achievements (checks criteria from core contract)
(define-public (claim-badge (badge-type uint))
  (let
    (
      (user-data (unwrap! (contract-call? .loiters-core get-user tx-sender) ERR-NOT-AUTHORIZED))
    )
    ;; Check criteria based on badge type
    (asserts! (check-badge-criteria badge-type user-data) ERR-CRITERIA-NOT-MET)
    (mint-badge tx-sender badge-type)
  )
)

;; Helper function to check if user meets badge criteria
(define-read-only (check-badge-criteria (badge-type uint) (user-data {
  username: (string-utf8 32),
  bio: (string-utf8 256),
  avatar-uri: (string-utf8 256),
  reputation-score: uint,
  total-checkins: uint,
  current-streak: uint,
  longest-streak: uint,
  total-endorsements-received: uint,
  total-endorsements-given: uint,
  joined-at: uint,
  last-checkin: uint
}))
  (if (is-eq badge-type BADGE-CHECKIN-10)
    (>= (get total-checkins user-data) u10)
    (if (is-eq badge-type BADGE-CHECKIN-50)
      (>= (get total-checkins user-data) u50)
      (if (is-eq badge-type BADGE-CHECKIN-100)
        (>= (get total-checkins user-data) u100)
        (if (is-eq badge-type BADGE-CHECKIN-500)
          (>= (get total-checkins user-data) u500)
          (if (is-eq badge-type BADGE-CHECKIN-1000)
            (>= (get total-checkins user-data) u1000)
            (if (is-eq badge-type BADGE-STREAK-7)
              (>= (get longest-streak user-data) u7)
              (if (is-eq badge-type BADGE-STREAK-30)
                (>= (get longest-streak user-data) u30)
                (if (is-eq badge-type BADGE-STREAK-90)
                  (>= (get longest-streak user-data) u90)
                  (if (is-eq badge-type BADGE-STREAK-365)
                    (>= (get longest-streak user-data) u365)
                    (if (is-eq badge-type BADGE-SOCIAL-BUTTERFLY-10)
                      (>= (get total-endorsements-received user-data) u10)
                      (if (is-eq badge-type BADGE-REPUTATION-SILVER)
                        (>= (get reputation-score user-data) u1000)
                        (if (is-eq badge-type BADGE-REPUTATION-GOLD)
                          (>= (get reputation-score user-data) u5000)
                          (if (is-eq badge-type BADGE-REPUTATION-PLATINUM)
                            (>= (get reputation-score user-data) u15000)
                            (if (is-eq badge-type BADGE-REPUTATION-DIAMOND)
                              (>= (get reputation-score user-data) u50000)
                              false
                            )
                          )
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)

;; Admin functions
(define-public (set-base-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set base-token-uri new-uri))
  )
)

(define-public (add-badge-type (badge-type uint) (name (string-utf8 64)) (description (string-utf8 256)) (rarity (string-utf8 32)) (transferable bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set badge-type-info badge-type {
      name: name,
      description: description,
      rarity: rarity,
      transferable: transferable
    }))
  )
)
