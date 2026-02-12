;; DAO Governance Contract

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-voted (err u102))
(define-constant err-voting-closed (err u103))

(define-data-var next-proposal-id uint u1)
(define-data-var voting-period uint u1440)

(define-map proposals
  uint
  {
    proposer: principal,
    title: (string-ascii 256),
    votes-for: uint,
    votes-against: uint,
    start-block: uint,
    end-block: uint,
    executed: bool
  }
)

(define-map votes { proposal-id: uint, voter: principal } bool)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-public (create-proposal (title (string-ascii 256)))
  (let ((proposal-id (var-get next-proposal-id)))
    (map-set proposals proposal-id {
      proposer: tx-sender,
      title: title,
      votes-for: u0,
      votes-against: u0,
      start-block: block-height,
      end-block: (+ block-height (var-get voting-period)),
      executed: false
    })
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (vote (proposal-id uint) (vote-for bool))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-not-found)))
    (asserts! (< block-height (get end-block proposal)) err-voting-closed)
    (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) err-already-voted)
    (map-set votes { proposal-id: proposal-id, voter: tx-sender } true)
    (if vote-for
      (map-set proposals proposal-id (merge proposal { votes-for: (+ (get votes-for proposal) u1) }))
      (map-set proposals proposal-id (merge proposal { votes-against: (+ (get votes-against proposal) u1) }))
    )
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-not-found)))
    (asserts! (>= block-height (get end-block proposal)) (err u104))
    (asserts! (not (get executed proposal)) (err u105))
    (asserts! (> (get votes-for proposal) (get votes-against proposal)) (err u106))
    (map-set proposals proposal-id (merge proposal { executed: true }))
    (ok true)
  )
)
