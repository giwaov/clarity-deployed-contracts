(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-already-voted (err u104))

(define-map members
  {member: principal}
  {voting-power: uint, active: bool}
)

(define-map proposals
  {proposal-id: uint}
  {
    title: (string-ascii 256),
    description: (string-ascii 512),
    proposer: principal,
    votes-for: uint,
    votes-against: uint,
    status: (string-ascii 16),
    created-at: uint,
    ends-at: uint,
    proposal-type: (string-ascii 64)
  }
)

(define-map votes
  {proposal-id: uint, voter: principal}
  {vote: bool, power: uint}
)

(define-data-var proposal-nonce uint u0)
(define-data-var total-voting-power uint u0)

(define-read-only (get-member (member principal))
  (map-get? members {member: member})
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals {proposal-id: proposal-id})
)

(define-public (add-member (member principal) (voting-power uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set members {member: member}
      {voting-power: voting-power, active: true}
    )
    (var-set total-voting-power (+ (var-get total-voting-power) voting-power))
    (ok true)
  )
)

(define-public (create-proposal
  (title (string-ascii 256))
  (description (string-ascii 512))
  (proposal-type (string-ascii 64))
  (duration uint)
)
  (let (
    (member (unwrap! (map-get? members {member: tx-sender}) err-unauthorized))
    (proposal-id (var-get proposal-nonce))
  )
    (asserts! (get active member) err-unauthorized)
    (map-set proposals {proposal-id: proposal-id}
      {
        title: title,
        description: description,
        proposer: tx-sender,
        votes-for: u0,
        votes-against: u0,
        status: "active",
        created-at: stacks-block-height,
        ends-at: (+ stacks-block-height duration),
        proposal-type: proposal-type
      }
    )
    (var-set proposal-nonce (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (vote (proposal-id uint) (vote-for bool))
  (let (
    (proposal (unwrap! (map-get? proposals {proposal-id: proposal-id}) err-not-found))
    (member (unwrap! (map-get? members {member: tx-sender}) err-unauthorized))
  )
    (asserts! (get active member) err-unauthorized)
    (asserts! (is-eq (get status proposal) "active") err-invalid-params)
    (asserts! (< stacks-block-height (get ends-at proposal)) err-invalid-params)
    (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: tx-sender})) err-already-voted)
    (map-set votes {proposal-id: proposal-id, voter: tx-sender}
      {vote: vote-for, power: (get voting-power member)}
    )
    (ok (map-set proposals {proposal-id: proposal-id}
      (merge proposal {
        votes-for: (if vote-for (+ (get votes-for proposal) (get voting-power member)) (get votes-for proposal)),
        votes-against: (if vote-for (get votes-against proposal) (+ (get votes-against proposal) (get voting-power member)))
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
