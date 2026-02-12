;; title: dispute-resolution
;; version: 1.0.0
;; summary: Handle conflicts between parties
;; description: Dispute management, evidence submission, arbitration, and automated resolution system

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-status (err u103))
(define-constant err-already-resolved (err u104))
(define-constant err-insufficient-amount (err u105))
(define-constant err-invalid-party (err u106))
(define-constant err-evidence-limit (err u107))
(define-constant err-appeal-expired (err u108))

;; Dispute status
(define-constant STATUS-OPEN u1)
(define-constant STATUS-UNDER-REVIEW u2)
(define-constant STATUS-RESOLVED u3)
(define-constant STATUS-APPEALED u4)
(define-constant STATUS-CLOSED u5)

;; Dispute types
(define-constant TYPE-PAYMENT u1)
(define-constant TYPE-FRAUD u2)
(define-constant TYPE-QUALITY u3)
(define-constant TYPE-CONTRACT-BREACH u4)

;; Resolution outcomes
(define-constant OUTCOME-ADVERTISER-WINS u1)
(define-constant OUTCOME-PUBLISHER-WINS u2)
(define-constant OUTCOME-SPLIT u3)
(define-constant OUTCOME-DISMISSED u4)

;; data vars
(define-data-var dispute-nonce uint u0)
(define-data-var min-dispute-amount uint u1000000) ;; 1 STX
(define-data-var max-evidence-per-dispute uint u10)
(define-data-var arbitration-fee-percentage uint u5) ;; 5%
(define-data-var appeal-window uint u1440) ;; ~10 days in blocks (assuming ~10min blocks)
(define-data-var auto-resolve-threshold uint u100000) ;; Small claims auto-resolve
(define-data-var total-disputes-resolved uint u0)

;; data maps
(define-map disputes
    { dispute-id: uint }
    {
        campaign-id: uint,
        advertiser: principal,
        publisher: principal,
        dispute-type: uint,
        amount: uint,
        status: uint,
        description: (string-utf8 500),
        created-at: uint,
        updated-at: uint,
        resolution-deadline: uint
    }
)

(define-map evidence-submissions
    { dispute-id: uint, evidence-id: uint }
    {
        submitter: principal,
        evidence-type: (string-ascii 30),
        evidence-hash: (string-ascii 64), ;; IPFS hash
        description: (string-utf8 300),
        submitted-at: uint
    }
)

(define-map arbitrator-assignments
    { dispute-id: uint }
    {
        arbitrator: principal,
        assigned-at: uint,
        decision-deadline: uint
    }
)

(define-map arbitrator-votes
    { dispute-id: uint, arbitrator: principal }
    {
        outcome: uint,
        reasoning: (string-utf8 500),
        voted-at: uint
    }
)

(define-map dispute-outcomes
    { dispute-id: uint }
    {
        outcome: uint,
        winner: principal,
        amount-transferred: uint,
        reasoning: (string-utf8 500),
        resolved-at: uint,
        can-appeal: bool
    }
)

(define-map evidence-count
    { dispute-id: uint }
    {
        total-evidence: uint
    }
)

(define-map dispute-history
    { party: principal }
    {
        total-disputes: uint,
        disputes-won: uint,
        disputes-lost: uint,
        reputation-score: uint
    }
)

(define-map arbitrator-stats
    { arbitrator: principal }
    {
        total-cases: uint,
        cases-resolved: uint,
        reputation: uint,
        active: bool
    }
)

;; private functions
(define-private (is-valid-dispute-type (dispute-type uint))
    (or
        (is-eq dispute-type TYPE-PAYMENT)
        (is-eq dispute-type TYPE-FRAUD)
        (is-eq dispute-type TYPE-QUALITY)
        (is-eq dispute-type TYPE-CONTRACT-BREACH)
    )
)

(define-private (is-valid-outcome (outcome uint))
    (or
        (is-eq outcome OUTCOME-ADVERTISER-WINS)
        (is-eq outcome OUTCOME-PUBLISHER-WINS)
        (is-eq outcome OUTCOME-SPLIT)
        (is-eq outcome OUTCOME-DISMISSED)
    )
)

(define-private (calculate-arbitration-fee (amount uint))
    (/ (* amount (var-get arbitration-fee-percentage)) u100)
)

(define-private (update-party-reputation (party principal) (won bool))
    (let
        (
            (history (default-to
                { total-disputes: u0, disputes-won: u0, disputes-lost: u0, reputation-score: u100 }
                (map-get? dispute-history { party: party })
            ))
        )
        (map-set dispute-history
            { party: party }
            {
                total-disputes: (+ (get total-disputes history) u1),
                disputes-won: (if won (+ (get disputes-won history) u1) (get disputes-won history)),
                disputes-lost: (if won (get disputes-lost history) (+ (get disputes-lost history) u1)),
                reputation-score: (if won
                    (let ((new-score (+ (get reputation-score history) u5))) (if (> new-score u100) u100 new-score))
                    (if (> (get reputation-score history) u5) (- (get reputation-score history) u5) u0)
                )
            }
        )
    )
)

;; read only functions
(define-read-only (get-dispute (dispute-id uint))
    (map-get? disputes { dispute-id: dispute-id })
)

(define-read-only (get-evidence (dispute-id uint) (evidence-id uint))
    (map-get? evidence-submissions { dispute-id: dispute-id, evidence-id: evidence-id })
)

(define-read-only (get-arbitrator-assignment (dispute-id uint))
    (map-get? arbitrator-assignments { dispute-id: dispute-id })
)

(define-read-only (get-arbitrator-vote (dispute-id uint) (arbitrator principal))
    (map-get? arbitrator-votes { dispute-id: dispute-id, arbitrator: arbitrator })
)

(define-read-only (get-dispute-outcome (dispute-id uint))
    (map-get? dispute-outcomes { dispute-id: dispute-id })
)

(define-read-only (get-evidence-count (dispute-id uint))
    (default-to { total-evidence: u0 } (map-get? evidence-count { dispute-id: dispute-id }))
)

(define-read-only (get-party-history (party principal))
    (map-get? dispute-history { party: party })
)

(define-read-only (get-arbitrator-stats (arbitrator principal))
    (map-get? arbitrator-stats { arbitrator: arbitrator })
)

(define-read-only (get-dispute-nonce)
    (var-get dispute-nonce)
)

(define-read-only (can-appeal (dispute-id uint))
    (match (map-get? dispute-outcomes { dispute-id: dispute-id })
        outcome (and
            (get can-appeal outcome)
            (< (- stacks-block-time (get resolved-at outcome)) (var-get appeal-window))
        )
        false
    )
)

;; public functions
(define-public (open-dispute
    (campaign-id uint)
    (other-party principal)
    (dispute-type uint)
    (amount uint)
    (description (string-utf8 500))
    (is-advertiser bool)
)
    (let
        (
            (dispute-id (+ (var-get dispute-nonce) u1))
            (advertiser (if is-advertiser tx-sender other-party))
            (publisher (if is-advertiser other-party tx-sender))
            (resolution-deadline (+ stacks-block-time u1440)) ;; ~10 days
        )
        (asserts! (is-valid-dispute-type dispute-type) err-invalid-status)
        (asserts! (>= amount (var-get min-dispute-amount)) err-insufficient-amount)
        (asserts! (not (is-eq tx-sender other-party)) err-invalid-party)

        (map-set disputes
            { dispute-id: dispute-id }
            {
                campaign-id: campaign-id,
                advertiser: advertiser,
                publisher: publisher,
                dispute-type: dispute-type,
                amount: amount,
                status: STATUS-OPEN,
                description: description,
                created-at: stacks-block-time,
                updated-at: stacks-block-time,
                resolution-deadline: resolution-deadline
            }
        )

        (map-set evidence-count
            { dispute-id: dispute-id }
            { total-evidence: u0 }
        )

        (var-set dispute-nonce dispute-id)
        (ok dispute-id)
    )
)

(define-public (submit-evidence
    (dispute-id uint)
    (evidence-type (string-ascii 30))
    (evidence-hash (string-ascii 64))
    (description (string-utf8 300))
)
    (let
        (
            (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) err-not-found))
            (count-data (get-evidence-count dispute-id))
            (evidence-id (+ (get total-evidence count-data) u1))
        )
        (asserts! (or
            (is-eq tx-sender (get advertiser dispute))
            (is-eq tx-sender (get publisher dispute))
        ) err-unauthorized)
        (asserts! (< (get total-evidence count-data) (var-get max-evidence-per-dispute)) err-evidence-limit)
        (asserts! (or
            (is-eq (get status dispute) STATUS-OPEN)
            (is-eq (get status dispute) STATUS-UNDER-REVIEW)
        ) err-invalid-status)

        (map-set evidence-submissions
            { dispute-id: dispute-id, evidence-id: evidence-id }
            {
                submitter: tx-sender,
                evidence-type: evidence-type,
                evidence-hash: evidence-hash,
                description: description,
                submitted-at: stacks-block-time
            }
        )

        (map-set evidence-count
            { dispute-id: dispute-id }
            { total-evidence: evidence-id }
        )

        (ok evidence-id)
    )
)

(define-public (assign-arbitrator (dispute-id uint) (arbitrator principal))
    (let
        (
            (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) err-not-found))
            (decision-deadline (+ stacks-block-time u720)) ;; ~5 days
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-eq (get status dispute) STATUS-OPEN) err-invalid-status)

        (map-set arbitrator-assignments
            { dispute-id: dispute-id }
            {
                arbitrator: arbitrator,
                assigned-at: stacks-block-time,
                decision-deadline: decision-deadline
            }
        )

        (map-set disputes
            { dispute-id: dispute-id }
            (merge dispute {
                status: STATUS-UNDER-REVIEW,
                updated-at: stacks-block-time
            })
        )

        (let
            (
                (arb-stats (default-to
                    { total-cases: u0, cases-resolved: u0, reputation: u100, active: true }
                    (map-get? arbitrator-stats { arbitrator: arbitrator })
                ))
            )
            (map-set arbitrator-stats
                { arbitrator: arbitrator }
                (merge arb-stats {
                    total-cases: (+ (get total-cases arb-stats) u1)
                })
            )
        )
        (ok true)
    )
)

(define-public (vote-on-dispute
    (dispute-id uint)
    (outcome uint)
    (reasoning (string-utf8 500))
)
    (let
        (
            (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) err-not-found))
            (assignment (unwrap! (map-get? arbitrator-assignments { dispute-id: dispute-id }) err-not-found))
        )
        (asserts! (is-eq tx-sender (get arbitrator assignment)) err-unauthorized)
        (asserts! (is-eq (get status dispute) STATUS-UNDER-REVIEW) err-invalid-status)
        (asserts! (is-valid-outcome outcome) err-invalid-status)

        (map-set arbitrator-votes
            { dispute-id: dispute-id, arbitrator: tx-sender }
            {
                outcome: outcome,
                reasoning: reasoning,
                voted-at: stacks-block-time
            }
        )

        (ok true)
    )
)

(define-public (execute-ruling (dispute-id uint))
    (let
        (
            (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) err-not-found))
            (vote (unwrap! (map-get? arbitrator-votes {
                dispute-id: dispute-id,
                arbitrator: (get arbitrator (unwrap! (map-get? arbitrator-assignments { dispute-id: dispute-id }) err-not-found))
            }) err-not-found))
            (outcome (get outcome vote))
            (winner (if (is-eq outcome OUTCOME-ADVERTISER-WINS)
                (get advertiser dispute)
                (if (is-eq outcome OUTCOME-PUBLISHER-WINS)
                    (get publisher dispute)
                    contract-owner
                )
            ))
            (transfer-amount (if (is-eq outcome OUTCOME-SPLIT)
                (/ (get amount dispute) u2)
                (get amount dispute)
            ))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-eq (get status dispute) STATUS-UNDER-REVIEW) err-invalid-status)

        ;; Update dispute status
        (map-set disputes
            { dispute-id: dispute-id }
            (merge dispute {
                status: STATUS-RESOLVED,
                updated-at: stacks-block-time
            })
        )

        ;; Record outcome
        (map-set dispute-outcomes
            { dispute-id: dispute-id }
            {
                outcome: outcome,
                winner: winner,
                amount-transferred: transfer-amount,
                reasoning: (get reasoning vote),
                resolved-at: stacks-block-time,
                can-appeal: (>= (get amount dispute) (* (var-get auto-resolve-threshold) u5))
            }
        )

        ;; Update reputations
        (update-party-reputation (get advertiser dispute) (is-eq outcome OUTCOME-ADVERTISER-WINS))
        (update-party-reputation (get publisher dispute) (is-eq outcome OUTCOME-PUBLISHER-WINS))

        ;; Update arbitrator stats
        (let
            (
                (assignment (unwrap! (map-get? arbitrator-assignments { dispute-id: dispute-id }) err-not-found))
                (arb-stats (unwrap! (map-get? arbitrator-stats { arbitrator: (get arbitrator assignment) }) err-not-found))
            )
            (map-set arbitrator-stats
                { arbitrator: (get arbitrator assignment) }
                (merge arb-stats {
                    cases-resolved: (+ (get cases-resolved arb-stats) u1)
                })
            )
        )

        (var-set total-disputes-resolved (+ (var-get total-disputes-resolved) u1))
        (ok true)
    )
)

(define-public (appeal-decision (dispute-id uint) (reason (string-utf8 500)))
    (let
        (
            (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) err-not-found))
            (outcome (unwrap! (map-get? dispute-outcomes { dispute-id: dispute-id }) err-not-found))
        )
        (asserts! (or
            (is-eq tx-sender (get advertiser dispute))
            (is-eq tx-sender (get publisher dispute))
        ) err-unauthorized)
        (asserts! (get can-appeal outcome) err-invalid-status)
        (asserts! (< (- stacks-block-time (get resolved-at outcome)) (var-get appeal-window)) err-appeal-expired)

        (map-set disputes
            { dispute-id: dispute-id }
            (merge dispute {
                status: STATUS-APPEALED,
                updated-at: stacks-block-time
            })
        )

        (ok true)
    )
)

(define-public (auto-resolve-dispute (dispute-id uint))
    (let
        (
            (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) err-not-found))
        )
        (asserts! (<= (get amount dispute) (var-get auto-resolve-threshold)) err-insufficient-amount)
        (asserts! (is-eq (get status dispute) STATUS-OPEN) err-invalid-status)

        (map-set disputes
            { dispute-id: dispute-id }
            (merge dispute {
                status: STATUS-RESOLVED,
                updated-at: stacks-block-time
            })
        )

        (map-set dispute-outcomes
            { dispute-id: dispute-id }
            {
                outcome: OUTCOME-SPLIT,
                winner: contract-owner,
                amount-transferred: (/ (get amount dispute) u2),
                reasoning: u"Auto-resolved: small claim split 50/50",
                resolved-at: stacks-block-time,
                can-appeal: false
            }
        )

        (var-set total-disputes-resolved (+ (var-get total-disputes-resolved) u1))
        (ok true)
    )
)

(define-public (close-dispute (dispute-id uint))
    (let
        (
            (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) err-not-found))
        )
        (asserts! (is-eq (get status dispute) STATUS-RESOLVED) err-invalid-status)

        (map-set disputes
            { dispute-id: dispute-id }
            (merge dispute {
                status: STATUS-CLOSED,
                updated-at: stacks-block-time
            })
        )
        (ok true)
    )
)

;; Admin functions
(define-public (register-arbitrator (arbitrator principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)

        (map-set arbitrator-stats
            { arbitrator: arbitrator }
            {
                total-cases: u0,
                cases-resolved: u0,
                reputation: u100,
                active: true
            }
        )
        (ok true)
    )
)

(define-public (deactivate-arbitrator (arbitrator principal))
    (let
        (
            (stats (unwrap! (map-get? arbitrator-stats { arbitrator: arbitrator }) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)

        (map-set arbitrator-stats
            { arbitrator: arbitrator }
            (merge stats { active: false })
        )
        (ok true)
    )
)

(define-public (set-auto-resolve-threshold (new-threshold uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set auto-resolve-threshold new-threshold)
        (ok true)
    )
)

(define-public (set-appeal-window (new-window uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set appeal-window new-window)
        (ok true)
    )
)
