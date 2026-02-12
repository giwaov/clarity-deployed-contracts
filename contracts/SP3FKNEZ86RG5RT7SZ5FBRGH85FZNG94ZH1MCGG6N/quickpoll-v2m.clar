;; QuickPoll Contract v2m - Enhanced with validation, admin controls, and improved events
;; Contract 3 of 3 for Stacks Transaction Hub

;; ============================================
;; CONTRACT METADATA
;; ============================================
(define-constant CONTRACT-NAME "quickpoll")
(define-constant VERSION u5)

;; ============================================
;; CONFIGURATION
;; ============================================
(define-constant contract-owner tx-sender)
(define-constant interaction-fee u1000) ;; 0.001 STX = 1000 microSTX
(define-constant MAX-QUESTION-LENGTH u100)
(define-constant MAX-POLLS-PER-USER u50)

;; ============================================
;; ERROR CODES
;; ============================================
;; Vote/Poll errors (100-109)
(define-constant ERR-ALREADY-VOTED (err u100))
(define-constant ERR-POLL-NOT-FOUND (err u101))
(define-constant ERR-POLL-ENDED (err u102))
(define-constant ERR-NOT-CREATOR (err u103))
(define-constant ERR-NO-POLL (err u104))

;; Authorization errors (110-119)
(define-constant ERR-NOT-OWNER (err u110))
(define-constant ERR-UNAUTHORIZED (err u111))

;; State errors (120-129)
(define-constant ERR-CONTRACT-PAUSED (err u120))
(define-constant ERR-POLL-ALREADY-ACTIVE (err u121))
(define-constant ERR-POLL-ALREADY-ENDED (err u122))

;; Input validation errors (130-139)
(define-constant ERR-INVALID-POLL-ID (err u130))
(define-constant ERR-EMPTY-QUESTION (err u131))
(define-constant ERR-QUESTION-TOO-LONG (err u132))
(define-constant ERR-TOO-MANY-POLLS (err u133))

;; ============================================
;; DATA VARIABLES
;; ============================================
(define-data-var poll-counter uint u0)
(define-data-var total-votes uint u0)
(define-data-var total-fees-collected uint u0)
(define-data-var last-activity-block uint u0)
(define-data-var unique-voters uint u0)
(define-data-var unique-creators uint u0)
(define-data-var is-paused bool false)

;; ============================================
;; DATA MAPS
;; ============================================
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
(define-map user-polls-created principal uint)
(define-map user-first-vote principal uint)

;; ============================================
;; PRIVATE FUNCTIONS
;; ============================================

;; Check if contract is active
(define-private (check-not-paused)
  (ok (asserts! (not (var-get is-paused)) ERR-CONTRACT-PAUSED))
)

;; Check if caller is owner
(define-private (check-owner)
  (ok (asserts! (is-eq tx-sender contract-owner) ERR-NOT-OWNER))
)

;; Collect interaction fee
(define-private (collect-fee)
  (begin
    (try! (stx-transfer? interaction-fee tx-sender contract-owner))
    (var-set total-fees-collected (+ (var-get total-fees-collected) interaction-fee))
    (ok true)
  )
)

;; Validate question
(define-private (validate-question (question (string-ascii 100)))
  (let
    (
      (len (len question))
    )
    (asserts! (> len u0) ERR-EMPTY-QUESTION)
    (asserts! (<= len MAX-QUESTION-LENGTH) ERR-QUESTION-TOO-LONG)
    (ok true)
  )
)

;; Track new voter
(define-private (track-new-voter)
  (if (is-eq (default-to u0 (map-get? user-vote-count tx-sender)) u0)
    (begin
      (var-set unique-voters (+ (var-get unique-voters) u1))
      (map-set user-first-vote tx-sender block-height)
      true
    )
    false
  )
)

;; Track new creator
(define-private (track-new-creator)
  (if (is-eq (default-to u0 (map-get? user-polls-created tx-sender)) u0)
    (begin
      (var-set unique-creators (+ (var-get unique-creators) u1))
      true
    )
    false
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-version)
  VERSION
)

(define-read-only (get-contract-name)
  CONTRACT-NAME
)

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

(define-read-only (get-user-polls-created (user principal))
  (default-to u0 (map-get? user-polls-created user))
)

(define-read-only (get-unique-voters)
  (var-get unique-voters)
)

(define-read-only (get-unique-creators)
  (var-get unique-creators)
)

(define-read-only (get-last-activity-block)
  (var-get last-activity-block)
)

(define-read-only (has-voted (poll-id uint) (voter principal))
  (default-to false (map-get? user-votes { poll-id: poll-id, voter: voter }))
)

(define-read-only (is-contract-paused)
  (var-get is-paused)
)

(define-read-only (get-poll-results (poll-id uint))
  (match (map-get? polls poll-id)
    poll {
      yes: (get yes-votes poll),
      no: (get no-votes poll),
      total: (+ (get yes-votes poll) (get no-votes poll)),
      active: (get active poll)
    }
    { yes: u0, no: u0, total: u0, active: false }
  )
)

(define-read-only (get-stats)
  {
    total-polls: (var-get poll-counter),
    total-votes: (var-get total-votes),
    fees-collected: (var-get total-fees-collected),
    unique-voters: (var-get unique-voters),
    unique-creators: (var-get unique-creators),
    paused: (var-get is-paused)
  }
)

(define-read-only (get-contract-info)
  {
    name: CONTRACT-NAME,
    version: VERSION,
    total-polls: (var-get poll-counter),
    total-votes: (var-get total-votes),
    unique-voters: (var-get unique-voters),
    unique-creators: (var-get unique-creators),
    fee: interaction-fee,
    last-activity: (var-get last-activity-block),
    owner: contract-owner,
    paused: (var-get is-paused)
  }
)

;; ============================================
;; PUBLIC FUNCTIONS
;; ============================================

;; Create a new poll - costs 0.001 STX
(define-public (create-poll (question (string-ascii 100)))
  (let
    (
      (poll-id (+ (var-get poll-counter) u1))
      (user-polls (get-user-polls-created tx-sender))
    )
    ;; Check contract is active
    (try! (check-not-paused))
    ;; Validate question
    (try! (validate-question question))
    ;; Check user poll limit
    (asserts! (< user-polls MAX-POLLS-PER-USER) ERR-TOO-MANY-POLLS)
    ;; Track new creator
    (track-new-creator)
    ;; Collect fee
    (try! (collect-fee))
    ;; Create poll
    (map-set polls poll-id {
      question: question,
      yes-votes: u0,
      no-votes: u0,
      created-at: block-height,
      creator: tx-sender,
      active: true
    })
    ;; Update state
    (map-set user-polls-created tx-sender (+ user-polls u1))
    (var-set poll-counter poll-id)
    (var-set last-activity-block block-height)
    ;; Emit enhanced event
    (print {
      event: "create-poll",
      version: VERSION,
      poll-id: poll-id,
      creator: tx-sender,
      question: question,
      block: block-height
    })
    (ok poll-id)
  )
)

;; Vote yes on a poll - costs 0.001 STX
(define-public (vote-yes (poll-id uint))
  (let
    (
      (poll (unwrap! (map-get? polls poll-id) ERR-POLL-NOT-FOUND))
      (new-total-votes (+ (var-get total-votes) u1))
      (user-votes-count (get-user-vote-count tx-sender))
    )
    ;; Check contract is active
    (try! (check-not-paused))
    ;; Validate poll
    (asserts! (get active poll) ERR-POLL-ENDED)
    (asserts! (not (has-voted poll-id tx-sender)) ERR-ALREADY-VOTED)
    ;; Track new voter
    (track-new-voter)
    ;; Collect fee
    (try! (collect-fee))
    ;; Record vote
    (map-set user-votes { poll-id: poll-id, voter: tx-sender } true)
    (map-set polls poll-id (merge poll { yes-votes: (+ (get yes-votes poll) u1) }))
    (map-set user-vote-count tx-sender (+ user-votes-count u1))
    ;; Update state
    (var-set total-votes new-total-votes)
    (var-set last-activity-block block-height)
    ;; Emit enhanced event
    (print {
      event: "vote",
      version: VERSION,
      poll-id: poll-id,
      voter: tx-sender,
      vote: "yes",
      total-votes: new-total-votes,
      block: block-height
    })
    (ok true)
  )
)

;; Vote no on a poll - costs 0.001 STX
(define-public (vote-no (poll-id uint))
  (let
    (
      (poll (unwrap! (map-get? polls poll-id) ERR-POLL-NOT-FOUND))
      (new-total-votes (+ (var-get total-votes) u1))
      (user-votes-count (get-user-vote-count tx-sender))
    )
    ;; Check contract is active
    (try! (check-not-paused))
    ;; Validate poll
    (asserts! (get active poll) ERR-POLL-ENDED)
    (asserts! (not (has-voted poll-id tx-sender)) ERR-ALREADY-VOTED)
    ;; Track new voter
    (track-new-voter)
    ;; Collect fee
    (try! (collect-fee))
    ;; Record vote
    (map-set user-votes { poll-id: poll-id, voter: tx-sender } true)
    (map-set polls poll-id (merge poll { no-votes: (+ (get no-votes poll) u1) }))
    (map-set user-vote-count tx-sender (+ user-votes-count u1))
    ;; Update state
    (var-set total-votes new-total-votes)
    (var-set last-activity-block block-height)
    ;; Emit enhanced event
    (print {
      event: "vote",
      version: VERSION,
      poll-id: poll-id,
      voter: tx-sender,
      vote: "no",
      total-votes: new-total-votes,
      block: block-height
    })
    (ok true)
  )
)

;; Generic vote function - costs 0.001 STX
(define-public (vote (poll-id uint) (vote-yes-flag bool))
  (if vote-yes-flag
    (vote-yes poll-id)
    (vote-no poll-id)
  )
)

;; End a poll (creator only) - costs 0.001 STX
(define-public (end-poll (poll-id uint))
  (let
    (
      (poll (unwrap! (map-get? polls poll-id) ERR-POLL-NOT-FOUND))
    )
    ;; Check contract is active
    (try! (check-not-paused))
    ;; Validate ownership
    (asserts! (is-eq tx-sender (get creator poll)) ERR-NOT-CREATOR)
    (asserts! (get active poll) ERR-POLL-ALREADY-ENDED)
    ;; Collect fee
    (try! (collect-fee))
    ;; End poll
    (map-set polls poll-id (merge poll { active: false }))
    (var-set last-activity-block block-height)
    ;; Emit enhanced event
    (print {
      event: "end-poll",
      version: VERSION,
      poll-id: poll-id,
      ended-by: tx-sender,
      yes-votes: (get yes-votes poll),
      no-votes: (get no-votes poll),
      block: block-height
    })
    (ok true)
  )
)

;; Ping - costs 0.001 STX
(define-public (ping)
  (begin
    (try! (check-not-paused))
    (try! (collect-fee))
    (var-set last-activity-block block-height)
    (print {
      event: "ping",
      version: VERSION,
      user: tx-sender,
      block: block-height
    })
    (ok block-height)
  )
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

;; Pause contract (owner only)
(define-public (pause)
  (begin
    (try! (check-owner))
    (var-set is-paused true)
    (print {
      event: "contract-paused",
      version: VERSION,
      by: tx-sender,
      block: block-height
    })
    (ok true)
  )
)

;; Unpause contract (owner only)
(define-public (unpause)
  (begin
    (try! (check-owner))
    (var-set is-paused false)
    (print {
      event: "contract-unpaused",
      version: VERSION,
      by: tx-sender,
      block: block-height
    })
    (ok true)
  )
)

;; Force end a poll (owner only - emergency) - no fee
(define-public (admin-end-poll (poll-id uint))
  (let
    (
      (poll (unwrap! (map-get? polls poll-id) ERR-POLL-NOT-FOUND))
    )
    (try! (check-owner))
    (map-set polls poll-id (merge poll { active: false }))
    (print {
      event: "admin-end-poll",
      version: VERSION,
      poll-id: poll-id,
      ended-by: tx-sender,
      block: block-height
    })
    (ok true)
  )
)
