;; StackSusu Core v7
;; Main savings circle contract - simplified, no authorization barriers

(define-constant CONTRACT-OWNER tx-sender)

;; Error constants  
(define-constant ERR-CIRCLE-NOT-FOUND (err u1001))
(define-constant ERR-NOT-MEMBER (err u1002))
(define-constant ERR-ALREADY-MEMBER (err u1003))
(define-constant ERR-CIRCLE-FULL (err u1004))
(define-constant ERR-INVALID-AMOUNT (err u1005))
(define-constant ERR-INVALID-MEMBERS (err u1006))
(define-constant ERR-NOT-CREATOR (err u1007))
(define-constant ERR-INVALID-INTERVAL (err u1008))
(define-constant ERR-CIRCLE-NOT-ACTIVE (err u1009))
(define-constant ERR-ALREADY-CONTRIBUTED (err u1010))
(define-constant ERR-CIRCLE-ACTIVE (err u1011))
(define-constant ERR-NOT-ENOUGH-MEMBERS (err u1012))
(define-constant ERR-PAUSED (err u1021))
(define-constant ERR-TRANSFER-FAILED (err u1017))
(define-constant ERR-SLOT-TAKEN (err u1030))
(define-constant ERR-MAX-CIRCLES-REACHED (err u1031))
(define-constant ERR-INVALID-MODE (err u1032))

;; Circle status
(define-constant STATUS-PENDING u0)
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-COMPLETED u2)
(define-constant STATUS-CANCELLED u3)

;; Contribution modes
(define-constant MODE-MANUAL u0)
(define-constant MODE-SCHEDULED u1)

;; Configuration
(define-constant MIN-MEMBERS u2)
(define-constant MAX-MEMBERS u12)
(define-constant MIN-CONTRIBUTION u100000)      ;; 0.1 STX minimum
(define-constant MAX-CONTRIBUTION u100000000000) ;; 100k STX max
(define-constant BLOCKS-PER-DAY u144)
(define-constant MAX-CIRCLES-PER-MEMBER u20)

;; State
(define-data-var circle-counter uint u0)

;; Circle data
(define-map circles
  uint  ;; circle-id
  {
    creator: principal,
    name: (string-ascii 50),
    description: (string-ascii 200),
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
    current-pot: uint
  }
)

;; Circle membership
(define-map circle-members
  { circle-id: uint, member: principal }
  { 
    slot: uint,
    joined-at: uint,
    contributions-made: uint,
    last-contribution-round: uint
  }
)

;; Slot to member mapping
(define-map slot-to-member
  { circle-id: uint, slot: uint }
  principal
)

;; Round contributions
(define-map round-contributions
  { circle-id: uint, round: uint, member: principal }
  { amount: uint, contributed-at: uint }
)

;; Member's circles
(define-map member-circles
  principal
  (list 20 uint)
)


;; ============================================
;; Create Circle
;; ============================================

(define-public (create-circle 
    (name (string-ascii 50))
    (description (string-ascii 200))
    (contribution uint)
    (max-members uint)
    (payout-interval uint))
  (let
    (
      (creator tx-sender)
      (circle-id (+ (var-get circle-counter) u1))
      (current-circles (default-to (list) (map-get? member-circles creator)))
    )
    ;; Validations
    (asserts! (not (contract-call? .stacksusu-admin-v7 is-paused)) ERR-PAUSED)
    (asserts! (and (>= max-members MIN-MEMBERS) (<= max-members MAX-MEMBERS)) ERR-INVALID-MEMBERS)
    (asserts! (and (>= contribution MIN-CONTRIBUTION) (<= contribution MAX-CONTRIBUTION)) ERR-INVALID-AMOUNT)
    (asserts! (>= payout-interval BLOCKS-PER-DAY) ERR-INVALID-INTERVAL)
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
      contribution-mode: MODE-MANUAL,
      min-reputation: u0,
      total-contributed: u0,
      total-paid-out: u0,
      current-pot: u0
    })
    
    ;; Add creator as first member
    (map-set circle-members { circle-id: circle-id, member: creator }
      { slot: u1, joined-at: block-height, contributions-made: u0, last-contribution-round: u0 })
    (map-set slot-to-member { circle-id: circle-id, slot: u1 } creator)
    
    ;; Track member's circles
    (map-set member-circles creator 
      (unwrap! (as-max-len? (append current-circles circle-id) u20) ERR-MAX-CIRCLES-REACHED))
    
    ;; Initialize reputation
    (try! (contract-call? .stacksusu-reputation-v7 initialize-member creator))
    
    ;; Update admin stats
    (try! (contract-call? .stacksusu-admin-v7 increment-circles))
    
    (var-set circle-counter circle-id)
    (ok circle-id)
  )
)


;; ============================================
;; Join Circle
;; ============================================

(define-public (join-circle (circle-id uint))
  (let
    (
      (circle (unwrap! (map-get? circles circle-id) ERR-CIRCLE-NOT-FOUND))
      (member tx-sender)
      (current-count (get member-count circle))
      (new-slot (+ current-count u1))
      (current-circles (default-to (list) (map-get? member-circles member)))
    )
    ;; Validations
    (asserts! (not (contract-call? .stacksusu-admin-v7 is-paused)) ERR-PAUSED)
    (asserts! (is-eq (get status circle) STATUS-PENDING) ERR-CIRCLE-ACTIVE)
    (asserts! (is-none (map-get? circle-members { circle-id: circle-id, member: member })) ERR-ALREADY-MEMBER)
    (asserts! (< current-count (get max-members circle)) ERR-CIRCLE-FULL)
    (asserts! (< (len current-circles) MAX-CIRCLES-PER-MEMBER) ERR-MAX-CIRCLES-REACHED)
    
    ;; Check reputation requirement
    (let ((rep-score (unwrap! (contract-call? .stacksusu-reputation-v7 get-score member) ERR-NOT-MEMBER)))
      (asserts! (>= rep-score (get min-reputation circle)) ERR-NOT-MEMBER)
    )
    
    ;; Add member
    (map-set circle-members { circle-id: circle-id, member: member }
      { slot: new-slot, joined-at: block-height, contributions-made: u0, last-contribution-round: u0 })
    (map-set slot-to-member { circle-id: circle-id, slot: new-slot } member)
    
    ;; Update circle
    (map-set circles circle-id (merge circle { member-count: new-slot }))
    
    ;; Track member's circles
    (map-set member-circles member 
      (unwrap! (as-max-len? (append current-circles circle-id) u20) ERR-MAX-CIRCLES-REACHED))
    
    ;; Initialize reputation
    (try! (contract-call? .stacksusu-reputation-v7 initialize-member member))
    (try! (contract-call? .stacksusu-reputation-v7 record-circle-join member))
    
    (ok new-slot)
  )
)


;; ============================================
;; Start Circle
;; ============================================

(define-public (start-circle (circle-id uint))
  (let
    (
      (circle (unwrap! (map-get? circles circle-id) ERR-CIRCLE-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get creator circle)) ERR-NOT-CREATOR)
    (asserts! (is-eq (get status circle) STATUS-PENDING) ERR-CIRCLE-ACTIVE)
    (asserts! (>= (get member-count circle) MIN-MEMBERS) ERR-NOT-ENOUGH-MEMBERS)
    
    (map-set circles circle-id (merge circle {
      status: STATUS-ACTIVE,
      start-block: block-height
    }))
    
    (ok true)
  )
)


;; ============================================
;; Contribute
;; ============================================

(define-public (contribute (circle-id uint))
  (let
    (
      (circle (unwrap! (map-get? circles circle-id) ERR-CIRCLE-NOT-FOUND))
      (member tx-sender)
      (member-data (unwrap! (map-get? circle-members { circle-id: circle-id, member: member }) ERR-NOT-MEMBER))
      (round (get current-round circle))
      (contribution-amount (get contribution circle))
      (fee-bps (contract-call? .stacksusu-admin-v7 get-admin-fee-bps))
      (fee (/ (* contribution-amount fee-bps) u10000))
      (net-amount (- contribution-amount fee))
    )
    ;; Validations
    (asserts! (not (contract-call? .stacksusu-admin-v7 is-paused)) ERR-PAUSED)
    (asserts! (is-eq (get status circle) STATUS-ACTIVE) ERR-CIRCLE-NOT-ACTIVE)
    (asserts! (is-none (map-get? round-contributions { circle-id: circle-id, round: round, member: member })) ERR-ALREADY-CONTRIBUTED)
    
    ;; Transfer STX to escrow
    (try! (contract-call? .stacksusu-escrow-v7 deposit circle-id contribution-amount))
    
    ;; Record fee
    (if (> fee u0)
      (try! (contract-call? .stacksusu-admin-v7 record-fee fee))
      true
    )
    
    ;; Record contribution
    (map-set round-contributions { circle-id: circle-id, round: round, member: member }
      { amount: contribution-amount, contributed-at: block-height })
    
    ;; Update member data
    (map-set circle-members { circle-id: circle-id, member: member }
      (merge member-data {
        contributions-made: (+ (get contributions-made member-data) u1),
        last-contribution-round: round
      }))
    
    ;; Update circle pot
    (map-set circles circle-id (merge circle {
      total-contributed: (+ (get total-contributed circle) contribution-amount),
      current-pot: (+ (get current-pot circle) net-amount)
    }))
    
    ;; Update reputation
    (try! (contract-call? .stacksusu-reputation-v7 record-contribution member))
    
    (ok true)
  )
)


;; ============================================
;; Process Payout
;; ============================================

(define-public (process-payout (circle-id uint))
  (let
    (
      (circle (unwrap! (map-get? circles circle-id) ERR-CIRCLE-NOT-FOUND))
      (round (get current-round circle))
      (recipient (unwrap! (map-get? slot-to-member { circle-id: circle-id, slot: round }) ERR-NOT-MEMBER))
      (payout-amount (get current-pot circle))
    )
    ;; Validations
    (asserts! (not (contract-call? .stacksusu-admin-v7 is-paused)) ERR-PAUSED)
    (asserts! (is-eq (get status circle) STATUS-ACTIVE) ERR-CIRCLE-NOT-ACTIVE)
    (asserts! (> payout-amount u0) ERR-INVALID-AMOUNT)
    
    ;; Process payout from escrow
    (try! (contract-call? .stacksusu-escrow-v7 process-payout circle-id recipient payout-amount))
    
    ;; Update circle
    (let
      (
        (new-round (+ round u1))
        (is-complete (> new-round (get member-count circle)))
      )
      (map-set circles circle-id (merge circle {
        current-round: new-round,
        current-pot: u0,
        total-paid-out: (+ (get total-paid-out circle) payout-amount),
        status: (if is-complete STATUS-COMPLETED (get status circle))
      }))
      
      ;; Update stats
      (try! (contract-call? .stacksusu-admin-v7 increment-payouts))
      (try! (contract-call? .stacksusu-reputation-v7 record-payout recipient))
      
      ;; If completed, record for all members
      (if is-complete
        (try! (contract-call? .stacksusu-reputation-v7 record-circle-complete recipient))
        true
      )
      
      (ok payout-amount)
    )
  )
)


;; ============================================
;; Read Functions
;; ============================================

(define-read-only (get-circle (circle-id uint))
  (map-get? circles circle-id)
)

(define-read-only (get-circle-count)
  (var-get circle-counter)
)

(define-read-only (get-member (circle-id uint) (member principal))
  (map-get? circle-members { circle-id: circle-id, member: member })
)

(define-read-only (get-slot-member (circle-id uint) (slot uint))
  (map-get? slot-to-member { circle-id: circle-id, slot: slot })
)

(define-read-only (get-contribution (circle-id uint) (round uint) (member principal))
  (map-get? round-contributions { circle-id: circle-id, round: round, member: member })
)

(define-read-only (get-member-circles (member principal))
  (default-to (list) (map-get? member-circles member))
)

(define-read-only (is-member (circle-id uint) (member principal))
  (is-some (map-get? circle-members { circle-id: circle-id, member: member }))
)

(define-read-only (has-contributed (circle-id uint) (round uint) (member principal))
  (is-some (map-get? round-contributions { circle-id: circle-id, round: round, member: member }))
)
