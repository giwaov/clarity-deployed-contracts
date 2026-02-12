;; title: guardstack
;; version:
;; summary:
;; description:

;; Decentralized Insurance Smart Contract
;; Implements advanced insurance functionality with multi-tier policies, staking, and risk assessment

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u1))
(define-constant ERR-NO-POLICY-EXISTS (err u2))
(define-constant ERR-FUNDS-INSUFFICIENT (err u3))
(define-constant ERR-INVALID-PARAMETERS (err u4))
(define-constant ERR-POLICY-TERMINATED (err u5))
(define-constant ERR-DUPLICATE-CLAIM (err u6))
(define-constant ERR-INVALID-CLAIM-DATA (err u7))
(define-constant ERR-STAKE-TOO-LOW (err u8))
(define-constant ERR-COOLDOWN-ACTIVE (err u9))
(define-constant ERR-RISK-SCORE-HIGH (err u10))
(define-constant ERR-MAX-COVERAGE-EXCEEDED (err u11))

;; Constants
(define-constant RISK-THRESHOLD u75)
(define-constant MIN-STAKE-AMOUNT u1000000)
(define-constant CLAIM-COOLDOWN-PERIOD u144) ;; ~1 day in blocks
(define-constant MAX-COVERAGE-MULTIPLIER u5)

;; Data variables
(define-data-var reserve-pool uint u0)
(define-data-var stake-pool uint u0)
(define-data-var protocol-owner principal tx-sender)
(define-data-var base-premium uint u1000000)
(define-data-var claim-ceiling uint u100000000)
(define-data-var total-policies uint u0)
(define-data-var total-active-claims uint u0)

;; Policy tiers
(define-map policy-tiers 
    uint 
    {
        name: (string-ascii 20),
        coverage-multiplier: uint,
        premium-discount: uint,
        min-stake: uint
    }
)

;; Policy structure
(define-map insurance-policies
    principal
    {
        tier: uint,
        premium-paid: uint,
        coverage-limit: uint,
        stake-amount: uint,
        start-block: uint,
        expiry-block: uint,
        risk-score: uint,
        claims-made: uint,
        status: (string-ascii 10),
        last-claim-block: uint
    }
)

;; Claims structure
(define-map insurance-claims
    {policyholder: principal, claim-id: uint}
    {
        amount-requested: uint,
        evidence-hash: (buff 32),
        timestamp: uint,
        assessor: principal,
        verdict: (string-ascii 20),
        payout-amount: uint,
        category: (string-ascii 30)
    }
)

;; Staking and rewards
(define-map staker-info
    principal
    {
        amount: uint,
        rewards: uint,
        lock-period: uint,
        last-reward-block: uint
    }
)

;; Risk assessment data
(define-map risk-profiles
    principal
    {
        base-score: uint,
        claim-history: uint,
        stake-weight: uint,
        duration-multiplier: uint
    }
)

;; Read-only functions
(define-read-only (get-insurance-policy (policyholder principal))
    (map-get? insurance-policies policyholder)
)

(define-read-only (get-claim-details (policyholder principal) (claim-id uint))
    (map-get? insurance-claims {policyholder: policyholder, claim-id: claim-id})
)

(define-read-only (get-risk-profile (user principal))
    (map-get? risk-profiles user)
)

;; calculate-premiums function
(define-read-only (calculate-premiums (tier uint) (coverage uint) (risk-score uint))
    (let (
        (tier-info (unwrap! (map-get? policy-tiers tier) ERR-INVALID-PARAMETERS))
        (base-amount (var-get base-premium))
        (risk-multiplier (+ u100 risk-score))
    )
    (ok (/ (* (* coverage risk-multiplier) (- u100 (get premium-discount tier-info))) u10000)))
)

;; Private functions
(define-private (verify-policy-active (policyholder principal))
    (match (map-get? insurance-policies policyholder)
        policy (and
            (is-eq (get status policy) "ACTIVE")
            (<= stacks-block-height (get expiry-block policy))
        )
        false
    )
)

(define-private (calculate-risk-score (user principal))
    (let (
        (profile (unwrap! (map-get? risk-profiles user) u50))
        (base (get base-score profile))
        (claims (get claim-history profile))
        (stake (get stake-weight profile))
    )
    (/ (+ (* base u2) (* claims u3) (* stake u1)) u6))
)

;; Public functions
(define-public (initialize-policy-tiers)
    (begin
        (asserts! (is-eq tx-sender (var-get protocol-owner)) ERR-UNAUTHORIZED)

        ;; Basic tier
        (map-set policy-tiers u1 {
            name: "BASIC",
            coverage-multiplier: u1,
            premium-discount: u0,
            min-stake: MIN-STAKE-AMOUNT
        })

        ;; Premium tier
        (map-set policy-tiers u2 {
            name: "PREMIUM",
            coverage-multiplier: u2,
            premium-discount: u10,
            min-stake: (* MIN-STAKE-AMOUNT u2)
        })

        ;; Elite tier
        (map-set policy-tiers u3 {
            name: "ELITE",
            coverage-multiplier: u3,
            premium-discount: u20,
            min-stake: (* MIN-STAKE-AMOUNT u3)
        })

        (ok true)
    )
)


(define-public (submit-enhanced-claim 
    (amount uint) 
    (evidence-hash (buff 32))
    (category (string-ascii 30)))
    (let (
        (policy (unwrap! (map-get? insurance-policies tx-sender) ERR-NO-POLICY-EXISTS))
        (claim-id (get claims-made policy))
    )
    ;; Validate claim
    (asserts! (verify-policy-active tx-sender) ERR-POLICY-TERMINATED)
    (asserts! (<= amount (get coverage-limit policy)) ERR-INVALID-PARAMETERS)
    (asserts! (> (- stacks-block-height (get last-claim-block policy)) CLAIM-COOLDOWN-PERIOD) ERR-COOLDOWN-ACTIVE)

    ;; Create claim
    (map-set insurance-claims 
        {policyholder: tx-sender, claim-id: claim-id}
        {
            amount-requested: amount,
            evidence-hash: evidence-hash,
            timestamp: stacks-block-height,
            assessor: (var-get protocol-owner),
            verdict: "PENDING",
            payout-amount: u0,
            category: category
        })

    ;; Update policy
    (ok (map-set insurance-policies tx-sender 
        (merge policy {
            claims-made: (+ claim-id u1),
            last-claim-block: stacks-block-height
        })))
))





;; Administrative functions
(define-public (update-protocol-parameters 
    (new-base-premium uint)
    (new-claim-ceiling uint)
    (new-risk-threshold uint))
    (begin
        (asserts! (is-eq tx-sender (var-get protocol-owner)) ERR-UNAUTHORIZED)
        (var-set base-premium new-base-premium)
        (var-set claim-ceiling new-claim-ceiling)
        (ok true)
    )
)

(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get protocol-owner)) ERR-UNAUTHORIZED)
        (ok (var-set protocol-owner new-owner))
    )
)


