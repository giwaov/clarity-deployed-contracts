;; Incubant - Incubation Contract
;; Manages startup applications, approvals, and milestone-based token streaming

(define-constant ERR-UNAUTHORIZED (err u1001))
(define-constant ERR-STARTUP-NOT-FOUND (err u1002))
(define-constant ERR-MILESTONE-NOT-FOUND (err u1003))
(define-constant ERR-MILESTONE-ALREADY-VERIFIED (err u1004))
(define-constant ERR-INVALID-STATUS (err u1005))
(define-constant ERR-INSUFFICIENT-FUNDS (err u1006))

(define-constant CONTRACT-OWNER tx-sender)

;; Startup status enum
(define-data-var next-startup-id uint u1)

;; Startup data structure
(define-map startups
    { id: uint }
    {
        founder: principal,
        name: (string-ascii 100),
        description: (string-utf8 500),
        status: uint, ;; 0: pending, 1: approved, 2: active, 3: completed, 4: rejected
        total-funding: uint,
        current-milestone: uint,
        created-at: uint,
        equity-token-contract: (optional principal)
    }
)

;; Milestone data structure
(define-map milestones
    { startup-id: uint, milestone-index: uint }
    {
        title: (string-ascii 100),
        description: (string-utf8 500),
        funding-amount: uint,
        status: uint, ;; 0: pending, 1: in-progress, 2: completed, 3: verified
        deadline: uint,
        created-at: uint,
        verified-at: (optional uint),
        verifier: (optional principal)
    }
)

;; Startup applications
(define-map applications
    { applicant: principal }
    {
        startup-id: (optional uint),
        name: (string-ascii 100),
        description: (string-utf8 500),
        proposal: (string-utf8 1000),
        submitted-at: uint,
        status: uint ;; 0: pending, 1: approved, 2: rejected
    }
)

;; Get next startup ID
(define-read-only (get-next-startup-id)
    (var-get next-startup-id)
)

;; Apply for incubation
(define-public (apply-for-incubation
    (name (string-ascii 100))
    (description (string-utf8 500))
    (proposal (string-utf8 1000))
)
    (let
        (
            (applicant tx-sender)
            (timestamp (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
        )
        (asserts! (is-none (map-get? applications { applicant: applicant })) ERR-UNAUTHORIZED)
        (ok (map-set applications
            { applicant: applicant }
            {
                startup-id: none,
                name: name,
                description: description,
                proposal: proposal,
                submitted-at: timestamp,
                status: u0
            }
        ))
    )
)

;; Approve startup application (governance only)
(define-public (approve-startup
    (applicant principal)
)
    (let
        (
            (application (unwrap! (map-get? applications { applicant: applicant }) ERR-STARTUP-NOT-FOUND))
            (startup-id (var-get next-startup-id))
            (timestamp (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
        )
        (asserts! (is-eq (get status application) u0) ERR-INVALID-STATUS)
        (begin
            ;; Update application status
            (map-set applications
                { applicant: applicant }
                {
                    startup-id: (some startup-id),
                    name: (get name application),
                    description: (get description application),
                    proposal: (get proposal application),
                    submitted-at: (get submitted-at application),
                    status: u1
                }
            )
            ;; Create startup record
            (map-set startups
                { id: startup-id }
                {
                    founder: applicant,
                    name: (get name application),
                    description: (get description application),
                    status: u1,
                    total-funding: u0,
                    current-milestone: u0,
                    created-at: timestamp,
                    equity-token-contract: none
                }
            )
            ;; Increment startup ID
            (var-set next-startup-id (+ startup-id u1))
            (ok startup-id)
        )
    )
)

;; Create milestone for a startup
(define-public (create-milestone
    (startup-id uint)
    (title (string-ascii 100))
    (description (string-utf8 500))
    (funding-amount uint)
    (deadline uint)
)
    (let
        (
            (startup (unwrap! (map-get? startups { id: startup-id }) ERR-STARTUP-NOT-FOUND))
            (timestamp (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
            (milestone-index (get current-milestone startup))
        )
        (asserts! (is-eq tx-sender (get founder startup)) ERR-UNAUTHORIZED)
        (asserts! (or (is-eq (get status startup) u1) (is-eq (get status startup) u2)) ERR-INVALID-STATUS)
        (begin
            (map-set milestones
                { startup-id: startup-id, milestone-index: milestone-index }
                {
                    title: title,
                    description: description,
                    funding-amount: funding-amount,
                    status: u0,
                    deadline: deadline,
                    created-at: timestamp,
                    verified-at: none,
                    verifier: none
                }
            )
            (map-set startups
                { id: startup-id }
                {
                    founder: (get founder startup),
                    name: (get name startup),
                    description: (get description startup),
                    status: u2,
                    total-funding: (+ (get total-funding startup) funding-amount),
                    current-milestone: (+ milestone-index u1),
                    created-at: (get created-at startup),
                    equity-token-contract: (get equity-token-contract startup)
                }
            )
            (ok milestone-index)
        )
    )
)

;; Mark milestone as completed (founder action)
(define-public (complete-milestone
    (startup-id uint)
    (milestone-index uint)
)
    (let
        (
            (startup (unwrap! (map-get? startups { id: startup-id }) ERR-STARTUP-NOT-FOUND))
            (milestone (unwrap! (map-get? milestones { startup-id: startup-id, milestone-index: milestone-index }) ERR-MILESTONE-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get founder startup)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status milestone) u1) ERR-INVALID-STATUS)
        (ok (map-set milestones
            { startup-id: startup-id, milestone-index: milestone-index }
            {
                title: (get title milestone),
                description: (get description milestone),
                funding-amount: (get funding-amount milestone),
                status: u2,
                deadline: (get deadline milestone),
                created-at: (get created-at milestone),
                verified-at: (get verified-at milestone),
                verifier: (get verifier milestone)
            }
        ))
    )
)

;; Verify milestone (governance/oracle action)
(define-public (verify-milestone
    (startup-id uint)
    (milestone-index uint)
)
    (let
        (
            (milestone (unwrap! (map-get? milestones { startup-id: startup-id, milestone-index: milestone-index }) ERR-MILESTONE-NOT-FOUND))
            (timestamp (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
        )
        (asserts! (is-eq (get status milestone) u2) ERR-INVALID-STATUS)
        (asserts! (is-none (get verified-at milestone)) ERR-MILESTONE-ALREADY-VERIFIED)
        (ok (map-set milestones
            { startup-id: startup-id, milestone-index: milestone-index }
            {
                title: (get title milestone),
                description: (get description milestone),
                funding-amount: (get funding-amount milestone),
                status: u3,
                deadline: (get deadline milestone),
                created-at: (get created-at milestone),
                verified-at: (some timestamp),
                verifier: (some tx-sender)
            }
        ))
    )
)

;; Get startup information
(define-read-only (get-startup (startup-id uint))
    (map-get? startups { id: startup-id })
)

;; Get milestone information
(define-read-only (get-milestone (startup-id uint) (milestone-index uint))
    (map-get? milestones { startup-id: startup-id, milestone-index: milestone-index })
)

;; Get application
(define-read-only (get-application (applicant principal))
    (map-get? applications { applicant: applicant })
)

;; Set equity token contract (called after equity token deployment)
(define-public (set-equity-token-contract
    (startup-id uint)
    (contract principal)
)
    (let
        (
            (startup (unwrap! (map-get? startups { id: startup-id }) ERR-STARTUP-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get founder startup)) ERR-UNAUTHORIZED)
        (ok (map-set startups
            { id: startup-id }
            {
                founder: (get founder startup),
                name: (get name startup),
                description: (get description startup),
                status: (get status startup),
                total-funding: (get total-funding startup),
                current-milestone: (get current-milestone startup),
                created-at: (get created-at startup),
                equity-token-contract: (some contract)
            }
        ))
    )
)

