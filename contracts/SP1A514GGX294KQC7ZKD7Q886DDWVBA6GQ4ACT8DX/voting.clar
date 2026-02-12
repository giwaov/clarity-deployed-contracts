;; title: voting
;; version: 1.0
;; summary: Basic democratic voting contract
;; description: One-person-one-vote system with multiple rounds support

;; Error constants
(define-constant err-not-authorized (err u100))
(define-constant err-round-not-found (err u101))
(define-constant err-round-closed (err u102))
(define-constant err-invalid-proposal (err u103))
(define-constant err-already-voted (err u104))

;; Contract owner (deployer)
(define-data-var contract-owner principal tx-sender)

;; Data maps
(define-map rounds uint {
  open: bool
})

(define-map proposals {round-id: uint, proposal-id: uint} {
  owner: principal,
  votes: uint
})

(define-map has-voted {voter: principal, round-id: uint, proposal-id: uint} bool)

;; Admin function to open a round
(define-public (open-round (round-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-not-authorized)
    (map-set rounds round-id {open: true})
    (ok round-id)
  )
)

;; Admin function to close a round
(define-public (close-round (round-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-not-authorized)
    (asserts! (is-some (map-get? rounds round-id)) err-round-not-found)
    (map-set rounds round-id {open: false})
    (ok round-id)
  )
)

;; Register a proposal
(define-public (register-proposal (round-id uint) (proposal-id uint))
  (begin
    (asserts! (is-none (map-get? proposals {round-id: round-id, proposal-id: proposal-id})) err-invalid-proposal)
    (map-set proposals {round-id: round-id, proposal-id: proposal-id} {
      owner: tx-sender,
      votes: u0
    })
    (ok proposal-id)
  )
)

;; Cast a vote (one vote per person per proposal)
(define-public (vote (round-id uint) (proposal-id uint))
  (let (
        (round (map-get? rounds round-id))
        (proposal (map-get? proposals {round-id: round-id, proposal-id: proposal-id}))
        (voted (default-to false (map-get? has-voted {voter: tx-sender, round-id: round-id, proposal-id: proposal-id})))
       )
    (begin
      (asserts! (is-some round) err-round-not-found)
      (asserts! (get open (unwrap! round err-round-not-found)) err-round-closed)
      (asserts! (is-some proposal) err-invalid-proposal)
      (asserts! (not voted) err-already-voted)

      ;; Mark as voted
      (map-set has-voted {voter: tx-sender, round-id: round-id, proposal-id: proposal-id} true)

      ;; Add vote
      (map-set proposals {round-id: round-id, proposal-id: proposal-id} {
        owner: (get owner (unwrap! proposal err-invalid-proposal)),
        votes: (+ (get votes (unwrap! proposal err-invalid-proposal)) u1)
      })

      (ok true)
    )
  )
)

;; Read-only functions
(define-read-only (get-proposal (round-id uint) (proposal-id uint))
  (map-get? proposals {round-id: round-id, proposal-id: proposal-id})
)

(define-read-only (get-round-status (round-id uint))
  (map-get? rounds round-id)
)

(define-read-only (has-voter-voted (round-id uint) (proposal-id uint) (voter principal))
  (default-to false (map-get? has-voted {voter: voter, round-id: round-id, proposal-id: proposal-id}))
)

(define-read-only (is-contract-owner (caller principal))
  (is-eq caller (var-get contract-owner))
)
