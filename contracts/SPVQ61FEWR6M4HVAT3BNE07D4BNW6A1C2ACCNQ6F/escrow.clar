;; FreelanceGuard Escrow Smart Contract
;; Milestone-based escrow system for freelancer payments

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ESCROW-NOT-FOUND (err u101))
(define-constant ERR-INVALID-MILESTONE (err u102))
(define-constant ERR-ALREADY-SUBMITTED (err u103))
(define-constant ERR-NOT-SUBMITTED (err u104))
(define-constant ERR-ALREADY-APPROVED (err u105))
(define-constant ERR-INSUFFICIENT-FUNDS (err u106))
(define-constant ERR-MILESTONE-NOT-APPROVED (err u107))
(define-constant ERR-DISPUTE-EXISTS (err u108))
(define-constant ERR-NO-DISPUTE (err u109))
(define-constant ERR-INVALID-AMOUNT (err u110))
(define-constant ERR-ESCROW-COMPLETED (err u111))
(define-constant ERR-ESCROW-CANCELLED (err u112))

;; Status constants
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-COMPLETED u2)
(define-constant STATUS-CANCELLED u3)
(define-constant STATUS-DISPUTED u4)

;; Milestone status constants
(define-constant MILESTONE-PENDING u1)
(define-constant MILESTONE-SUBMITTED u2)
(define-constant MILESTONE-APPROVED u3)
(define-constant MILESTONE-REJECTED u4)
(define-constant MILESTONE-DISPUTED u5)

;; Data Variables
(define-data-var escrow-nonce uint u0)

;; Helper Functions for Enhanced Validation

;; Validate string is not empty
(define-private (is-valid-string (str (string-ascii 256)))
  (> (len str) u0)
)

;; Check if deadline is in the future
(define-private (is-future-deadline (deadline uint))
  (> deadline stacks-block-height)
)

;; Data Maps
(define-map escrows
  uint
  {
    client: principal,
    freelancer: principal,
    arbitrator: principal,
    total-amount: uint,
    paid-amount: uint,
    status: uint,
    created-at: uint,
    metadata: (string-ascii 256)
  }
)

(define-map milestones
  { escrow-id: uint, milestone-id: uint }
  {
    label: (string-ascii 128),
    amount: uint,
    deadline: uint,
    status: uint,
    deliverable: (optional (string-ascii 512)),
    submitted-at: (optional uint),
    approved-at: (optional uint)
  }
)

(define-map escrow-milestone-count
  uint
  uint
)

(define-map disputes
  uint
  {
    raised-by: principal,
    milestone-id: uint,
    reason: (string-ascii 512),
    resolved: bool,
    resolution: (optional (string-ascii 512)),
    resolved-at: (optional uint)
  }
)

;; Read-only functions

(define-read-only (get-escrow (escrow-id uint))
  (map-get? escrows escrow-id)
)

(define-read-only (get-milestone (escrow-id uint) (milestone-id uint))
  (map-get? milestones { escrow-id: escrow-id, milestone-id: milestone-id })
)

(define-read-only (get-milestone-count (escrow-id uint))
  (default-to u0 (map-get? escrow-milestone-count escrow-id))
)

(define-read-only (get-dispute (escrow-id uint))
  (map-get? disputes escrow-id)
)

(define-read-only (get-escrow-nonce)
  (var-get escrow-nonce)
)

;; Private functions

(define-private (is-client (escrow-id uint) (caller principal))
  (match (map-get? escrows escrow-id)
    escrow (is-eq (get client escrow) caller)
    false
  )
)

(define-private (is-freelancer (escrow-id uint) (caller principal))
  (match (map-get? escrows escrow-id)
    escrow (is-eq (get freelancer escrow) caller)
    false
  )
)

(define-private (is-arbitrator (escrow-id uint) (caller principal))
  (match (map-get? escrows escrow-id)
    escrow (is-eq (get arbitrator escrow) caller)
    false
  )
)

(define-private (is-escrow-active (escrow-id uint))
  (match (map-get? escrows escrow-id)
    escrow (is-eq (get status escrow) STATUS-ACTIVE)
    false
  )
)

;; Public functions

;; Create a new escrow agreement
(define-public (create-escrow 
    (freelancer principal)
    (arbitrator principal)
    (total-amount uint)
    (metadata (string-ascii 256)))
  (let
    (
      (escrow-id (+ (var-get escrow-nonce) u1))
    )
    (asserts! (> total-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (is-valid-string metadata) ERR-INVALID-AMOUNT)
    
    ;; Transfer funds from client to contract
    (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
    
    ;; Create escrow record
    (map-set escrows escrow-id {
      client: tx-sender,
      freelancer: freelancer,
      arbitrator: arbitrator,
      total-amount: total-amount,
      paid-amount: u0,
      status: STATUS-ACTIVE,
      created-at: stacks-block-height,
      metadata: metadata
    })
    
    ;; Initialize milestone count
    (map-set escrow-milestone-count escrow-id u0)
    
    ;; Increment nonce
    (var-set escrow-nonce escrow-id)
    
    (print {
      event: "escrow-created",
      escrow-id: escrow-id,
      client: tx-sender,
      freelancer: freelancer,
      amount: total-amount
    })
    
    (ok escrow-id)
  )
)

;; Add a milestone to an escrow
(define-public (add-milestone
    (escrow-id uint)
    (label (string-ascii 128))
    (amount uint)
    (deadline uint))
  (let
    (
      (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
      (current-count (get-milestone-count escrow-id))
      (new-milestone-id (+ current-count u1))
    )
    ;; Only client can add milestones
    (asserts! (is-eq tx-sender (get client escrow)) ERR-NOT-AUTHORIZED)
    
    ;; Escrow must be active
    (asserts! (is-eq (get status escrow) STATUS-ACTIVE) ERR-ESCROW-COMPLETED)
    
    ;; Amount must be valid
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Validate label is not empty (Clarity 4 string validation)
    (asserts! (> (len label) u0) ERR-INVALID-AMOUNT)
    
    ;; Validate deadline is in the future
    (asserts! (is-future-deadline deadline) ERR-INVALID-AMOUNT)
    
    ;; Create milestone
    (map-set milestones 
      { escrow-id: escrow-id, milestone-id: new-milestone-id }
      {
        label: label,
        amount: amount,
        deadline: deadline,
        status: MILESTONE-PENDING,
        deliverable: none,
        submitted-at: none,
        approved-at: none
      }
    )
    
    ;; Update milestone count
    (map-set escrow-milestone-count escrow-id new-milestone-id)
    
    (print {
      event: "milestone-added",
      escrow-id: escrow-id,
      milestone-id: new-milestone-id,
      amount: amount
    })
    
    (ok new-milestone-id)
  )
)

;; Submit a milestone deliverable
(define-public (submit-milestone
    (escrow-id uint)
    (milestone-id uint)
    (deliverable (string-ascii 512)))
  (let
    (
      (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
      (milestone (unwrap! (map-get? milestones { escrow-id: escrow-id, milestone-id: milestone-id }) ERR-INVALID-MILESTONE))
    )
    ;; Only freelancer can submit
    (asserts! (is-eq tx-sender (get freelancer escrow)) ERR-NOT-AUTHORIZED)
    
    ;; Escrow must be active
    (asserts! (is-eq (get status escrow) STATUS-ACTIVE) ERR-ESCROW-COMPLETED)
    
    ;; Milestone must be pending or rejected
    (asserts! (or 
      (is-eq (get status milestone) MILESTONE-PENDING)
      (is-eq (get status milestone) MILESTONE-REJECTED)
    ) ERR-ALREADY-SUBMITTED)
    
    ;; Validate deliverable is not empty (Clarity 4 string validation)
    (asserts! (> (len deliverable) u0) ERR-INVALID-AMOUNT)
    
    ;; Update milestone with deliverable
    (map-set milestones 
      { escrow-id: escrow-id, milestone-id: milestone-id }
      (merge milestone {
        status: MILESTONE-SUBMITTED,
        deliverable: (some deliverable),
        submitted-at: (some stacks-block-height)
      })
    )
    
    (print {
      event: "milestone-submitted",
      escrow-id: escrow-id,
      milestone-id: milestone-id,
      freelancer: tx-sender
    })
    
    (ok true)
  )
)

;; Approve a milestone and release payment
(define-public (approve-milestone
    (escrow-id uint)
    (milestone-id uint))
  (let
    (
      (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
      (milestone (unwrap! (map-get? milestones { escrow-id: escrow-id, milestone-id: milestone-id }) ERR-INVALID-MILESTONE))
      (milestone-amount (get amount milestone))
      (new-paid-amount (+ (get paid-amount escrow) milestone-amount))
    )
    ;; Only client can approve
    (asserts! (is-eq tx-sender (get client escrow)) ERR-NOT-AUTHORIZED)
    
    ;; Escrow must be active
    (asserts! (is-eq (get status escrow) STATUS-ACTIVE) ERR-ESCROW-COMPLETED)
    
    ;; Milestone must be submitted
    (asserts! (is-eq (get status milestone) MILESTONE-SUBMITTED) ERR-NOT-SUBMITTED)
    
    ;; Update milestone status
    (map-set milestones 
      { escrow-id: escrow-id, milestone-id: milestone-id }
      (merge milestone {
        status: MILESTONE-APPROVED,
        approved-at: (some stacks-block-height)
      })
    )
    
    ;; Transfer payment to freelancer
    (try! (as-contract (stx-transfer? milestone-amount tx-sender (get freelancer escrow))))
    
    ;; Update escrow paid amount
    (map-set escrows escrow-id
      (merge escrow {
        paid-amount: new-paid-amount
      })
    )
    
    ;; Check if all milestones completed
    (if (is-eq new-paid-amount (get total-amount escrow))
      (map-set escrows escrow-id
        (merge escrow {
          paid-amount: new-paid-amount,
          status: STATUS-COMPLETED
        })
      )
      true
    )
    
    (print {
      event: "milestone-approved",
      escrow-id: escrow-id,
      milestone-id: milestone-id,
      amount: milestone-amount,
      freelancer: (get freelancer escrow)
    })
    
    (ok true)
  )
)

;; Reject a milestone
(define-public (reject-milestone
    (escrow-id uint)
    (milestone-id uint))
  (let
    (
      (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
      (milestone (unwrap! (map-get? milestones { escrow-id: escrow-id, milestone-id: milestone-id }) ERR-INVALID-MILESTONE))
    )
    ;; Only client can reject
    (asserts! (is-eq tx-sender (get client escrow)) ERR-NOT-AUTHORIZED)
    
    ;; Escrow must be active
    (asserts! (is-eq (get status escrow) STATUS-ACTIVE) ERR-ESCROW-COMPLETED)
    
    ;; Milestone must be submitted
    (asserts! (is-eq (get status milestone) MILESTONE-SUBMITTED) ERR-NOT-SUBMITTED)
    
    ;; Update milestone status to rejected
    (map-set milestones 
      { escrow-id: escrow-id, milestone-id: milestone-id }
      (merge milestone {
        status: MILESTONE-REJECTED
      })
    )
    
    (print {
      event: "milestone-rejected",
      escrow-id: escrow-id,
      milestone-id: milestone-id
    })
    
    (ok true)
  )
)

;; Raise a dispute
(define-public (raise-dispute
    (escrow-id uint)
    (milestone-id uint)
    (reason (string-ascii 512)))
  (let
    (
      (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
      (milestone (unwrap! (map-get? milestones { escrow-id: escrow-id, milestone-id: milestone-id }) ERR-INVALID-MILESTONE))
    )
    ;; Only client or freelancer can raise dispute
    (asserts! (or 
      (is-eq tx-sender (get client escrow))
      (is-eq tx-sender (get freelancer escrow))
    ) ERR-NOT-AUTHORIZED)
    
    ;; Escrow must be active
    (asserts! (is-eq (get status escrow) STATUS-ACTIVE) ERR-ESCROW-COMPLETED)
    
    ;; No existing dispute
    (asserts! (is-none (map-get? disputes escrow-id)) ERR-DISPUTE-EXISTS)
    
    ;; Milestone must be submitted or rejected
    (asserts! (or
      (is-eq (get status milestone) MILESTONE-SUBMITTED)
      (is-eq (get status milestone) MILESTONE-REJECTED)
    ) ERR-INVALID-MILESTONE)
    
    ;; Validate reason is not empty (Clarity 4 string validation)
    (asserts! (> (len reason) u0) ERR-INVALID-AMOUNT)
    
    ;; Create dispute
    (map-set disputes escrow-id {
      raised-by: tx-sender,
      milestone-id: milestone-id,
      reason: reason,
      resolved: false,
      resolution: none,
      resolved-at: none
    })
    
    ;; Update milestone status
    (map-set milestones 
      { escrow-id: escrow-id, milestone-id: milestone-id }
      (merge milestone {
        status: MILESTONE-DISPUTED
      })
    )
    
    ;; Update escrow status
    (map-set escrows escrow-id
      (merge escrow {
        status: STATUS-DISPUTED
      })
    )
    
    (print {
      event: "dispute-raised",
      escrow-id: escrow-id,
      milestone-id: milestone-id,
      raised-by: tx-sender
    })
    
    (ok true)
  )
)

;; Resolve a dispute (arbitrator only)
(define-public (resolve-dispute
    (escrow-id uint)
    (award-to-freelancer bool)
    (resolution (string-ascii 512)))
  (let
    (
      (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
      (dispute (unwrap! (map-get? disputes escrow-id) ERR-NO-DISPUTE))
      (milestone (unwrap! (map-get? milestones { escrow-id: escrow-id, milestone-id: (get milestone-id dispute) }) ERR-INVALID-MILESTONE))
      (milestone-amount (get amount milestone))
    )
    ;; Only arbitrator can resolve
    (asserts! (is-eq tx-sender (get arbitrator escrow)) ERR-NOT-AUTHORIZED)
    
    ;; Dispute must not be resolved
    (asserts! (not (get resolved dispute)) ERR-NO-DISPUTE)
    
    ;; Validate resolution is not empty (Clarity 4 string validation)
    (asserts! (> (len resolution) u0) ERR-INVALID-AMOUNT)
    
    ;; Update dispute
    (map-set disputes escrow-id
      (merge dispute {
        resolved: true,
        resolution: (some resolution),
        resolved-at: (some stacks-block-height)
      })
    )
    
    ;; Process payment based on decision
    (if award-to-freelancer
      (begin
        ;; Award to freelancer
        (try! (as-contract (stx-transfer? milestone-amount tx-sender (get freelancer escrow))))
        
        ;; Update milestone as approved
        (map-set milestones 
          { escrow-id: escrow-id, milestone-id: (get milestone-id dispute) }
          (merge milestone {
            status: MILESTONE-APPROVED,
            approved-at: (some stacks-block-height)
          })
        )
        
        ;; Update escrow paid amount
        (map-set escrows escrow-id
          (merge escrow {
            paid-amount: (+ (get paid-amount escrow) milestone-amount),
            status: STATUS-ACTIVE
          })
        )
      )
      ;; Refund stays in contract for client
      (begin
        ;; Update milestone as rejected
        (map-set milestones 
          { escrow-id: escrow-id, milestone-id: (get milestone-id dispute) }
          (merge milestone {
            status: MILESTONE-REJECTED
          })
        )
        
        ;; Update escrow status back to active
        (map-set escrows escrow-id
          (merge escrow {
            status: STATUS-ACTIVE
          })
        )
      )
    )
    
    (print {
      event: "dispute-resolved",
      escrow-id: escrow-id,
      milestone-id: (get milestone-id dispute),
      award-to-freelancer: award-to-freelancer,
      arbitrator: tx-sender
    })
    
    (ok true)
  )
)

;; Cancel escrow (mutual agreement or timeout)
(define-public (cancel-escrow
    (escrow-id uint))
  (let
    (
      (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
      (refund-amount (- (get total-amount escrow) (get paid-amount escrow)))
    )
    ;; Only client can cancel
    (asserts! (is-eq tx-sender (get client escrow)) ERR-NOT-AUTHORIZED)
    
    ;; Escrow must be active (no disputes)
    (asserts! (is-eq (get status escrow) STATUS-ACTIVE) ERR-ESCROW-COMPLETED)
    
    ;; Refund remaining amount to client
    (if (> refund-amount u0)
      (try! (as-contract (stx-transfer? refund-amount tx-sender (get client escrow))))
      true
    )
    
    ;; Update escrow status
    (map-set escrows escrow-id
      (merge escrow {
        status: STATUS-CANCELLED
      })
    )
    
    (print {
      event: "escrow-cancelled",
      escrow-id: escrow-id,
      refunded: refund-amount
    })
    
    (ok true)
  )
)
