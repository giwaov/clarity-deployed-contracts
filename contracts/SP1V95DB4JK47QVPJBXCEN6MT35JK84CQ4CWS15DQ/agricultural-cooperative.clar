(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-not-member (err u104))

(define-map members
  {member-id: principal}
  {
    name: (string-ascii 128),
    join-date: uint,
    shares: uint,
    active: bool,
    contribution: uint
  }
)

(define-map proposals
  {proposal-id: uint}
  {
    title: (string-ascii 256),
    proposer: principal,
    votes-for: uint,
    votes-against: uint,
    status: (string-ascii 16),
    created-at: uint,
    ends-at: uint
  }
)

(define-map votes
  {proposal-id: uint, voter: principal}
  {vote: bool, shares: uint}
)

(define-data-var total-shares uint u0)
(define-data-var proposal-nonce uint u0)
(define-data-var treasury-balance uint u0)

(define-read-only (get-member (member-id principal))
  (map-get? members {member-id: member-id})
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals {proposal-id: proposal-id})
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes {proposal-id: proposal-id, voter: voter})
)

(define-public (join-cooperative (name (string-ascii 128)) (initial-contribution uint))
  (begin
    (asserts! (> initial-contribution u0) err-invalid-params)
    (map-set members {member-id: tx-sender}
      {
        name: name,
        join-date: stacks-block-height,
        shares: initial-contribution,
        active: true,
        contribution: initial-contribution
      }
    )
    (var-set total-shares (+ (var-get total-shares) initial-contribution))
    (ok true)
  )
)

(define-public (add-contribution (amount uint))
  (let ((member (unwrap! (map-get? members {member-id: tx-sender}) err-not-member)))
    (asserts! (get active member) err-unauthorized)
    (asserts! (> amount u0) err-invalid-params)
    (map-set members {member-id: tx-sender}
      (merge member {
        shares: (+ (get shares member) amount),
        contribution: (+ (get contribution member) amount)
      })
    )
    (var-set total-shares (+ (var-get total-shares) amount))
    (ok true)
  )
)

(define-public (create-proposal
  (title (string-ascii 256))
  (duration uint)
)
  (let (
    (member (unwrap! (map-get? members {member-id: tx-sender}) err-not-member))
    (proposal-id (var-get proposal-nonce))
  )
    (asserts! (get active member) err-unauthorized)
    (map-set proposals {proposal-id: proposal-id}
      {
        title: title,
        proposer: tx-sender,
        votes-for: u0,
        votes-against: u0,
        status: "active",
        created-at: stacks-block-height,
        ends-at: (+ stacks-block-height duration)
      }
    )
    (var-set proposal-nonce (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let (
    (proposal (unwrap! (map-get? proposals {proposal-id: proposal-id}) err-not-found))
    (member (unwrap! (map-get? members {member-id: tx-sender}) err-not-member))
  )
    (asserts! (get active member) err-unauthorized)
    (asserts! (is-eq (get status proposal) "active") err-invalid-params)
    (asserts! (< stacks-block-height (get ends-at proposal)) err-invalid-params)
    (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: tx-sender})) err-invalid-params)
    (map-set votes {proposal-id: proposal-id, voter: tx-sender}
      {vote: vote-for, shares: (get shares member)}
    )
    (ok (map-set proposals {proposal-id: proposal-id}
      (merge proposal {
        votes-for: (if vote-for (+ (get votes-for proposal) (get shares member)) (get votes-for proposal)),
        votes-against: (if vote-for (get votes-against proposal) (+ (get votes-against proposal) (get shares member)))
      })
    ))
  )
)

(define-public (finalize-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals {proposal-id: proposal-id}) err-not-found)))
    (asserts! (>= stacks-block-height (get ends-at proposal)) err-invalid-params)
    (ok (map-set proposals {proposal-id: proposal-id}
      (merge proposal {
        status: (if (> (get votes-for proposal) (get votes-against proposal)) "passed" "rejected")
      })
    ))
  )
)
