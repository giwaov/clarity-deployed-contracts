;; DisputeResolution Contract
;; This contract handles the dispute resolution process for the Strade marketplace.
;; It allows users to raise disputes, arbitrators to vote on them, and resolves disputes based on the outcome.

;; --- Constants ---
;; Defines immutable values used throughout the contract for error handling and configuration.

(define-constant CONTRACT_OWNER tx-sender) ;; Sets the contract deployer as the owner.
(define-constant ERR_NOT_AUTHORIZED (err u100)) ;; Error for unauthorized actions.
(define-constant ERR_DISPUTE_NOT_FOUND (err u101)) ;; Error when a dispute cannot be found.
(define-constant ERR_INVALID_STATE (err u102)) ;; Error for invalid dispute states.
(define-constant ERR_NOT_ARBITRATOR (err u103)) ;; Error when a user is not an authorized arbitrator.
(define-constant ERR_ALREADY_VOTED (err u104)) ;; Error if an arbitrator has already voted.
(define-constant ERR_VOTING_CLOSED (err u105)) ;; Error when voting on a dispute is closed.
(define-constant ERR_INSUFFICIENT_VOTES (err u106)) ;; Error if there are not enough votes to resolve a dispute.
(define-constant ERR_INVALID_VOTE (err u107)) ;; Error for invalid vote values.
(define-constant ERR_NOT_INVOLVED_PARTY (err u108)) ;; Error when a user is not a party to the dispute.
(define-constant ERR_INVALID_ESCROW_ID (err u109)) ;; Error for invalid escrow IDs.
(define-constant ERR_INVALID_REASON (err u110)) ;; Error for invalid dispute reasons.
(define-constant ERR_INVALID_DISPUTE_ID (err u111)) ;; Error for invalid dispute IDs.
(define-constant ERR_INVALID_REWARD (err u112)) ;; Error for invalid arbitrator rewards.
(define-constant ERR_INVALID_PRINCIPAL (err u113)) ;; Error for invalid principal addresses.
(define-constant VOTING_PERIOD u144) ;; The duration of the voting period in blocks (approximately 24 hours).
(define-constant MIN_VOTES_REQUIRED u3) ;; The minimum number of votes required to resolve a dispute.

;; --- Data Maps ---
;; Defines the data structures used to store dispute and arbitrator information.

(define-map Disputes
  { dispute-id: uint }
  {
    escrow-id: uint, ;; The ID of the associated escrow.
    initiator: principal, ;; The principal who initiated the dispute.
    counterparty: principal, ;; The other party in the dispute.
    reason: (string-utf8 256), ;; The reason for the dispute.
    status: (string-ascii 20), ;; The current status of the dispute (e.g., "open", "resolved").
    created-at: uint, ;; The block height at which the dispute was created.
    votes-for: uint, ;; The number of votes in favor of the initiator.
    votes-against: uint, ;; The number of votes against the initiator.
    resolution: (optional (string-ascii 20)) ;; The resolution of the dispute.
  }
)

(define-map Arbitrators principal bool) ;; Stores the set of authorized arbitrators.
(define-map ArbitratorVotes { dispute-id: uint, arbitrator: principal } bool) ;; Tracks votes cast by arbitrators.

;; --- Variables ---
;; Defines mutable variables for tracking the contract's state.

(define-data-var last-dispute-id uint u0) ;; Tracks the ID of the last created dispute.
(define-data-var arbitrator-reward uint u100) ;; The reward amount for arbitrators who vote on a dispute.

;; --- Private Functions ---
;; Helper functions intended for internal use by the contract.

;; Checks if a given user is an authorized arbitrator.
(define-private (is-arbitrator (user principal))
  (default-to false (map-get? Arbitrators user))
)

;; Checks if an arbitrator has already voted on a specific dispute.
(define-private (has-voted (dispute-id uint) (arbitrator principal))
  (is-some (map-get? ArbitratorVotes { dispute-id: dispute-id, arbitrator: arbitrator }))
)

;; Updates the vote count for a dispute.
(define-private (update-vote-count (dispute-id uint) (vote bool))
  (match (map-get? Disputes { dispute-id: dispute-id })
    dispute (let
      (
        (new-votes-for (if vote (+ (get votes-for dispute) u1) (get votes-for dispute)))
        (new-votes-against (if vote (get votes-against dispute) (+ (get votes-against dispute) u1)))
      )
      (map-set Disputes { dispute-id: dispute-id }
        (merge dispute {
          votes-for: new-votes-for,
          votes-against: new-votes-against
        }))
      (ok true))
    (err ERR_DISPUTE_NOT_FOUND)
  )
)

;; Checks if an escrow ID is valid.
(define-private (is-valid-escrow-id (escrow-id uint))
  (> escrow-id u0)
)

;; Checks if a dispute reason is valid.
(define-private (is-valid-reason (reason (string-utf8 256)))
  (and (> (len reason) u0) (<= (len reason) u256))
)

;; Checks if a dispute ID is valid.
(define-private (is-valid-dispute-id (dispute-id uint))
  (<= dispute-id (var-get last-dispute-id))
)

;; --- Public Functions ---
;; Functions that can be called by any user.

;; Raises a new dispute.
;; @param escrow-id: The ID of the escrow to dispute.
;; @param counterparty: The other party in the dispute.
;; @param reason: The reason for the dispute.
;; @returns (ok uint): The ID of the newly created dispute.
(define-public (raise-dispute (escrow-id uint) (counterparty principal) (reason (string-utf8 256)))
  (let
    (
      (dispute-id (+ (var-get last-dispute-id) u1))
    )
    (asserts! (is-valid-escrow-id escrow-id) (err ERR_INVALID_ESCROW_ID))
    (asserts! (is-valid-reason reason) (err ERR_INVALID_REASON))
    (asserts! (not (is-eq tx-sender counterparty)) (err ERR_NOT_INVOLVED_PARTY))
    (map-set Disputes
      { dispute-id: dispute-id }
      {
        escrow-id: escrow-id,
        initiator: tx-sender,
        counterparty: counterparty,
        reason: reason,
        status: "open",
        created-at: stacks-block-height,
        votes-for: u0,
        votes-against: u0,
        resolution: none
      }
    )
    (var-set last-dispute-id dispute-id)
    (print { event: "dispute_raised", dispute-id: dispute-id, escrow-id: escrow-id, initiator: tx-sender })
    (ok dispute-id)
  )
)

;; Allows an arbitrator to vote on a dispute.
;; @param dispute-id: The ID of the dispute to vote on.
;; @param vote: The arbitrator's vote (true for initiator, false for counterparty).
;; @returns (ok bool): True if the vote is successful.
(define-public (vote-on-dispute (dispute-id uint) (vote bool))
  (let
    (
      (dispute (unwrap! (map-get? Disputes { dispute-id: dispute-id }) (err ERR_DISPUTE_NOT_FOUND)))
    )
    (asserts! (is-valid-dispute-id dispute-id) (err ERR_INVALID_DISPUTE_ID))
    (asserts! (is-arbitrator tx-sender) (err ERR_NOT_ARBITRATOR))
    (asserts! (is-eq (get status dispute) "open") (err ERR_VOTING_CLOSED))
    (asserts! (<= (- stacks-block-height (get created-at dispute)) VOTING_PERIOD) (err ERR_VOTING_CLOSED))
    (asserts! (not (has-voted dispute-id tx-sender)) (err ERR_ALREADY_VOTED))
    (try! (update-vote-count dispute-id vote))
    (map-set ArbitratorVotes { dispute-id: dispute-id, arbitrator: tx-sender } vote)
    (print { event: "arbitrator_voted", dispute-id: dispute-id, arbitrator: tx-sender, vote: vote })
    (ok true)
  )
)

;; Resolves a dispute based on the votes.
;; @param dispute-id: The ID of the dispute to resolve.
;; @returns (ok (string-ascii 20)): The resolution of the dispute.
(define-public (resolve-dispute (dispute-id uint))
  (let
    (
      (dispute (unwrap! (map-get? Disputes { dispute-id: dispute-id }) (err ERR_DISPUTE_NOT_FOUND)))
    )
    (asserts! (is-valid-dispute-id dispute-id) (err ERR_INVALID_DISPUTE_ID))
    (asserts! (is-eq (get status dispute) "open") (err ERR_INVALID_STATE))
    (asserts! (>= (+ (get votes-for dispute) (get votes-against dispute)) MIN_VOTES_REQUIRED) (err ERR_INSUFFICIENT_VOTES))
    (asserts! (<= (- stacks-block-height (get created-at dispute)) VOTING_PERIOD) (err ERR_VOTING_CLOSED))
    (let
      (
        (resolution (if (> (get votes-for dispute) (get votes-against dispute)) "for_initiator" "for_counterparty"))
      )
      (map-set Disputes { dispute-id: dispute-id }
        (merge dispute {
          status: "resolved",
          resolution: (some resolution)
        })
      )
      (print { event: "dispute_resolved", dispute-id: dispute-id, resolution: resolution })
      (ok resolution)
    )
  )
)

;; Adds a new arbitrator.
;; @param arbitrator: The principal of the new arbitrator.
;; @returns (ok bool): True if the arbitrator is added successfully.
(define-public (add-arbitrator (arbitrator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_NOT_AUTHORIZED))
    (asserts! (is-valid-principal arbitrator) (err ERR_INVALID_PRINCIPAL))
    (map-set Arbitrators arbitrator true)
    (print { event: "arbitrator_added", arbitrator: arbitrator })
    (ok true)
  )
)

;; Removes an arbitrator.
;; @param arbitrator: The principal of the arbitrator to remove.
;; @returns (ok bool): True if the arbitrator is removed successfully.
(define-public (remove-arbitrator (arbitrator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_NOT_AUTHORIZED))
    (asserts! (is-valid-principal arbitrator) (err ERR_INVALID_PRINCIPAL))
    (map-delete Arbitrators arbitrator)
    (print { event: "arbitrator_removed", arbitrator: arbitrator })
    (ok true)
  )
)

;; Sets the reward for arbitrators.
;; @param new-reward: The new reward amount.
;; @returns (ok bool): True if the reward is set successfully.
(define-public (set-arbitrator-reward (new-reward uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_NOT_AUTHORIZED))
    (asserts! (> new-reward u0) (err ERR_INVALID_REWARD))
    (var-set arbitrator-reward new-reward)
    (print { event: "arbitrator_reward_set", new-reward: new-reward })
    (ok true)
  )
)

;; --- Read-Only Functions ---
;; Functions for retrieving data from the contract without making state changes.

;; Retrieves a dispute by its ID.
;; @param dispute-id: The ID of the dispute to retrieve.
;; @returns (optional {<dispute-data>}): The dispute data or none if not found.
(define-read-only (get-dispute (dispute-id uint))
  (map-get? Disputes { dispute-id: dispute-id })
)

;; Retrieves the ID of the last created dispute.
;; @returns (ok uint): The last dispute ID.
(define-read-only (get-last-dispute-id)
  (ok (var-get last-dispute-id))
)

;; Retrieves the arbitrator reward amount.
;; @returns (ok uint): The arbitrator reward amount.
(define-read-only (get-arbitrator-reward)
  (ok (var-get arbitrator-reward))
)

;; Checks if a user is an authorized arbitrator.
;; @param user: The principal to check.
;; @returns (ok bool): True if the user is an arbitrator.
(define-read-only (is-user-arbitrator (user principal))
  (ok (is-arbitrator user))
)

;; --- Helper function for principal validation ---
(define-private (is-valid-principal (principal principal))
  (and 
    (not (is-eq principal CONTRACT_OWNER))
    (not (is-eq principal (as-contract tx-sender)))
  )
)

;; --- Contract Initialization ---
;; Initializes the contract upon deployment.
(begin
  (print "DisputeResolution contract initialized")
  (ok true)
)
