;; StackSusu Core v5
;; Enhanced circle management with round-by-round contributions

(define-constant CONTRACT-OWNER tx-sender)

;; Circle size limits
(define-constant MIN-MEMBERS u3)
(define-constant MAX-MEMBERS u50)
(define-constant MIN-CONTRIBUTION u10000)        ;; 0.01 STX minimum
(define-constant MAX-CONTRIBUTION u100000000)    ;; 100 STX maximum per round
(define-constant BLOCKS-PER-DAY u144)

;; Circle status constants
(define-constant STATUS-PENDING u0)      ;; Waiting for members
(define-constant STATUS-ACTIVE u1)       ;; Circle is running rounds
(define-constant STATUS-COMPLETED u2)    ;; All rounds finished
(define-constant STATUS-CANCELLED u3)    ;; Circle was cancelled
(define-constant STATUS-PAUSED u4)       ;; Temporarily paused

;; Contribution mode constants
(define-constant MODE-UPFRONT u0)        ;; All members deposit full amount upfront (v4 style)
(define-constant MODE-ROUND-BY-ROUND u1) ;; Members contribute each round

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-CIRCLE-NOT-FOUND (err u1001))
(define-constant ERR-CIRCLE-FULL (err u1002))
(define-constant ERR-ALREADY-MEMBER (err u1004))
(define-constant ERR-NOT-MEMBER (err u1005))
(define-constant ERR-INVALID-AMOUNT (err u1006))
(define-constant ERR-INVALID-MEMBERS (err u1007))
(define-constant ERR-INVALID-INTERVAL (err u1008))
(define-constant ERR-CIRCLE-NOT-ACTIVE (err u1015))
(define-constant ERR-PAUSED (err u1021))
(define-constant ERR-INVALID-SLOT (err u1022))
(define-constant ERR-MAX-CIRCLES-REACHED (err u1026))
(define-constant ERR-REPUTATION-TOO-LOW (err u1027))
(define-constant ERR-CIRCLE-NOT-READY (err u1028))
(define-constant ERR-INVALID-MODE (err u1029))

;; Circle data structure
(define-map circles
  uint
  {
    creator: principal,
    name: (string-ascii 50),
    contribution: uint,           ;; Amount per member per round
    max-members: uint,
    payout-interval: uint,        ;; Blocks between payouts
    status: uint,
    current-round: uint,
    start-block: uint,
    member-count: uint,
    created-at: uint,
    contribution-mode: uint,      ;; NEW: upfront or round-by-round
    min-reputation: uint,         ;; NEW: minimum reputation required
    total-contributed: uint,      ;; NEW: total STX contributed to circle
    total-paid-out: uint          ;; NEW: total STX paid out
  }
)

;; Member data
(define-map circle-members
  { circle-id: uint, member: principal }
  { 
    slot: uint, 
    joined-at: uint,
    contributions-made: uint,     ;; NEW: count of contributions
    last-contribution-round: uint ;; NEW: last round contributed to
  }
)

;; Slot to member mapping (for payout order)
(define-map slot-to-member
  { circle-id: uint, slot: uint }
  principal
)

;; Member's circles list
(define-map member-circles
  principal
  (list 20 uint)
)

;; Round contribution tracking
(define-map round-contributions
  { circle-id: uint, round: uint, member: principal }
  { amount: uint, contributed-at: uint, is-late: bool }
)

;; Round status
(define-map round-status
  { circle-id: uint, round: uint }
  {
    contributions-received: uint,
    total-amount: uint,
    payout-processed: bool,
    recipient: (optional principal),
    started-at: uint
  }
)

;; Counters
(define-data-var circle-counter uint u0)

;; NFT minting setting
(define-data-var nft-minting-enabled bool true)

;; Authorized slot updaters
(define-map authorized-slot-updaters principal bool)


;; ============================================
;; Circle Creation
;; ============================================

(define-public (create-circle 
    (name (string-ascii 50))
    (contribution uint) 
    (max-members uint) 
    (payout-interval-days uint)
    (contribution-mode uint)
    (min-reputation uint))
  (let
    (
      (creator tx-sender)
      (circle-id (+ (var-get circle-counter) u1))
      (payout-interval-blocks (* payout-interval-days BLOCKS-PER-DAY))
      (creator-circles (default-to (list) (map-get? member-circles creator)))
      (max-allowed (contract-call? .stacksusu-admin-v5 get-max-circles-per-member))
    )
    ;; Validations
    (asserts! (not (contract-call? .stacksusu-admin-v5 is-paused)) ERR-PAUSED)
    (asserts! (< (len creator-circles) max-allowed) ERR-MAX-CIRCLES-REACHED)
    (asserts! (and (>= contribution MIN-CONTRIBUTION) (<= contribution MAX-CONTRIBUTION)) 
              ERR-INVALID-AMOUNT)
    (asserts! (and (>= max-members MIN-MEMBERS) (<= max-members MAX-MEMBERS)) 
              ERR-INVALID-MEMBERS)
    (asserts! (and (>= payout-interval-days u1) (<= payout-interval-days u30)) 
              ERR-INVALID-INTERVAL)
    (asserts! (or (is-eq contribution-mode MODE-UPFRONT) 
                  (is-eq contribution-mode MODE-ROUND-BY-ROUND))
              ERR-INVALID-MODE)
    
    ;; Check creator reputation if required
    (if (contract-call? .stacksusu-admin-v5 is-reputation-required)
      (asserts! (contract-call? .stacksusu-reputation-v5 meets-requirement creator min-reputation)
                ERR-REPUTATION-TOO-LOW)
      true
    )
    
    ;; Create circle
    (map-set circles circle-id
      {
        creator: creator,
        name: name,
        contribution: contribution,
        max-members: max-members,
        payout-interval: payout-interval-blocks,
        status: STATUS-PENDING,
        current-round: u0,
        start-block: u0,
        member-count: u0,
        created-at: block-height,
        contribution-mode: contribution-mode,
        min-reputation: min-reputation,
        total-contributed: u0,
        total-paid-out: u0
      }
    )
    
    ;; Initialize first round status
    (map-set round-status { circle-id: circle-id, round: u0 }
      {
        contributions-received: u0,
        total-amount: u0,
        payout-processed: false,
        recipient: none,
        started-at: block-height
      }
    )
    
    (var-set circle-counter circle-id)
    
    ;; Creator auto-joins
    (try! (internal-join-circle circle-id creator))
    
    ;; Initialize reputation for creator
    (try! (contract-call? .stacksusu-reputation-v5 initialize-member creator))
    
    ;; Record in admin stats
    (try! (contract-call? .stacksusu-admin-v5 increment-circles-created))
    
    (ok circle-id)
  )
)

;; Legacy create-circle (for backwards compatibility)
(define-public (create-circle-simple
    (name (string-ascii 50))
    (contribution uint) 
    (max-members uint) 
    (payout-interval-days uint))
  (create-circle name contribution max-members payout-interval-days MODE-UPFRONT u0)
)


;; ============================================
;; Join Circle
;; ============================================

(define-public (join-circle (circle-id uint))
  (let
    (
      (joiner tx-sender)
      (circle (unwrap! (map-get? circles circle-id) ERR-CIRCLE-NOT-FOUND))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v5 is-paused)) ERR-PAUSED)
    
    ;; Check reputation requirement
    (if (> (get min-reputation circle) u0)
      (asserts! (contract-call? .stacksusu-reputation-v5 meets-requirement joiner (get min-reputation circle))
                ERR-REPUTATION-TOO-LOW)
      true
    )
    
    ;; Initialize reputation
    (try! (contract-call? .stacksusu-reputation-v5 initialize-member joiner))
    
    (internal-join-circle circle-id joiner)
  )
)

;; Join with referral
(define-public (join-circle-with-referral (circle-id uint) (referrer principal))
  (begin
    ;; Register referral first (will fail silently if already referred)
    (match (contract-call? .stacksusu-referral-v5 register-referral referrer)
      success true
      error true
    )
    ;; Then join circle
    (join-circle circle-id)
  )
)

(define-private (internal-join-circle (circle-id uint) (member principal))
  (let
    (
      (circle (unwrap! (map-get? circles circle-id) ERR-CIRCLE-NOT-FOUND))
      (current-count (get member-count circle))
      (slot current-count)
      (member-circle-list (default-to (list) (map-get? member-circles member)))
      (max-allowed (contract-call? .stacksusu-admin-v5 get-max-circles-per-member))
    )
    ;; Validations
    (asserts! (< (len member-circle-list) max-allowed) ERR-MAX-CIRCLES-REACHED)
    (asserts! (< current-count (get max-members circle)) ERR-CIRCLE-FULL)
    (asserts! (is-none (map-get? circle-members { circle-id: circle-id, member: member })) 
              ERR-ALREADY-MEMBER)
    (asserts! (is-eq (get status circle) STATUS-PENDING) ERR-CIRCLE-NOT-ACTIVE)
    
    ;; Add member
    (map-set circle-members 
      { circle-id: circle-id, member: member }
      { 
        slot: slot, 
        joined-at: block-height,
        contributions-made: u0,
        last-contribution-round: u0
      }
    )
    
    (map-set slot-to-member
      { circle-id: circle-id, slot: slot }
      member
    )
    
    (map-set member-circles member 
      (unwrap! (as-max-len? (append member-circle-list circle-id) u20) ERR-MAX-CIRCLES-REACHED)
    )
    
    ;; Update circle status
    (let ((new-count (+ current-count u1)))
      (map-set circles circle-id
        (merge circle { 
          member-count: new-count,
          status: (if (is-eq new-count (get max-members circle)) 
                    STATUS-ACTIVE 
                    STATUS-PENDING),
          start-block: (if (is-eq new-count (get max-members circle))
                         block-height
                         u0)
        })
      )
      
      ;; If circle is now full and active, update round start
      (if (is-eq new-count (get max-members circle))
        (map-set round-status { circle-id: circle-id, round: u0 }
          {
            contributions-received: u0,
            total-amount: u0,
            payout-processed: false,
            recipient: (map-get? slot-to-member { circle-id: circle-id, slot: u0 }),
            started-at: block-height
          }
        )
        true
      )
    )
    
    (ok slot)
  )
)


;; ============================================
;; Start Circle (manual start option)
;; ============================================

(define-public (start-circle (circle-id uint))
  (let
    (
      (circle (unwrap! (map-get? circles circle-id) ERR-CIRCLE-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get creator circle)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status circle) STATUS-PENDING) ERR-CIRCLE-NOT-ACTIVE)
    (asserts! (>= (get member-count circle) MIN-MEMBERS) ERR-CIRCLE-NOT-READY)
    
    ;; Activate circle
    (map-set circles circle-id
      (merge circle {
        status: STATUS-ACTIVE,
        start-block: block-height,
        max-members: (get member-count circle) ;; Lock in current member count
      })
    )
    
    ;; Initialize first round
    (map-set round-status { circle-id: circle-id, round: u0 }
      {
        contributions-received: u0,
        total-amount: u0,
        payout-processed: false,
        recipient: (map-get? slot-to-member { circle-id: circle-id, slot: u0 }),
        started-at: block-height
      }
    )
    
    (ok true)
  )
)


;; ============================================
;; Read-only Functions
;; ============================================

(define-read-only (get-circle-info (circle-id uint))
  (ok (map-get? circles circle-id))
)

(define-read-only (get-circle-count)
  (var-get circle-counter)
)

(define-read-only (get-member-info (circle-id uint) (member principal))
  (ok (map-get? circle-members { circle-id: circle-id, member: member }))
)

(define-read-only (get-member-at-slot (circle-id uint) (slot uint))
  (ok (map-get? slot-to-member { circle-id: circle-id, slot: slot }))
)

(define-read-only (get-my-circles (member principal))
  (ok (default-to (list) (map-get? member-circles member)))
)

(define-read-only (is-member (circle-id uint) (addr principal))
  (is-some (map-get? circle-members { circle-id: circle-id, member: addr }))
)

(define-read-only (get-current-recipient (circle-id uint))
  (let ((circle (map-get? circles circle-id)))
    (match circle
      c (map-get? slot-to-member { circle-id: circle-id, slot: (get current-round c) })
      none
    )
  )
)

(define-read-only (get-round-status (circle-id uint) (round uint))
  (ok (map-get? round-status { circle-id: circle-id, round: round }))
)

(define-read-only (get-round-contribution (circle-id uint) (round uint) (member principal))
  (ok (map-get? round-contributions { circle-id: circle-id, round: round, member: member }))
)

(define-read-only (get-next-payout-block (circle-id uint))
  (let ((circle (map-get? circles circle-id)))
    (match circle
      c (ok (+ (get start-block c) (* (+ (get current-round c) u1) (get payout-interval c))))
      ERR-CIRCLE-NOT-FOUND
    )
  )
)

(define-read-only (get-required-contribution (circle-id uint))
  (let ((circle (map-get? circles circle-id)))
    (match circle
      c (if (is-eq (get contribution-mode c) MODE-UPFRONT)
          (ok (* (get contribution c) (get max-members c)))  ;; Full amount upfront
          (ok (get contribution c)))                          ;; Just one round
      ERR-CIRCLE-NOT-FOUND
    )
  )
)

(define-read-only (is-circle-ready (circle-id uint))
  (let ((circle (map-get? circles circle-id)))
    (match circle
      c (is-eq (get status c) STATUS-ACTIVE)
      false
    )
  )
)

(define-read-only (get-contribution-mode (circle-id uint))
  (match (map-get? circles circle-id)
    c (ok (get contribution-mode c))
    ERR-CIRCLE-NOT-FOUND
  )
)


;; ============================================
;; Slot Management (for NFT transfers)
;; ============================================

(define-public (authorize-slot-updater (updater principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-slot-updaters updater true))
  )
)

(define-public (revoke-slot-updater (updater principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-slot-updaters updater))
  )
)

(define-read-only (is-authorized-slot-updater (caller principal))
  (or (is-eq caller CONTRACT-OWNER) (default-to false (map-get? authorized-slot-updaters caller)))
)

(define-public (update-slot-holder (circle-id uint) (slot uint) (new-holder principal))
  (let
    (
      (circle (unwrap! (map-get? circles circle-id) ERR-CIRCLE-NOT-FOUND))
      (current-member (map-get? slot-to-member { circle-id: circle-id, slot: slot }))
    )
    (asserts! (is-authorized-slot-updater contract-caller) ERR-NOT-AUTHORIZED)
    (asserts! (< slot (get max-members circle)) ERR-INVALID-SLOT)
    
    (map-set slot-to-member { circle-id: circle-id, slot: slot } new-holder)
    
    (match current-member
      old-holder
        (let ((old-member-info (map-get? circle-members { circle-id: circle-id, member: old-holder })))
          (match old-member-info
            info
              (begin
                (map-delete circle-members { circle-id: circle-id, member: old-holder })
                (map-set circle-members 
                  { circle-id: circle-id, member: new-holder }
                  (merge info { slot: slot })
                )
                (ok true)
              )
            (ok true)
          )
        )
      (ok true)
    )
  )
)

;; Update circle stats (called by escrow)
(define-public (update-circle-stats (circle-id uint) (contributed uint) (paid-out uint))
  (let
    (
      (circle (unwrap! (map-get? circles circle-id) ERR-CIRCLE-NOT-FOUND))
    )
    (asserts! (is-authorized-slot-updater contract-caller) ERR-NOT-AUTHORIZED)
    
    (map-set circles circle-id
      (merge circle {
        total-contributed: (+ (get total-contributed circle) contributed),
        total-paid-out: (+ (get total-paid-out circle) paid-out)
      })
    )
    (ok true)
  )
)

;; Advance to next round (called by escrow after payout)
(define-public (advance-round (circle-id uint))
  (let
    (
      (circle (unwrap! (map-get? circles circle-id) ERR-CIRCLE-NOT-FOUND))
      (next-round (+ (get current-round circle) u1))
    )
    (asserts! (is-authorized-slot-updater contract-caller) ERR-NOT-AUTHORIZED)
    
    (if (>= next-round (get max-members circle))
      ;; Circle completed
      (map-set circles circle-id (merge circle { 
        current-round: next-round,
        status: STATUS-COMPLETED 
      }))
      ;; Move to next round
      (begin
        (map-set circles circle-id (merge circle { current-round: next-round }))
        ;; Initialize next round
        (map-set round-status { circle-id: circle-id, round: next-round }
          {
            contributions-received: u0,
            total-amount: u0,
            payout-processed: false,
            recipient: (map-get? slot-to-member { circle-id: circle-id, slot: next-round }),
            started-at: block-height
          }
        )
      )
    )
    (ok next-round)
  )
)


;; ============================================
;; NFT Minting Control
;; ============================================

(define-public (set-nft-minting (enabled bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set nft-minting-enabled enabled))
  )
)

(define-read-only (is-nft-minting-enabled)
  (var-get nft-minting-enabled)
)
