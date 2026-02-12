;; title: role-based-access
;; version:
;; summary:
;; description:

;; Decentralized Information Marketplace Smart Contract
;; A trustless platform enabling users to post information requests with monetary rewards,
;; allowing knowledge providers to submit solutions and earn STX tokens upon selection.
;; Features automated escrow, fair dispute resolution, and community-driven knowledge sharing.

;; ERROR CONSTANTS

(define-constant ERR-OWNER-ONLY-OPERATION (err u100))
(define-constant ERR-INFORMATION-REQUEST-NOT-FOUND (err u101))
(define-constant ERR-UNAUTHORIZED-ACCESS (err u102))
(define-constant ERR-INVALID-REWARD-AMOUNT (err u103))
(define-constant ERR-REQUEST-ALREADY-CLOSED (err u104))
(define-constant ERR-REQUEST-HAS-EXPIRED (err u105))
(define-constant ERR-DUPLICATE-SUBMISSION-ATTEMPT (err u106))
(define-constant ERR-INSUFFICIENT-CONTRACT-BALANCE (err u107))
(define-constant ERR-INVALID-INPUT-PARAMETERS (err u108))
(define-constant ERR-REQUEST-HAS-ACTIVE-SUBMISSIONS (err u109))
(define-constant ERR-NO-SUBMISSIONS-FOUND (err u110))
(define-constant ERR-SUBMISSION-DOES-NOT-EXIST (err u111))

;; CONFIGURATION CONSTANTS

(define-constant contract-administrator tx-sender)
(define-constant maximum-title-length u128)
(define-constant maximum-description-length u512)
(define-constant maximum-solution-content-length u1024)
(define-constant maximum-user-requests-limit u100)
(define-constant maximum-user-submissions-limit u100)
(define-constant default-platform-commission-rate u250) ;; 2.5% in basis points
(define-constant minimum-information-request-reward u1000000) ;; 1 STX
(define-constant maximum-request-duration-blocks u4320) ;; 30 days (144 blocks/day)
(define-constant basis-points-denominator u10000)

;; STATE VARIABLES

(define-data-var information-request-counter uint u0)
(define-data-var platform-commission-rate uint default-platform-commission-rate)
(define-data-var minimum-reward-threshold uint minimum-information-request-reward)
(define-data-var maximum-duration-limit uint maximum-request-duration-blocks)

;; DATA STRUCTURES

;; Main information request registry
(define-map information-requests-registry
    uint
    {
        request-creator: principal,
        request-title: (string-ascii 128),
        detailed-description: (string-utf8 512),
        reward-pool-amount: uint,
        expiration-block-height: uint,
        current-status: (string-ascii 16),
        selected-solution-provider: (optional principal),
        request-creation-block: uint
    }
)

;; Solutions submitted for each request
(define-map solution-submissions-registry
    {information-request-id: uint, solution-provider: principal}
    {
        solution-content-data: (string-utf8 1024),
        submission-block-height: uint,
        is-selected-solution: bool
    }
)

;; Track submission counts per request
(define-map request-submission-counters
    uint
    uint
)

;; User's created requests tracking
(define-map user-created-requests-log
    principal
    (list 100 uint)
)

;; User's submission history tracking
(define-map user-submission-history-log
    principal
    (list 100 {request-id: uint, submission-timestamp: uint})
)

;; READ-ONLY QUERY FUNCTIONS

(define-read-only (get-information-request-details (request-id uint))
    (map-get? information-requests-registry request-id)
)

(define-read-only (get-solution-submission-details (request-id uint) (provider principal))
    (map-get? solution-submissions-registry {information-request-id: request-id, solution-provider: provider})
)

(define-read-only (get-total-submissions-for-request (request-id uint))
    (default-to u0 (map-get? request-submission-counters request-id))
)

(define-read-only (get-user-created-requests-list (user-address principal))
    (default-to (list) (map-get? user-created-requests-log user-address))
)

(define-read-only (get-user-submission-history (user-address principal))
    (default-to (list) (map-get? user-submission-history-log user-address))
)

(define-read-only (get-current-platform-commission-rate)
    (var-get platform-commission-rate)
)

(define-read-only (get-minimum-reward-threshold)
    (var-get minimum-reward-threshold)
)

(define-read-only (get-total-information-requests-count)
    (var-get information-request-counter)
)

(define-read-only (check-if-request-is-active (request-id uint))
    (match (map-get? information-requests-registry request-id)
        request-details
        (and 
            (is-eq (get current-status request-details) "active")
            (< stacks-block-height (get expiration-block-height request-details))
        )
        false
    )
)

(define-read-only (calculate-platform-commission-fee (reward-amount uint))
    (/ (* reward-amount (var-get platform-commission-rate)) basis-points-denominator)
)

(define-read-only (calculate-final-solution-provider-payout (reward-amount uint))
    (- reward-amount (calculate-platform-commission-fee reward-amount))
)

;; INTERNAL UTILITY FUNCTIONS

(define-private (append-request-to-user-log (user-address principal) (request-id uint))
    (let 
        (
            (existing-user-requests (get-user-created-requests-list user-address))
            (updated-list (unwrap! (as-max-len? (append existing-user-requests request-id) u100) 
                (err u999)))
        )
        (map-set user-created-requests-log user-address updated-list)
        (ok true)
    )
)

(define-private (append-submission-to-user-history (user-address principal) (request-id uint))
    (let 
        (
            (existing-submission-history (get-user-submission-history user-address))
            (new-submission-entry {request-id: request-id, submission-timestamp: stacks-block-height})
            (updated-list (unwrap! (as-max-len? (append existing-submission-history new-submission-entry) u100) 
                (err u999)))
        )
        (map-set user-submission-history-log user-address updated-list)
        (ok true)
    )
)

(define-private (update-information-request-status 
    (request-id uint) 
    (new-status (string-ascii 16)) 
    (solution-provider-address (optional principal))
)
    (match (map-get? information-requests-registry request-id)
        existing-request-data
        (begin
            (map-set information-requests-registry request-id 
                (merge existing-request-data {
                    current-status: new-status, 
                    selected-solution-provider: solution-provider-address
                })
            )
            (ok true)
        )
        (err u999)
    )
)

(define-private (validate-principal-not-empty (address principal))
    (not (is-eq address 'SP000000000000000000002Q6VF78))
)

(define-private (validate-amount-greater-than-zero (amount uint))
    (> amount u0)
)

(define-private (validate-input-string-length (input-string (string-utf8 1024)) (max-length uint))
    (and (> (len input-string) u0) (<= (len input-string) max-length))
)

(define-private (validate-ascii-string-length (input-string (string-ascii 128)) (max-length uint))
    (and (> (len input-string) u0) (<= (len input-string) max-length))
)

;; CORE BUSINESS LOGIC FUNCTIONS


(define-public (submit-solution-for-request 
    (request-id uint) 
    (solution-content (string-utf8 1024))
)
    (let 
        (
            (request-details (unwrap! (map-get? information-requests-registry request-id) ERR-INFORMATION-REQUEST-NOT-FOUND))
            (submission-identifier {information-request-id: request-id, solution-provider: tx-sender})
        )
        ;; Verify request is still active and not expired
        (asserts! (check-if-request-is-active request-id) ERR-REQUEST-ALREADY-CLOSED)
        
        ;; Validate solution content
        (asserts! (validate-input-string-length solution-content u1024) ERR-INVALID-INPUT-PARAMETERS)
        
        ;; Prevent duplicate submissions from same user
        (asserts! (is-none (map-get? solution-submissions-registry submission-identifier)) ERR-DUPLICATE-SUBMISSION-ATTEMPT)
        
        ;; Record the solution submission
        (map-set solution-submissions-registry submission-identifier {
            solution-content-data: solution-content,
            submission-block-height: stacks-block-height,
            is-selected-solution: false
        })
        
        ;; Increment submission counter for this request
        (map-set request-submission-counters request-id 
            (+ (get-total-submissions-for-request request-id) u1)
        )
        
        ;; Update user's submission history
        (try! (append-submission-to-user-history tx-sender request-id))
        
        (ok true)
    )
)
