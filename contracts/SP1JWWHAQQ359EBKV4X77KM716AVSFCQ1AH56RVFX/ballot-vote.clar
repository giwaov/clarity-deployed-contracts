;; title: ballot-vote
;; version:
;; summary:
;; description:

;; title: Stacks-Ballot
;; version:
;; summary:
;; Democracy Chain: Decentralized Voting Smart Contract
;; A comprehensive smart contract for creating and managing community proposals with
;; configurable voting durations, transparent vote tracking, and administrator controls.

;; Define constants
(define-constant contract-admin tx-sender)
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-DUPLICATE-VOTE (err u101))
(define-constant ERR-INVALID-PROPOSAL-ID (err u102))
(define-constant ERR-VOTING-PERIOD-ENDED (err u103))
(define-constant ERR-INVALID-PARAMETER (err u104))
(define-constant ERR-PROPOSAL-DOES-NOT-EXIST (err u105))
(define-constant ERR-VOTING-DURATION-OUT-OF-BOUNDS (err u106))
(define-constant max-allowed-voting-period u2592000) ;; 30 days in seconds
(define-constant min-allowed-voting-period u86400) ;; 1 day in seconds

;; Define data maps
(define-map proposal-registry
  { proposal-id: uint }
  {
    proposal-title: (string-ascii 50),
    proposal-description: (string-ascii 500),
    total-votes: uint,
    proposal-status: bool,
    proposal-creator: principal,
    creation-block: uint,
    voting-period-length: uint,
  }
)

(define-map voter-registry
  {
    voter-address: principal,
    proposal-id: uint,
  }
  {
    has-participated: bool,
    participation-block: uint,
  }
)

;; Define data variables
(define-data-var total-proposal-count uint u0)
(define-data-var standard-voting-period uint u604800) ;; 7 days in seconds

;; Private functions
;; Ensure proposal content meets requirements
(define-private (is-valid-proposal-content
    (title (string-ascii 50))
    (description (string-ascii 500))
  )
  (and
    (> (len title) u0)
    (<= (len title) u50)
    (> (len description) u0)
    (<= (len description) u500)
  )
)

;; Check if proposal ID exists in the registry
(define-private (is-valid-proposal-reference (proposal-id uint))
  (and
    (> proposal-id u0)
    (<= proposal-id (var-get total-proposal-count))
  )
)

;; Determine if a proposal is open for voting
(define-private (can-accept-votes (proposal-id uint))
  (match (map-get? proposal-registry { proposal-id: proposal-id })
    proposal-data (and
      (get proposal-status proposal-data)
      (< stacks-block-height
        (+ (get creation-block proposal-data)
          (get voting-period-length proposal-data)
        ))
    )
    false
  )
)

;; Verify voting period is within allowed bounds
(define-private (is-valid-voting-duration (duration uint))
  (and
    (>= duration min-allowed-voting-period)
    (<= duration max-allowed-voting-period)
  )
)

;; Public functions
;; Submit a new community proposal
(define-public (submit-proposal
    (title (string-ascii 50))
    (description (string-ascii 500))
    (custom-duration (optional uint))
  )
  (let (
      (next-proposal-id (+ (var-get total-proposal-count) u1))
      (effective-voting-period (default-to (var-get standard-voting-period) custom-duration))
    )
    ;; Only contract administrator can create proposals
    (asserts! (is-eq tx-sender contract-admin) ERR-UNAUTHORIZED-ACCESS)

    ;; Ensure proposal content meets requirements
    (asserts! (is-valid-proposal-content title description) ERR-INVALID-PARAMETER)

    ;; Ensure voting duration is reasonable
    (asserts! (is-valid-voting-duration effective-voting-period)
      ERR-INVALID-PARAMETER
    )

    ;; Register the new proposal
    (map-set proposal-registry { proposal-id: next-proposal-id } {
      proposal-title: title,
      proposal-description: description,
      total-votes: u0,
      proposal-status: true,
      proposal-creator: tx-sender,
      creation-block: stacks-block-height,
      voting-period-length: effective-voting-period,
    })

    ;; Update total proposal counter
    (var-set total-proposal-count next-proposal-id)

    (ok next-proposal-id)
  )
)

;; Cast a vote on an active proposal
(define-public (cast-vote (proposal-id uint))
  (let (
      (proposal-data (unwrap! (map-get? proposal-registry { proposal-id: proposal-id })
        ERR-INVALID-PROPOSAL-ID
      ))
      (voter-history (map-get? voter-registry {
        voter-address: tx-sender,
        proposal-id: proposal-id,
      }))
      (has-already-voted (default-to false (get has-participated voter-history)))
    )
    ;; Validate proposal exists
    (asserts! (is-valid-proposal-reference proposal-id) ERR-INVALID-PROPOSAL-ID)

    ;; Ensure proposal is still accepting votes
    (asserts! (can-accept-votes proposal-id) ERR-VOTING-PERIOD-ENDED)

    ;; Prevent duplicate voting
    (asserts! (not has-already-voted) ERR-DUPLICATE-VOTE)

    ;; Record voter participation
    (map-set voter-registry {
      voter-address: tx-sender,
      proposal-id: proposal-id,
    } {
      has-participated: true,
      participation-block: stacks-block-height,
    })

    ;; Increment vote counter for the proposal
    (map-set proposal-registry { proposal-id: proposal-id }
      (merge proposal-data { total-votes: (+ (get total-votes proposal-data) u1) })
    )

    (ok true)
  )
)

;; End voting on a proposal before its natural conclusion
(define-public (finalize-proposal (proposal-id uint))
  (let ((proposal-data (unwrap! (map-get? proposal-registry { proposal-id: proposal-id })
      ERR-PROPOSAL-DOES-NOT-EXIST
    )))
    ;; Validate proposal exists
    (asserts! (is-valid-proposal-reference proposal-id) ERR-INVALID-PROPOSAL-ID)

    ;; Only contract administrator can manually close proposals
    (asserts! (is-eq tx-sender contract-admin) ERR-UNAUTHORIZED-ACCESS)

    ;; Mark the proposal as inactive
    (ok (map-set proposal-registry { proposal-id: proposal-id }
      (merge proposal-data { proposal-status: false })
    ))
  )
)

;; Update the default voting period for future proposals
(define-public (configure-default-voting-period (new-duration uint))
  (begin
    ;; Only contract administrator can change system settings
    (asserts! (is-eq tx-sender contract-admin) ERR-UNAUTHORIZED-ACCESS)

    ;; Ensure new duration is within acceptable bounds
    (asserts! (is-valid-voting-duration new-duration) ERR-INVALID-PARAMETER)

    ;; Update the standard voting period
    (var-set standard-voting-period new-duration)
    (ok true)
  )
)

;; Read-only functions
;; Retrieve comprehensive proposal information
(define-read-only (get-proposal-info (proposal-id uint))
  (let ((proposal-data (map-get? proposal-registry { proposal-id: proposal-id })))
    ;; Only return data for valid proposals
    (if (is-valid-proposal-reference proposal-id)
      (if (is-some proposal-data)
        (some {
          proposal-details: proposal-data,
          currently-active: (can-accept-votes proposal-id),
          blocks-remaining: (match proposal-data
            p (- (+ (get creation-block p) (get voting-period-length p))
              stacks-block-height
            )
            u0
          ),
        })
        none
      )
      none
    )
  )
)

;; Get the current number of proposals in the system
(define-read-only (get-total-proposals)
  (var-get total-proposal-count)
)

;; Check if a particular user has voted on a specific proposal
(define-read-only (check-voter-participation
    (voter-address principal)
    (proposal-id uint)
  )
  ;; Only check valid proposals
  (if (is-valid-proposal-reference proposal-id)
    (default-to false
      (get has-participated
        (map-get? voter-registry {
          voter-address: voter-address,
          proposal-id: proposal-id,
        })
      ))
    false
  )
)
