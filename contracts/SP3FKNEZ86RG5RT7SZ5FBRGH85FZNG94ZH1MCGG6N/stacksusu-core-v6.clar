;; StackSusu Core v6
;; Enhanced circle management with batch operations, delegation, and scheduling

(define-constant CONTRACT-OWNER tx-sender)

;; Circle size limits
(define-constant MIN-MEMBERS u3)
(define-constant MAX-MEMBERS u50)
(define-constant MIN-CONTRIBUTION u10000)        ;; 0.01 STX minimum
(define-constant MAX-CONTRIBUTION u100000000)    ;; 100 STX maximum per round
(define-constant BLOCKS-PER-DAY u144)
(define-constant MAX-CIRCLES-PER-MEMBER u20)

;; Circle status constants
(define-constant STATUS-PENDING u0)      ;; Waiting for members
(define-constant STATUS-ACTIVE u1)       ;; Circle is running rounds
(define-constant STATUS-COMPLETED u2)    ;; All rounds finished
(define-constant STATUS-CANCELLED u3)    ;; Circle was cancelled
(define-constant STATUS-PAUSED u4)       ;; Temporarily paused

;; Contribution mode constants
(define-constant MODE-UPFRONT u0)        ;; All members deposit full amount upfront
(define-constant MODE-ROUND-BY-ROUND u1) ;; Members contribute each round
(define-constant MODE-SCHEDULED u2)      ;; NEW: Auto-scheduled contributions

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
(define-constant ERR-BATCH-TOO-LARGE (err u1050))
(define-constant ERR-NOT-DELEGATED (err u1051))
(define-constant ERR-ALREADY-DELEGATED (err u1052))
(define-constant ERR-SCHEDULE-NOT-DUE (err u1053))

;; Circle counter
(define-data-var circle-counter uint u0)

;; Circle data structure
(define-map circles
  uint
  {
    creator: principal,
    name: (string-ascii 50),
    description: (string-ascii 200),     ;; NEW: Circle description
    contribution: uint,
    max-members: uint,
    payout-interval: uint,
    status: uint,
    current-round: uint,
    start-block: uint,
    member-count: uint,
    created-at: uint,
    contribution-mode: uint,
    min-reputation: uint,
    total-contributed: uint,
    total-paid-out: uint,
    current-pot: uint,                   ;; Current pot balance
    is-private: bool,                    ;; NEW: Private circles require invite
    auto-start: bool                     ;; NEW: Auto-start when full
  }
)

;; Member data
(define-map circle-members
  { circle-id: uint, member: principal }
  { 
    slot: uint, 
    joined-at: uint,
    contributions-made: uint,
    last-contribution-round: uint,
    delegate: (optional principal),      ;; NEW: Delegation support
    auto-contribute: bool                ;; NEW: Auto-contribution flag
  }
)

;; Slot to member mapping
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
  { amount: uint, contributed-at: uint, is-late: bool, delegated-by: (optional principal) }
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

;; Delegation mappings
(define-map contribution-delegates
  { circle-id: uint, member: principal }
  { delegate: principal, authorized-at: uint, max-amount: uint, last-contribution: uint }
)

;; Private circle invites
(define-map circle-invites
  { circle-id: uint, invitee: principal }
  { invited-by: principal, invited-at: uint, accepted: bool }
)

;; Scheduled contributions
(define-map scheduled-contributions
  { circle-id: uint, member: principal }
  { next-block: uint, amount: uint, enabled: bool }
)


;; ============================================
;; Circle Creation
;; ============================================

(define-public (create-circle 
    (name (string-ascii 50))
    (description (string-ascii 200))
    (contribution uint)
    (max-members uint)
    (payout-interval uint)
    (contribution-mode uint)
    (min-reputation uint)
    (is-private bool)
    (auto-start bool))
  (let
    (
      (creator tx-sender)
      (circle-id (+ (var-get circle-counter) u1))
      (current-circles (default-to (list) (map-get? member-circles creator)))
    )
    ;; Validations
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (and (>= max-members MIN-MEMBERS) (<= max-members MAX-MEMBERS)) ERR-INVALID-MEMBERS)
    (asserts! (and (>= contribution MIN-CONTRIBUTION) (<= contribution MAX-CONTRIBUTION)) ERR-INVALID-AMOUNT)
    (asserts! (>= payout-interval BLOCKS-PER-DAY) ERR-INVALID-INTERVAL)
    (asserts! (<= contribution-mode MODE-SCHEDULED) ERR-INVALID-MODE)
    (asserts! (< (len current-circles) MAX-CIRCLES-PER-MEMBER) ERR-MAX-CIRCLES-REACHED)
    
    ;; Create circle
    (map-set circles circle-id {
      creator: creator,
      name: name,
      description: description,
      contribution: contribution,
      max-members: max-members,
      payout-interval: payout-interval,
      status: STATUS-PENDING,
      current-round: u1,
      start-block: u0,
      member-count: u1,
      created-at: block-height,
      contribution-mode: contribution-mode,
      min-reputation: min-reputation,
      total-contributed: u0,
      total-paid-out: u0,
      current-pot: u0,
      is-private: is-private,
      auto-start: auto-start
    })
    
    ;; Add creator as first member
    (map-set circle-members { circle-id: circle-id, member: creator }
      { slot: u1, joined-at: block-height, contributions-made: u0, 
        last-contribution-round: u0, delegate: none, auto-contribute: false })
    (map-set slot-to-member { circle-id: circle-id, slot: u1 } creator)
    
    ;; Track member's circles
    (map-set member-circles creator 
      (unwrap! (as-max-len? (append current-circles circle-id) u20) ERR-MAX-CIRCLES-REACHED))
    
    ;; Initialize reputation
    (try! (contract-call? .stacksusu-reputation-v6 initialize-member creator))
    
    ;; Update admin stats
    (try! (contract-call? .stacksusu-admin-v6 increment-circles))
    
    (var-set circle-counter circle-id)
    (ok circle-id)
  )
)


;; ============================================
;; Join Circle
;; ============================================

(define-public (join-circle (circle-id uint) (preferred-slot uint))
  (let
    (
      (member tx-sender)
      (circle (unwrap! (map-get? circles circle-id) ERR-CIRCLE-NOT-FOUND))
      (current-circles (default-to (list) (map-get? member-circles member)))
      (member-count (get member-count circle))
      (next-slot (if (is-eq preferred-slot u0) (+ member-count u1) preferred-slot))
    )
    ;; Validations
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (is-eq (get status circle) STATUS-PENDING) ERR-CIRCLE-NOT-ACTIVE)
    (asserts! (< member-count (get max-members circle)) ERR-CIRCLE-FULL)
    (asserts! (is-none (map-get? circle-members { circle-id: circle-id, member: member })) ERR-ALREADY-MEMBER)
    (asserts! (< (len current-circles) MAX-CIRCLES-PER-MEMBER) ERR-MAX-CIRCLES-REACHED)
    
    ;; Check private circle invite
    (if (get is-private circle)
      (asserts! (is-invited circle-id member) ERR-NOT-AUTHORIZED)
      true
    )
    
    ;; Check reputation requirement
    (if (> (get min-reputation circle) u0)
      (asserts! (contract-call? .stacksusu-reputation-v6 meets-requirement member (get min-reputation circle))
                ERR-REPUTATION-TOO-LOW)
      true
    )
    
    ;; Validate slot
    (asserts! (and (> next-slot u0) (<= next-slot (get max-members circle))) ERR-INVALID-SLOT)
    (asserts! (is-none (map-get? slot-to-member { circle-id: circle-id, slot: next-slot })) ERR-INVALID-SLOT)
    
    ;; Add member
    (map-set circle-members { circle-id: circle-id, member: member }
      { slot: next-slot, joined-at: block-height, contributions-made: u0,
        last-contribution-round: u0, delegate: none, auto-contribute: false })
    (map-set slot-to-member { circle-id: circle-id, slot: next-slot } member)
    
    ;; Update circle
    (map-set circles circle-id (merge circle { member-count: (+ member-count u1) }))
    
    ;; Track member's circles
    (map-set member-circles member
      (unwrap! (as-max-len? (append current-circles circle-id) u20) ERR-MAX-CIRCLES-REACHED))
    
    ;; Initialize reputation
    (try! (contract-call? .stacksusu-reputation-v6 initialize-member member))
    
    ;; Mark invite as accepted if private
    (if (get is-private circle)
      (map-set circle-invites { circle-id: circle-id, invitee: member }
        { invited-by: (get creator circle), invited-at: block-height, accepted: true })
      true
    )
    
    ;; Auto-start if enabled and full
    (if (and (get auto-start circle) (is-eq (+ member-count u1) (get max-members circle)))
      (start-circle-internal circle-id)
      (ok true)
    )
  )
)


;; ============================================
;; Batch Join (NEW in v6)
;; ============================================

(define-public (batch-join-circle (circle-id uint) (members (list 10 principal)))
  (let
    (
      (caller tx-sender)
      (circle (unwrap! (map-get? circles circle-id) ERR-CIRCLE-NOT-FOUND))
    )
    (asserts! (is-eq caller (get creator circle)) ERR-NOT-AUTHORIZED)
    (asserts! (<= (len members) u10) ERR-BATCH-TOO-LARGE)
    (asserts! (is-eq (get status circle) STATUS-PENDING) ERR-CIRCLE-NOT-ACTIVE)
    
    ;; Send invites to all members
    (map add-batch-invite (list circle-id circle-id circle-id circle-id circle-id 
                                 circle-id circle-id circle-id circle-id circle-id)
         members
         (list caller caller caller caller caller caller caller caller caller caller))
    
    (ok true)
  )
)

(define-private (add-batch-invite (circle-id uint) (invitee principal) (inviter principal))
  (map-set circle-invites { circle-id: circle-id, invitee: invitee }
    { invited-by: inviter, invited-at: block-height, accepted: false })
)


;; ============================================
;; Delegation Functions (NEW in v6)
;; ============================================

(define-public (delegate-contributions (circle-id uint) (delegate principal) (max-amount uint))
  (let
    (
      (member tx-sender)
      (member-info (unwrap! (map-get? circle-members { circle-id: circle-id, member: member }) ERR-NOT-MEMBER))
    )
    (asserts! (is-none (get delegate member-info)) ERR-ALREADY-DELEGATED)
    (asserts! (not (is-eq member delegate)) ERR-NOT-AUTHORIZED)
    
    (map-set contribution-delegates { circle-id: circle-id, member: member }
      { delegate: delegate, authorized-at: block-height, max-amount: max-amount, last-contribution: u0 })
    
    (map-set circle-members { circle-id: circle-id, member: member }
      (merge member-info { delegate: (some delegate) }))
    
    (ok true)
  )
)

(define-public (revoke-delegation (circle-id uint))
  (let
    (
      (member tx-sender)
      (member-info (unwrap! (map-get? circle-members { circle-id: circle-id, member: member }) ERR-NOT-MEMBER))
    )
    (map-delete contribution-delegates { circle-id: circle-id, member: member })
    (map-set circle-members { circle-id: circle-id, member: member }
      (merge member-info { delegate: none }))
    (ok true)
  )
)

(define-public (contribute-as-delegate (circle-id uint) (member principal) (amount uint))
  (let
    (
      (delegate tx-sender)
      (delegation (unwrap! (map-get? contribution-delegates { circle-id: circle-id, member: member }) ERR-NOT-DELEGATED))
      (member-info (unwrap! (map-get? circle-members { circle-id: circle-id, member: member }) ERR-NOT-MEMBER))
      (circle (unwrap! (map-get? circles circle-id) ERR-CIRCLE-NOT-FOUND))
    )
    (asserts! (is-eq delegate (get delegate delegation)) ERR-NOT-DELEGATED)
    (asserts! (<= amount (get max-amount delegation)) ERR-INVALID-AMOUNT)
    
    ;; Mark delegation as used - actual payment handled by escrow contract
    (map-set contribution-delegates { circle-id: circle-id, member: member }
      (merge delegation { last-contribution: block-height })
    )
    
    (ok { circle-id: circle-id, member: member, delegate: delegate, amount: amount })
  )
)


;; ============================================
;; Scheduled Contributions (NEW in v6)
;; ============================================

(define-public (setup-auto-contribute (circle-id uint) (amount uint))
  (let
    (
      (member tx-sender)
      (member-info (unwrap! (map-get? circle-members { circle-id: circle-id, member: member }) ERR-NOT-MEMBER))
      (circle (unwrap! (map-get? circles circle-id) ERR-CIRCLE-NOT-FOUND))
    )
    (map-set scheduled-contributions { circle-id: circle-id, member: member }
      { next-block: (+ block-height (get payout-interval circle)), amount: amount, enabled: true })
    
    (map-set circle-members { circle-id: circle-id, member: member }
      (merge member-info { auto-contribute: true }))
    
    (ok true)
  )
)

(define-public (disable-auto-contribute (circle-id uint))
  (let
    (
      (member tx-sender)
      (member-info (unwrap! (map-get? circle-members { circle-id: circle-id, member: member }) ERR-NOT-MEMBER))
    )
    (map-delete scheduled-contributions { circle-id: circle-id, member: member })
    (map-set circle-members { circle-id: circle-id, member: member }
      (merge member-info { auto-contribute: false }))
    (ok true)
  )
)


;; ============================================
;; Circle Management
;; ============================================

(define-public (start-circle (circle-id uint))
  (let
    (
      (circle (unwrap! (map-get? circles circle-id) ERR-CIRCLE-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get creator circle)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status circle) STATUS-PENDING) ERR-CIRCLE-NOT-ACTIVE)
    (asserts! (is-eq (get member-count circle) (get max-members circle)) ERR-CIRCLE-NOT-READY)
    
    (start-circle-internal circle-id)
  )
)

(define-private (start-circle-internal (circle-id uint))
  (let
    (
      (circle (unwrap! (map-get? circles circle-id) ERR-CIRCLE-NOT-FOUND))
    )
    (map-set circles circle-id (merge circle {
      status: STATUS-ACTIVE,
      start-block: block-height
    }))
    
    ;; Initialize first round
    (map-set round-status { circle-id: circle-id, round: u1 }
      { contributions-received: u0, total-amount: u0, payout-processed: false, 
        recipient: none, started-at: block-height })
    
    (ok true)
  )
)

(define-public (update-slot-holder (circle-id uint) (slot uint) (new-holder principal))
  (begin
    (asserts! (contract-call? .stacksusu-admin-v6 is-authorized-contract contract-caller) ERR-NOT-AUTHORIZED)
    (map-set slot-to-member { circle-id: circle-id, slot: slot } new-holder)
    (ok true)
  )
)


;; ============================================
;; Read-Only Functions
;; ============================================

(define-read-only (get-circle-info (circle-id uint))
  (ok (map-get? circles circle-id))
)

(define-read-only (is-member (circle-id uint) (member principal))
  (is-some (map-get? circle-members { circle-id: circle-id, member: member }))
)

(define-read-only (get-member-info (circle-id uint) (member principal))
  (map-get? circle-members { circle-id: circle-id, member: member })
)

(define-read-only (get-member-slot (circle-id uint) (member principal))
  (match (map-get? circle-members { circle-id: circle-id, member: member })
    member-data (ok (get slot member-data))
    ERR-NOT-MEMBER
  )
)

(define-read-only (get-slot-holder (circle-id uint) (slot uint))
  (map-get? slot-to-member { circle-id: circle-id, slot: slot })
)

(define-read-only (get-member-circles (member principal))
  (default-to (list) (map-get? member-circles member))
)

(define-read-only (is-invited (circle-id uint) (member principal))
  (match (map-get? circle-invites { circle-id: circle-id, invitee: member })
    invite (not (get accepted invite))
    false
  )
)

(define-read-only (get-circle-count)
  (var-get circle-counter)
)

(define-read-only (get-round-status (circle-id uint) (round uint))
  (map-get? round-status { circle-id: circle-id, round: round })
)

(define-read-only (get-delegation (circle-id uint) (member principal))
  (map-get? contribution-delegates { circle-id: circle-id, member: member })
)

(define-read-only (get-scheduled-contribution (circle-id uint) (member principal))
  (map-get? scheduled-contributions { circle-id: circle-id, member: member })
)
