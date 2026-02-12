;; TrustGigs sBTC-Powered Job Board / Bounty Contract
;;
;; High-level flow:
;; - Employer creates a job with a locked sBTC reward.
;; - Applicants submit applications to an open job.
;; - Employer selects a winner; contract releases sBTC to the chosen applicant.
;;
;; Notes:
;; - This contract assumes an SIP-010-compliant sBTC fungible token.
;; - Text fields are stored as bounded buffers; frontends can also pair with off-chain storage.

;; --------------------------------------------------------
;; Constants
;; --------------------------------------------------------

(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_NOT_FOUND u101)
(define-constant ERR_JOB_CLOSED u102)
(define-constant ERR_NOT_EMPLOYER u103)
(define-constant ERR_ALREADY_WINNER u104)
(define-constant ERR_INVALID_REWARD u105)

(define-constant CONTRACT_OWNER tx-sender)

;; Placeholder sBTC token configuration.
;; NOTE: For the current MVP, we DO NOT perform on-chain token transfers yet.
;; The `reward` value is tracked in-contract only. Later, this var can be
;; wired to an SIP-010 token contract and the transfer logic restored.
(define-data-var sbtc-token principal CONTRACT_OWNER)

;; --------------------------------------------------------
;; Data structures
;; --------------------------------------------------------

(define-data-var job-counter uint u0)

;; Each job:
;; - id: implicit numeric key
;; - employer: principal that created the job
;; - reward: amount of sBTC (in sats) locked in this bounty
;; - status: 0 = open, 1 = closed
;; - winner: optional principal of winning applicant
;; - application-counter: number of applications for this job
;; - title / description: short metadata for discoverability

(define-map jobs
  { id: uint }
  {
    employer: principal,
    reward: uint,
    status: uint,
    winner: (optional principal),
    application-counter: uint,
    title: (buff 96),
    description: (buff 256)
  }
)

;; Applications are keyed by (job-id, application-id).
;; We keep applicant and a short "note" or reference (e.g. a link or hash to off-chain content).

(define-map applications
  { job-id: uint, application-id: uint }
  {
    applicant: principal,
    note: (buff 256),
    is-winner: bool
  }
)

;; --------------------------------------------------------
;; Helpers
;; --------------------------------------------------------

(define-read-only (get-sbtc-token)
  (ok (var-get sbtc-token))
)

(define-private (only-job-employer (job-id uint))
  (match (map-get? jobs { id: job-id })
    job
      (begin
        (asserts! (is-eq (get employer job) tx-sender) (err ERR_NOT_EMPLOYER))
        (ok job)
      )
    (err ERR_NOT_FOUND)
  )
)

;; --------------------------------------------------------
;; Public functions
;; --------------------------------------------------------

;; Create a new job and lock sBTC into the contract.
;;
;; @param reward - amount of sBTC (sats) to lock for this job
;; @param title  - short title (truncated to 96 bytes if longer off-chain)
;; @param description - short description (truncated to 256 bytes)

(define-public (create-job (reward uint) (title (buff 96)) (description (buff 256)))
  (begin
    (asserts! (> reward u0) (err ERR_INVALID_REWARD))

    (let
      (
        (job-id (+ u1 (var-get job-counter)))
      )
      (var-set job-counter job-id)

      (map-set jobs
        { id: job-id }
        {
          employer: tx-sender,
          reward: reward,
          status: u0,
          winner: none,
          application-counter: u0,
          title: title,
          description: description
        }
      )

      (ok job-id)
    )
  )
)

;; Apply to an open job.
;;
;; @param job-id - the job to apply to
;; @param note   - short text (e.g., summary or link to full proposal)

(define-public (apply-to-job (job-id uint) (note (buff 256)))
  (let
    (
      (job (unwrap! (map-get? jobs { id: job-id }) (err ERR_NOT_FOUND)))
    )
    (asserts! (is-eq (get status job) u0) (err ERR_JOB_CLOSED))

    (let
      (
        (application-id (+ u1 (get application-counter job)))
      )
      (map-set applications
        { job-id: job-id, application-id: application-id }
        {
          applicant: tx-sender,
          note: note,
          is-winner: false
        }
      )

      (map-set jobs
        { id: job-id }
        (merge job { application-counter: application-id })
      )

      (ok application-id)
    )
  )
)

;; Select a winning application and release sBTC to the winner.
;;
;; Only the employer who created the job can call this.

(define-public (select-winner (job-id uint) (application-id uint))
  (let
    (
      (job (unwrap! (only-job-employer job-id) (err ERR_NOT_EMPLOYER)))
      (app (unwrap! (map-get? applications { job-id: job-id, application-id: application-id })
                    (err ERR_NOT_FOUND)))
    )
    (asserts! (is-eq (get status job) u0) (err ERR_JOB_CLOSED))
    (asserts! (not (is-some (get winner job))) (err ERR_ALREADY_WINNER))

    (let
      (
        (winner (get applicant app))
        (reward (get reward job))
      )
      (map-set jobs
        { id: job-id }
        (merge job { status: u1, winner: (some winner) })
      )

      (map-set applications
        { job-id: job-id, application-id: application-id }
        (merge app { is-winner: true })
      )

      (ok true)
    )
  )
)

;; --------------------------------------------------------
;; Read-only helpers for frontends
;; --------------------------------------------------------

;; Get a job by id.
(define-read-only (get-job (job-id uint))
  (match (map-get? jobs { id: job-id })
    job (ok job)
    (err ERR_NOT_FOUND)
  )
)

;; Get a single application for a job.
(define-read-only (get-application (job-id uint) (application-id uint))
  (match (map-get? applications { job-id: job-id, application-id: application-id })
    app (ok app)
    (err ERR_NOT_FOUND)
  )
)

;; Get counts useful for pagination on the frontend.
(define-read-only (get-job-count)
  (ok (var-get job-counter))
)

(define-read-only (get-application-count (job-id uint))
  (match (map-get? jobs { id: job-id })
    job (ok (get application-counter job))
    (err ERR_NOT_FOUND)
  )
)

