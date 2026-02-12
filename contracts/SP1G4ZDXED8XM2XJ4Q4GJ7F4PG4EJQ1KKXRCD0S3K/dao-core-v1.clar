;; Simple DAO that allows tokenless STX-based voting and treasury transfers.

(define-constant ERR_PROPOSAL_MISSING u100)
(define-constant ERR_VOTING_CLOSED u101)
(define-constant ERR_ALREADY_VOTED u102)
(define-constant ERR_ALREADY_EXECUTED u103)
(define-constant ERR_NOT_PASSED u104)
(define-constant ERR_TRANSFER_FAILED u105)
(define-constant ERR_INSUFFICIENT_POWER u106)
(define-constant ERR_AS_CONTRACT u107)

(define-constant CHOICE_AGAINST u0)
(define-constant CHOICE_FOR u1)

(define-constant VOTING_PERIOD u1440) ;; ~1 day on 10m blocks
(define-constant MIN_QUORUM u1000000) ;; 1 STX in microstx
(define-constant PROPOSAL_THRESHOLD u1000000) ;; 1 STX in microstx

(define-data-var next-proposal-id uint u1)

(define-map proposals
  { id: uint }
  {
    proposer: principal,
    recipient: principal,
    amount: uint,
    start-height: uint,
    end-height: uint,
    for-votes: uint,
    against-votes: uint,
    executed: bool,
  }
)

(define-map receipts
  {
    id: uint,
    voter: principal,
  }
  {
    choice: uint,
    weight: uint,
  }
)

(define-read-only (get-dao-balance)
  (unwrap! (as-contract? () (stx-get-balance tx-sender)) ERR_AS_CONTRACT)
)

(define-private (proposal-passes (proposal {
  proposer: principal,
  recipient: principal,
  amount: uint,
  start-height: uint,
  end-height: uint,
  for-votes: uint,
  against-votes: uint,
  executed: bool,
}))
  (let (
      (for (get for-votes proposal))
      (against (get against-votes proposal))
    )
    (and (>= for MIN_QUORUM) (> for against))
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { id: proposal-id })
)

(define-public (propose
    (recipient principal)
    (amount uint)
  )
  (let (
      (pid (var-get next-proposal-id))
      (power (stx-get-balance tx-sender))
    )
    (if (< power PROPOSAL_THRESHOLD)
      (err ERR_INSUFFICIENT_POWER)
      (begin
        (map-set proposals { id: pid } {
          proposer: tx-sender,
          recipient: recipient,
          amount: amount,
          start-height: stacks-block-height,
          end-height: (+ stacks-block-height VOTING_PERIOD),
          for-votes: u0,
          against-votes: u0,
          executed: false,
        })
        (var-set next-proposal-id (+ pid u1))
        (ok pid)
      )
    )
  )
)

(define-public (cast-vote
    (proposal-id uint)
    (choice uint)
  )
  (let ((proposal (unwrap! (map-get? proposals { id: proposal-id }) (err ERR_PROPOSAL_MISSING))))
    (if (or
        (get executed proposal)
        (< stacks-block-height (get start-height proposal))
        (> stacks-block-height (get end-height proposal))
      )
      (err ERR_VOTING_CLOSED)
      (if (is-some (map-get? receipts {
          id: proposal-id,
          voter: tx-sender,
        }))
        (err ERR_ALREADY_VOTED)
        (let (
            (weight (stx-get-balance tx-sender))
            (for-delta (if (is-eq choice CHOICE_FOR)
              weight
              u0
            ))
            (against-delta (if (is-eq choice CHOICE_AGAINST)
              weight
              u0
            ))
          )
          (map-set receipts {
            id: proposal-id,
            voter: tx-sender,
          } {
            choice: choice,
            weight: weight,
          })
          (map-set proposals { id: proposal-id } {
            proposer: (get proposer proposal),
            recipient: (get recipient proposal),
            amount: (get amount proposal),
            start-height: (get start-height proposal),
            end-height: (get end-height proposal),
            for-votes: (+ (get for-votes proposal) for-delta),
            against-votes: (+ (get against-votes proposal) against-delta),
            executed: (get executed proposal),
          })
          (ok true)
        )
      )
    )
  )
)

(define-public (execute (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals { id: proposal-id }) (err ERR_PROPOSAL_MISSING))))
    (if (get executed proposal)
      (err ERR_ALREADY_EXECUTED)
      (if (< stacks-block-height (get end-height proposal))
        (err ERR_VOTING_CLOSED)
        (if (proposal-passes proposal)
          (match (as-contract? ((with-stx (get amount proposal)))
            (try! (stx-transfer? (get amount proposal) tx-sender
              (get recipient proposal)
            ))
          )
            ok-result (begin
              (map-set proposals { id: proposal-id } {
                proposer: (get proposer proposal),
                recipient: (get recipient proposal),
                amount: (get amount proposal),
                start-height: (get start-height proposal),
                end-height: (get end-height proposal),
                for-votes: (get for-votes proposal),
                against-votes: (get against-votes proposal),
                executed: true,
              })
              (ok ok-result)
            )
            err-code (err ERR_TRANSFER_FAILED)
          )
          (err ERR_NOT_PASSED)
        )
      )
    )
  )
)
