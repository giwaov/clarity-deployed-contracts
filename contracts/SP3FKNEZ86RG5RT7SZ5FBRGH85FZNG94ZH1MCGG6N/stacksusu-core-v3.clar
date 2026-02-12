(define-constant CONTRACT-OWNER tx-sender)

(define-constant MIN-MEMBERS u25)
(define-constant MAX-MEMBERS u50)
(define-constant MIN-CONTRIBUTION u500000)
(define-constant MAX-CONTRIBUTION u10000000)
(define-constant BLOCKS-PER-DAY u144)

(define-constant STATUS-PENDING u0)
(define-constant STATUS-FUNDING u1)
(define-constant STATUS-ACTIVE u2)
(define-constant STATUS-COMPLETED u3)
(define-constant STATUS-CANCELLED u4)

(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-CIRCLE-NOT-FOUND (err u1001))
(define-constant ERR-CIRCLE-FULL (err u1002))
(define-constant ERR-CIRCLE-NOT-FULL (err u1003))
(define-constant ERR-ALREADY-MEMBER (err u1004))
(define-constant ERR-NOT-MEMBER (err u1005))
(define-constant ERR-INVALID-AMOUNT (err u1006))
(define-constant ERR-INVALID-MEMBERS (err u1007))
(define-constant ERR-INVALID-INTERVAL (err u1008))
(define-constant ERR-DEPOSITS-INCOMPLETE (err u1011))
(define-constant ERR-PAYOUT-NOT-DUE (err u1012))
(define-constant ERR-ALREADY-CLAIMED (err u1013))
(define-constant ERR-NOT-YOUR-TURN (err u1014))
(define-constant ERR-CIRCLE-NOT-ACTIVE (err u1015))
(define-constant ERR-CIRCLE-COMPLETED (err u1016))
(define-constant ERR-PAUSED (err u1021))
(define-constant ERR-INVALID-SLOT (err u1022))

(define-map circles
  uint
  {
    creator: principal,
    name: (string-ascii 50),
    contribution: uint,
    max-members: uint,
    payout-interval: uint,
    status: uint,
    current-round: uint,
    start-block: uint,
    member-count: uint,
    created-at: uint
  }
)

(define-map circle-members
  { circle-id: uint, member: principal }
  { slot: uint, joined-at: uint }
)

(define-map slot-to-member
  { circle-id: uint, slot: uint }
  principal
)

(define-map member-circles
  principal
  (list 20 uint)
)

(define-data-var circle-counter uint u0)

(define-data-var nft-minting-enabled bool true)

(define-map authorized-slot-updaters principal bool)


(define-public (create-circle 
    (name (string-ascii 50))
    (contribution uint) 
    (max-members uint) 
    (payout-interval-days uint))
  (let
    (
      (creator tx-sender)
      (circle-id (+ (var-get circle-counter) u1))
      (payout-interval-blocks (* payout-interval-days BLOCKS-PER-DAY))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v3 is-paused)) ERR-PAUSED)
    (asserts! (and (>= contribution MIN-CONTRIBUTION) (<= contribution MAX-CONTRIBUTION)) 
              ERR-INVALID-AMOUNT)
    (asserts! (and (>= max-members MIN-MEMBERS) (<= max-members MAX-MEMBERS)) 
              ERR-INVALID-MEMBERS)
    (asserts! (and (>= payout-interval-days u1) (<= payout-interval-days u30)) 
              ERR-INVALID-INTERVAL)
    
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
        created-at: block-height
      }
    )
    
    (var-set circle-counter circle-id)
    (try! (internal-join-circle circle-id creator))
    (ok circle-id)
  )
)


(define-private (internal-join-circle (circle-id uint) (member principal))
  (let
    (
      (circle (unwrap! (map-get? circles circle-id) ERR-CIRCLE-NOT-FOUND))
      (current-count (get member-count circle))
      (slot current-count)
      (member-circle-list (default-to (list) (map-get? member-circles member)))
    )
    (asserts! (< current-count (get max-members circle)) ERR-CIRCLE-FULL)
    (asserts! (is-none (map-get? circle-members { circle-id: circle-id, member: member })) 
              ERR-ALREADY-MEMBER)
    (asserts! (<= (get status circle) STATUS-FUNDING) ERR-CIRCLE-NOT-ACTIVE)
    
    (map-set circle-members 
      { circle-id: circle-id, member: member }
      { slot: slot, joined-at: block-height }
    )
    
    (map-set slot-to-member
      { circle-id: circle-id, slot: slot }
      member
    )
    
    (map-set member-circles member 
      (unwrap! (as-max-len? (append member-circle-list circle-id) u20) ERR-CIRCLE-FULL)
    )
    
    (let ((new-count (+ current-count u1)))
      (map-set circles circle-id
        (merge circle { 
          member-count: new-count,
          status: (if (is-eq new-count (get max-members circle)) 
                    STATUS-FUNDING 
                    STATUS-PENDING)
        })
      )
    )
    
    (ok slot)
  )
)

(define-public (join-circle (circle-id uint))
  (begin
    (asserts! (not (contract-call? .stacksusu-admin-v3 is-paused)) ERR-PAUSED)
    (internal-join-circle circle-id tx-sender)
  )
)


(define-public (deposit-to-circle (circle-id uint))
  (let
    (
      (circle (unwrap! (map-get? circles circle-id) ERR-CIRCLE-NOT-FOUND))
      (member-info (unwrap! (map-get? circle-members { circle-id: circle-id, member: tx-sender }) 
                           ERR-NOT-MEMBER))
      (required-deposit (* (get contribution circle) (get max-members circle)))
    )
    (asserts! (is-eq (get status circle) STATUS-FUNDING) ERR-CIRCLE-NOT-ACTIVE)
    
    (try! (contract-call? .stacksusu-escrow-v3 deposit circle-id required-deposit true))
    
    (let
      (
        (deposit-status (unwrap-panic (contract-call? .stacksusu-escrow-v3 get-circle-deposit-status circle-id)))
      )
      (if (is-eq (get deposit-count deposit-status) (get max-members circle))
        (begin
          (map-set circles circle-id
            (merge circle {
              status: STATUS-ACTIVE,
              start-block: block-height
            })
          )
          (ok true)
        )
        (ok true)
      )
    )
  )
)


(define-public (claim-payout (circle-id uint))
  (let
    (
      (circle (unwrap! (map-get? circles circle-id) ERR-CIRCLE-NOT-FOUND))
      (caller tx-sender)
      (member-info (unwrap! (map-get? circle-members { circle-id: circle-id, member: caller }) 
                           ERR-NOT-MEMBER))
      (current-round (get current-round circle))
      (payout-interval (get payout-interval circle))
      (start-block (get start-block circle))
      (contribution (get contribution circle))
      (max-members (get max-members circle))
      (total-pot (* contribution max-members))
      (admin-fee-bps (contract-call? .stacksusu-admin-v3 get-admin-fee-bps))
      (admin-fee (/ (* total-pot admin-fee-bps) u10000))
    )
    (asserts! (is-eq (get status circle) STATUS-ACTIVE) ERR-CIRCLE-NOT-ACTIVE)
    (asserts! (is-eq (get slot member-info) current-round) ERR-NOT-YOUR-TURN)
    
    (let ((blocks-since-start (- block-height start-block)))
      (asserts! (>= blocks-since-start (* current-round payout-interval)) ERR-PAYOUT-NOT-DUE)
    )
    
    (asserts! (not (contract-call? .stacksusu-escrow-v3 has-received-payout circle-id caller)) 
              ERR-ALREADY-CLAIMED)
    
    (let ((payout-result (try! (contract-call? .stacksusu-escrow-v3 process-payout 
                                 circle-id current-round caller total-pot admin-fee))))
      (let ((next-round (+ current-round u1)))
        (if (>= next-round max-members)
          (map-set circles circle-id (merge circle { 
            current-round: next-round,
            status: STATUS-COMPLETED 
          }))
          (map-set circles circle-id (merge circle { current-round: next-round }))
        )
      )
      (ok payout-result)
    )
  )
)


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

(define-read-only (get-next-payout-block (circle-id uint))
  (let ((circle (map-get? circles circle-id)))
    (match circle
      c (ok (+ (get start-block c) (* (get current-round c) (get payout-interval c))))
      ERR-CIRCLE-NOT-FOUND
    )
  )
)

(define-read-only (get-required-deposit (circle-id uint))
  (let ((circle (map-get? circles circle-id)))
    (match circle
      c (ok (* (get contribution c) (get max-members c)))
      ERR-CIRCLE-NOT-FOUND
    )
  )
)

(define-read-only (is-circle-ready (circle-id uint))
  (let ((circle (map-get? circles circle-id)))
    (match circle
      c (and (is-eq (get status c) STATUS-ACTIVE) (is-eq (get member-count c) (get max-members c)))
      false
    )
  )
)


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
                  { slot: slot, joined-at: (get joined-at info) }
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

(define-public (set-nft-minting (enabled bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set nft-minting-enabled enabled))
  )
)

(define-read-only (is-nft-minting-enabled)
  (var-get nft-minting-enabled)
)
