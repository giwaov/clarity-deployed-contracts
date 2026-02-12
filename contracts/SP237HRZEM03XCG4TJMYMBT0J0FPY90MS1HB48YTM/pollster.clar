;; pollster.clar
;;
;; ============================================
;; title: pollster
;; version: 1
;; summary: A simple voting and polling smart contract for Stacks blockchain.
;; description: Create polls, cast votes, and track results on-chain with duplicate prevention.
;; ============================================

;; traits
;;
;; ============================================
;; token definitions
;;
;; ============================================
;; constants
;;

;; Counter Error Codes (for decoration)
(define-constant ERR_UNDERFLOW (err u100))

;; Pollster Error Codes
(define-constant ERR_POLL_NOT_FOUND (err u101))
(define-constant ERR_POLL_CLOSED (err u102))
(define-constant ERR_ALREADY_VOTED (err u103))
(define-constant ERR_INVALID_OPTION (err u104))
(define-constant ERR_UNAUTHORIZED (err u105))
(define-constant ERR_EMPTY_OPTIONS (err u106))

;; ============================================
;; data vars
;;

;; Counter for general testing (as requested for decoration)
(define-data-var counter uint u0)

;; Poll ID counter to track the next available poll ID
(define-data-var next-poll-id uint u0)

;; ============================================
;; data maps
;;

;; Map to store poll metadata
(define-map polls
  uint  ;; poll-id
  {
    title: (string-ascii 256),
    creator: principal,
    total-votes: uint,
    is-active: bool,
    option-count: uint
  }
)

;; Map to store vote counts for each option in a poll
(define-map poll-options
  {poll-id: uint, option-index: uint}
  {
    option-name: (string-ascii 64),
    votes: uint
  }
)

;; Map to track who has voted in which poll (prevents duplicate voting)
(define-map voters
  {poll-id: uint, voter: principal}
  bool
)

;; ============================================
;; public functions
;;

;; --- Counter Functions (for decoration as requested) ---

;; Public function to increment the counter
(define-public (increment)
  (let
    ((new-value (+ (var-get counter) u1)))
    (begin
      (var-set counter new-value)
      (print {
        event: "counter-incremented",
        caller: tx-sender,
        new-value: new-value,
        block-height: stacks-block-height
      })
      (ok new-value)
    )
  )
)

;; Public function to decrement the counter
(define-public (decrement)
  (let 
    ((current-value (var-get counter)))
    (begin
      ;; Prevent underflow
      (asserts! (> current-value u0) ERR_UNDERFLOW)
      (let
        ((new-value (- current-value u1)))
        (begin
          (var-set counter new-value)
          (print {
            event: "counter-decremented",
            caller: tx-sender,
            new-value: new-value,
            block-height: stacks-block-height
          })
          (ok new-value)
        )
      )
    )
  )
)

;; --- Pollster Core Functions ---

;; Create a new poll with a title and list of options
(define-public (create-poll (title (string-ascii 256)) (options (list 20 (string-ascii 64))))
  (let
    (
      (poll-id (var-get next-poll-id))
      (option-count (len options))
    )
    (begin
      ;; Validate that there are options
      (asserts! (> option-count u0) ERR_EMPTY_OPTIONS)

      ;; Store poll metadata
      (map-set polls poll-id
        {
          title: title,
          creator: tx-sender,
          total-votes: u0,
          is-active: true,
          option-count: option-count
        }
      )

      ;; Store each option with initial vote count of 0
      (map store-option 
        options 
        (list 
          u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 
          u10 u11 u12 u13 u14 u15 u16 u17 u18 u19
        )
      )

      ;; Increment poll ID for next poll
      (var-set next-poll-id (+ poll-id u1))

      ;; Emit event
      (print {
        event: "poll-created",
        poll-id: poll-id,
        title: title,
        creator: tx-sender,
        option-count: option-count,
        block-height: stacks-block-height
      })

      (ok poll-id)
    )
  )
)

;; Cast a vote for a specific option in a poll
(define-public (vote (poll-id uint) (option-index uint))
  (let
    (
      (poll-info (unwrap! (map-get? polls poll-id) ERR_POLL_NOT_FOUND))
      (has-voted-already (default-to false (map-get? voters {poll-id: poll-id, voter: tx-sender})))
      (option-data (unwrap! (map-get? poll-options {poll-id: poll-id, option-index: option-index}) ERR_INVALID_OPTION))
    )
    (begin
      ;; Check if poll is still active
      (asserts! (get is-active poll-info) ERR_POLL_CLOSED)

      ;; Check if user has already voted
      (asserts! (not has-voted-already) ERR_ALREADY_VOTED)

      ;; Check if option index is valid
      (asserts! (< option-index (get option-count poll-info)) ERR_INVALID_OPTION)

      ;; Record the vote
      (map-set voters {poll-id: poll-id, voter: tx-sender} true)

      ;; Increment vote count for the option
      (map-set poll-options {poll-id: poll-id, option-index: option-index}
        {
          option-name: (get option-name option-data),
          votes: (+ (get votes option-data) u1)
        }
      )

      ;; Increment total votes for the poll
      (map-set polls poll-id
        (merge poll-info {total-votes: (+ (get total-votes poll-info) u1)})
      )

      ;; Emit event
      (print {
        event: "vote-cast",
        poll-id: poll-id,
        voter: tx-sender,
        option-index: option-index,
        block-height: stacks-block-height
      })

      (ok true)
    )
  )
)

;; Close a poll (only creator can do this)
(define-public (close-poll (poll-id uint))
  (let
    (
      (poll-info (unwrap! (map-get? polls poll-id) ERR_POLL_NOT_FOUND))
    )
    (begin
      ;; Check if caller is the creator
      (asserts! (is-eq tx-sender (get creator poll-info)) ERR_UNAUTHORIZED)

      ;; Check if poll is already closed
      (asserts! (get is-active poll-info) ERR_POLL_CLOSED)

      ;; Close the poll
      (map-set polls poll-id
        (merge poll-info {is-active: false})
      )

      ;; Emit event
      (print {
        event: "poll-closed",
        poll-id: poll-id,
        creator: tx-sender,
        total-votes: (get total-votes poll-info),
        block-height: stacks-block-height
      })

      (ok true)
    )
  )
)

;; ============================================
;; read only functions
;;

;; Read-only function to get the current counter value (for decoration)
(define-read-only (get-counter)
  (ok (var-get counter))
)

;; Get poll information
(define-read-only (get-poll-info (poll-id uint))
  (match (map-get? polls poll-id)
    poll-data (ok poll-data)
    ERR_POLL_NOT_FOUND
  )
)

;; Get vote count for a specific option
(define-read-only (get-option-votes (poll-id uint) (option-index uint))
  (match (map-get? poll-options {poll-id: poll-id, option-index: option-index})
    option-data (ok (get votes option-data))
    ERR_INVALID_OPTION
  )
)

;; Get option name and votes
(define-read-only (get-option-info (poll-id uint) (option-index uint))
  (match (map-get? poll-options {poll-id: poll-id, option-index: option-index})
    option-data (ok option-data)
    ERR_INVALID_OPTION
  )
)

;; Check if a user has voted in a poll
(define-read-only (has-voted (poll-id uint) (user principal))
  (ok (default-to false (map-get? voters {poll-id: poll-id, voter: user})))
)

;; Get the total number of polls created
(define-read-only (get-total-polls)
  (ok (var-get next-poll-id))
)

;; Get poll results summary for all options
(define-read-only (get-poll-results (poll-id uint))
  (let
    (
      (poll-info (unwrap! (map-get? polls poll-id) ERR_POLL_NOT_FOUND))
    )
    (ok {
      title: (get title poll-info),
      total-votes: (get total-votes poll-info),
      is-active: (get is-active poll-info),
      option-count: (get option-count poll-info)
    })
  )
)

;; ============================================
;; private functions
;;

;; Private helper function to store options when creating a poll
;; This is called by map in create-poll
(define-private (store-option (option-name (string-ascii 64)) (index uint))
  (let
    (
      (poll-id (var-get next-poll-id))
    )
    (begin
      (map-set poll-options {poll-id: poll-id, option-index: index}
        {
          option-name: option-name,
          votes: u0
        }
      )
      true
    )
  )
)
