;; QuickPoll Contract - Earn 0.001 STX per interaction
;; Contract 3 of 3 for Stacks Transaction Hub

;; Constants
(define-constant contract-owner tx-sender)
(define-constant interaction-fee u1000) ;; 0.001 STX = 1000 microSTX
(define-constant err-already-voted (err u100))
(define-constant err-poll-not-found (err u101))
(define-constant err-poll-ended (err u102))
(define-constant err-not-creator (err u103))
(define-constant err-no-poll (err u104))

;; Data Variables
(define-data-var poll-counter uint u0)
(define-data-var total-votes uint u0)
(define-data-var total-fees-collected uint u0)

;; Data Maps
(define-map polls uint {
  question: (string-ascii 100),
  yes-votes: uint,
  no-votes: uint,
  created-at: uint,
  creator: principal,
  active: bool
})

(define-map user-votes { poll-id: uint, voter: principal } bool)
(define-map user-vote-count principal uint)

;; Private function to collect fee
(define-private (collect-fee)
  (begin
    (try! (stx-transfer? interaction-fee tx-sender contract-owner))
    (var-set total-fees-collected (+ (var-get total-fees-collected) interaction-fee))
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-poll (poll-id uint))
  (map-get? polls poll-id)
)

(define-read-only (get-poll-count)
  (var-get poll-counter)
)

(define-read-only (get-total-votes)
  (var-get total-votes)
)

(define-read-only (get-total-fees-collected)
  (var-get total-fees-collected)
)

(define-read-only (get-interaction-fee)
  interaction-fee
)

(define-read-only (get-user-vote-count (user principal))
  (default-to u0 (map-get? user-vote-count user))
)

(define-read-only (has-voted (poll-id uint) (voter principal))
  (is-some (map-get? user-votes { poll-id: poll-id, voter: voter }))
)

(define-read-only (get-latest-poll)
  (let ((latest-id (var-get poll-counter)))
    (if (> latest-id u0)
      (map-get? polls (- latest-id u1))
      none
    )
  )
)

(define-read-only (get-stats)
  {
    poll-count: (var-get poll-counter),
    total-votes: (var-get total-votes),
    fees-collected: (var-get total-fees-collected)
  }
)

;; Public functions - Each call costs 0.001 STX

;; Create a new poll - costs 0.001 STX
(define-public (create-poll (question (string-ascii 100)))
  (let
    (
      (poll-id (var-get poll-counter))
    )
    ;; Collect fee first
    (try! (collect-fee))
    ;; Create the poll
    (map-set polls poll-id {
      question: question,
      yes-votes: u0,
      no-votes: u0,
      created-at: block-height,
      creator: tx-sender,
      active: true
    })
    ;; Increment counter
    (var-set poll-counter (+ poll-id u1))
    (ok poll-id)
  )
)

;; Vote yes on a poll - costs 0.001 STX
(define-public (vote-yes (poll-id uint))
  (let
    (
      (poll (unwrap! (map-get? polls poll-id) err-poll-not-found))
      (current-user-votes (get-user-vote-count tx-sender))
    )
    ;; Check not already voted
    (asserts! (not (has-voted poll-id tx-sender)) err-already-voted)
    ;; Check poll is active
    (asserts! (get active poll) err-poll-ended)
    ;; Collect fee
    (try! (collect-fee))
    ;; Record vote
    (map-set user-votes { poll-id: poll-id, voter: tx-sender } true)
    ;; Update poll
    (map-set polls poll-id (merge poll { yes-votes: (+ (get yes-votes poll) u1) }))
    ;; Update user stats
    (map-set user-vote-count tx-sender (+ current-user-votes u1))
    (var-set total-votes (+ (var-get total-votes) u1))
    (ok true)
  )
)

;; Vote no on a poll - costs 0.001 STX
(define-public (vote-no (poll-id uint))
  (let
    (
      (poll (unwrap! (map-get? polls poll-id) err-poll-not-found))
      (current-user-votes (get-user-vote-count tx-sender))
    )
    ;; Check not already voted
    (asserts! (not (has-voted poll-id tx-sender)) err-already-voted)
    ;; Check poll is active
    (asserts! (get active poll) err-poll-ended)
    ;; Collect fee
    (try! (collect-fee))
    ;; Record vote
    (map-set user-votes { poll-id: poll-id, voter: tx-sender } false)
    ;; Update poll
    (map-set polls poll-id (merge poll { no-votes: (+ (get no-votes poll) u1) }))
    ;; Update user stats
    (map-set user-vote-count tx-sender (+ current-user-votes u1))
    (var-set total-votes (+ (var-get total-votes) u1))
    (ok true)
  )
)

;; Close a poll (only creator) - costs 0.001 STX
(define-public (close-poll (poll-id uint))
  (let
    (
      (poll (unwrap! (map-get? polls poll-id) err-poll-not-found))
    )
    ;; Only creator can close
    (asserts! (is-eq tx-sender (get creator poll)) err-not-creator)
    ;; Collect fee
    (try! (collect-fee))
    ;; Close it
    (map-set polls poll-id (merge poll { active: false }))
    (ok true)
  )
)

;; Poll ping - costs 0.001 STX
(define-public (poll-ping)
  (begin
    (try! (collect-fee))
    (ok (var-get poll-counter))
  )
)

;; Quick vote on latest poll - costs 0.001 STX
(define-public (quick-vote-yes)
  (let ((latest-id (var-get poll-counter)))
    (if (> latest-id u0)
      (vote-yes (- latest-id u1))
      err-no-poll
    )
  )
)

(define-public (quick-vote-no)
  (let ((latest-id (var-get poll-counter)))
    (if (> latest-id u0)
      (vote-no (- latest-id u1))
      err-no-poll
    )
  )
)
