;; title: crowdfunding-goal-engine
;; summary: Funds are locked until a goal is met or the deadline passes.

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant TARGET-GOAL u5000000000) ;; 5,000 STX Goal
(define-constant DEADLINE-BLOCKS u144)    ;; ~24 hours from deployment
(define-constant DEPLOY-HEIGHT burn-block-height)

;; Error Codes
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-GOAL-NOT-MET (err u402))
(define-constant ERR-DEADLINE-PASSED (err u403))
(define-constant ERR-DEADLINE-NOT-REACHED (err u404))
(define-constant ERR-NO-CONTRIBUTION (err u405))

;; Data Storage
(define-map Contributions principal uint)
(define-data-var total-raised uint u0)

;; Public Functions

;; 1. Contribute: Send STX to the project
(define-public (contribute (amount uint))
    (let (
        (current-contribution (default-to u0 (map-get? Contributions tx-sender)))
    )
    (begin
        ;; Cannot contribute after the deadline
        (asserts! (< burn-block-height (+ DEPLOY-HEIGHT DEADLINE-BLOCKS)) ERR-DEADLINE-PASSED)
        
        ;; Move STX to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Update records
        (map-set Contributions tx-sender (+ current-contribution amount))
        (var-set total-raised (+ (var-get total-raised) amount))
        (ok true)
    )
    )
)

;; 2. Payout: Creator claims funds if goal is met
(define-public (claim-payout)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (>= (var-get total-raised) TARGET-GOAL) ERR-GOAL-NOT-MET)
        
        ;; Send all funds to creator
        (as-contract (stx-transfer? (stx-get-balance (as-contract tx-sender)) (as-contract tx-sender) CONTRACT-OWNER))
    )
)

;; 3. Refund: Donors claim back STX if deadline passes and goal is NOT met
(define-public (claim-refund)
    (let (
        (amount (unwrap! (map-get? Contributions tx-sender) ERR-NO-CONTRIBUTION))
    )
    (begin
        ;; Must be after deadline
        (asserts! (>= burn-block-height (+ DEPLOY-HEIGHT DEADLINE-BLOCKS)) ERR-DEADLINE-NOT-REACHED)
        ;; Goal must have failed
        (asserts! (< (var-get total-raised) TARGET-GOAL) (err u406))
        
        ;; Reset contribution to zero BEFORE sending to prevent multi-claims
        (map-delete Contributions tx-sender)
        (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender))
    )
    )
)

;; Read-Only Functions
(define-read-only (get-project-status)
    {
        raised: (var-get total-raised),
        goal: TARGET-GOAL,
        deadline: (+ DEPLOY-HEIGHT DEADLINE-BLOCKS),
        current-height: burn-block-height,
        is-active: (< burn-block-height (+ DEPLOY-HEIGHT DEADLINE-BLOCKS))
    }
)
