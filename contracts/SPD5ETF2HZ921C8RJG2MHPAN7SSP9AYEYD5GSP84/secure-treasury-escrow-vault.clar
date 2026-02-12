;; title: escrow-manager
;; version: 1.0.0
;; summary: Secure fund management beyond basic payments
;; description: Escrow accounts, milestone-based releases, and secure fund locking

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-invalid-status (err u104))
(define-constant err-milestone-incomplete (err u105))
(define-constant err-escrow-expired (err u106))
(define-constant err-escrow-active (err u107))
(define-constant err-invalid-amount (err u108))

;; Escrow status
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-RELEASED u2)
(define-constant STATUS-REFUNDED u3)
(define-constant STATUS-PARTIALLY-RELEASED u4)
(define-constant STATUS-EXPIRED u5)

;; Milestone status
(define-constant MILESTONE-PENDING u1)
(define-constant MILESTONE-COMPLETED u2)
(define-constant MILESTONE-FAILED u3)

;; data vars
(define-data-var escrow-nonce uint u0)
(define-data-var milestone-nonce uint u0)
(define-data-var min-escrow-amount uint u100000) ;; 0.1 STX
(define-data-var max-escrow-duration uint u52560) ;; ~1 year in blocks
(define-data-var emergency-withdrawal-fee uint u10) ;; 10% fee
(define-data-var total-escrowed uint u0)

;; data maps
(define-map escrow-accounts
    { escrow-id: uint }
    {
        campaign-id: uint,
        depositor: principal,
        beneficiary: principal,
        amount: uint,
        released-amount: uint,
        status: uint,
        created-at: uint,
        expiry: uint,
        requires-milestones: bool
    }
)

(define-map escrow-milestones
    { escrow-id: uint, milestone-id: uint }
    {
        description: (string-utf8 200),
        amount: uint,
        status: uint,
        condition-hash: (optional (buff 32)),
        deadline: uint,
        completed-at: uint
    }
)

(define-map milestone-count
    { escrow-id: uint }
    {
        total: uint,
        completed: uint
    }
)

(define-map escrow-releases
    { escrow-id: uint, release-id: uint }
    {
        amount: uint,
        recipient: principal,
        reason: (string-utf8 200),
        released-at: uint
    }
)

(define-map pending-escrows
    { user: principal }
    {
        total-locked: uint,
        total-escrowed-out: uint
    }
)

(define-map escrow-history
    { user: principal }
    {
        total-deposited: uint,
        total-received: uint,
        total-refunded: uint,
        escrows-completed: uint
    }
)

;; private functions
(define-private (calculate-emergency-fee (amount uint))
    (/ (* amount (var-get emergency-withdrawal-fee)) u100)
)

(define-private (update-user-pending (user principal) (amount uint) (is-deposit bool))
    (let
        (
            (pending (default-to
                { total-locked: u0, total-escrowed-out: u0 }
                (map-get? pending-escrows { user: user })
            ))
        )
        (map-set pending-escrows
            { user: user }
            (if is-deposit
                {
                    total-locked: (+ (get total-locked pending) amount),
                    total-escrowed-out: (get total-escrowed-out pending)
                }
                {
                    total-locked: (get total-locked pending),
                    total-escrowed-out: (+ (get total-escrowed-out pending) amount)
                }
            )
        )
    )
)

;; read only functions
(define-read-only (get-escrow (escrow-id uint))
    (map-get? escrow-accounts { escrow-id: escrow-id })
)

(define-read-only (get-milestone (escrow-id uint) (milestone-id uint))
    (map-get? escrow-milestones { escrow-id: escrow-id, milestone-id: milestone-id })
)

(define-read-only (get-milestone-count (escrow-id uint))
    (default-to { total: u0, completed: u0 } (map-get? milestone-count { escrow-id: escrow-id }))
)

(define-read-only (get-release (escrow-id uint) (release-id uint))
    (map-get? escrow-releases { escrow-id: escrow-id, release-id: release-id })
)

(define-read-only (get-pending-escrows (user principal))
    (map-get? pending-escrows { user: user })
)

(define-read-only (get-escrow-history (user principal))
    (map-get? escrow-history { user: user })
)

(define-read-only (get-escrow-nonce)
    (var-get escrow-nonce)
)

(define-read-only (is-escrow-expired (escrow-id uint))
    (match (map-get? escrow-accounts { escrow-id: escrow-id })
        escrow (>= stacks-block-time (get expiry escrow))
        false
    )
)

;; public functions
(define-public (create-escrow
    (campaign-id uint)
    (beneficiary principal)
    (amount uint)
    (duration uint)
    (requires-milestones bool)
)
    (let
        (
            (escrow-id (+ (var-get escrow-nonce) u1))
            (expiry (+ stacks-block-time duration))
        )
        (asserts! (>= amount (var-get min-escrow-amount)) err-invalid-amount)
        (asserts! (<= duration (var-get max-escrow-duration)) err-invalid-status)
        (asserts! (not (is-eq tx-sender beneficiary)) err-unauthorized)

        ;; In production, this would transfer STX to contract
        ;; (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

        (map-set escrow-accounts
            { escrow-id: escrow-id }
            {
                campaign-id: campaign-id,
                depositor: tx-sender,
                beneficiary: beneficiary,
                amount: amount,
                released-amount: u0,
                status: STATUS-ACTIVE,
                created-at: stacks-block-time,
                expiry: expiry,
                requires-milestones: requires-milestones
            }
        )

        (if requires-milestones
            (map-set milestone-count { escrow-id: escrow-id } { total: u0, completed: u0 })
            true
        )

        (update-user-pending tx-sender amount true)
        (var-set total-escrowed (+ (var-get total-escrowed) amount))
        (var-set escrow-nonce escrow-id)
        (ok escrow-id)
    )
)

(define-public (add-milestone
    (escrow-id uint)
    (description (string-utf8 200))
    (amount uint)
    (deadline uint)
    (condition-hash (optional (buff 32)))
)
    (let
        (
            (escrow (unwrap! (map-get? escrow-accounts { escrow-id: escrow-id }) err-not-found))
            (count-data (get-milestone-count escrow-id))
            (milestone-id (+ (get total count-data) u1))
        )
        (asserts! (is-eq tx-sender (get depositor escrow)) err-unauthorized)
        (asserts! (get requires-milestones escrow) err-invalid-status)
        (asserts! (is-eq (get status escrow) STATUS-ACTIVE) err-invalid-status)

        (map-set escrow-milestones
            { escrow-id: escrow-id, milestone-id: milestone-id }
            {
                description: description,
                amount: amount,
                status: MILESTONE-PENDING,
                condition-hash: condition-hash,
                deadline: deadline,
                completed-at: u0
            }
        )

        (map-set milestone-count
            { escrow-id: escrow-id }
            {
                total: milestone-id,
                completed: (get completed count-data)
            }
        )

        (ok milestone-id)
    )
)

(define-public (complete-milestone
    (escrow-id uint)
    (milestone-id uint)
)
    (let
        (
            (escrow (unwrap! (map-get? escrow-accounts { escrow-id: escrow-id }) err-not-found))
            (milestone (unwrap! (map-get? escrow-milestones { escrow-id: escrow-id, milestone-id: milestone-id }) err-not-found))
            (count-data (get-milestone-count escrow-id))
        )
        (asserts! (is-eq tx-sender (get beneficiary escrow)) err-unauthorized)
        (asserts! (is-eq (get status milestone) MILESTONE-PENDING) err-invalid-status)

        (map-set escrow-milestones
            { escrow-id: escrow-id, milestone-id: milestone-id }
            (merge milestone {
                status: MILESTONE-COMPLETED,
                completed-at: stacks-block-time
            })
        )

        (map-set milestone-count
            { escrow-id: escrow-id }
            {
                total: (get total count-data),
                completed: (+ (get completed count-data) u1)
            }
        )

        (ok true)
    )
)

(define-public (release-funds
    (escrow-id uint)
    (amount uint)
    (reason (string-utf8 200))
)
    (let
        (
            (escrow (unwrap! (map-get? escrow-accounts { escrow-id: escrow-id }) err-not-found))
            (available (- (get amount escrow) (get released-amount escrow)))
            (release-id (+ (var-get milestone-nonce) u1))
        )
        (asserts! (is-eq tx-sender (get depositor escrow)) err-unauthorized)
        (asserts! (is-eq (get status escrow) STATUS-ACTIVE) err-invalid-status)
        (asserts! (<= amount available) err-insufficient-funds)

        ;; In production, transfer STX to beneficiary
        ;; (try! (as-contract (stx-transfer? amount tx-sender (get beneficiary escrow))))

        (map-set escrow-releases
            { escrow-id: escrow-id, release-id: release-id }
            {
                amount: amount,
                recipient: (get beneficiary escrow),
                reason: reason,
                released-at: stacks-block-time
            }
        )

        (let ((new-released (+ (get released-amount escrow) amount)))
            (map-set escrow-accounts
                { escrow-id: escrow-id }
                (merge escrow {
                    released-amount: new-released,
                    status: (if (is-eq new-released (get amount escrow)) STATUS-RELEASED STATUS-PARTIALLY-RELEASED)
                })
            )
        )

        (var-set milestone-nonce release-id)
        (ok true)
    )
)

(define-public (release-milestone-funds
    (escrow-id uint)
    (milestone-id uint)
)
    (let
        (
            (escrow (unwrap! (map-get? escrow-accounts { escrow-id: escrow-id }) err-not-found))
            (milestone (unwrap! (map-get? escrow-milestones { escrow-id: escrow-id, milestone-id: milestone-id }) err-not-found))
            (available (- (get amount escrow) (get released-amount escrow)))
            (release-id (+ (var-get milestone-nonce) u1))
        )
        (asserts! (is-eq tx-sender (get depositor escrow)) err-unauthorized)
        (asserts! (is-eq (get status milestone) MILESTONE-COMPLETED) err-milestone-incomplete)
        (asserts! (<= (get amount milestone) available) err-insufficient-funds)

        ;; In production, transfer STX to beneficiary
        ;; (try! (as-contract (stx-transfer? (get amount milestone) tx-sender (get beneficiary escrow))))

        (map-set escrow-releases
            { escrow-id: escrow-id, release-id: release-id }
            {
                amount: (get amount milestone),
                recipient: (get beneficiary escrow),
                reason: (get description milestone),
                released-at: stacks-block-time
            }
        )

        (let ((new-released (+ (get released-amount escrow) (get amount milestone))))
            (map-set escrow-accounts
                { escrow-id: escrow-id }
                (merge escrow {
                    released-amount: new-released,
                    status: (if (is-eq new-released (get amount escrow)) STATUS-RELEASED STATUS-PARTIALLY-RELEASED)
                })
            )
        )

        (var-set milestone-nonce release-id)
        (ok true)
    )
)

(define-public (refund-escrow (escrow-id uint))
    (let
        (
            (escrow (unwrap! (map-get? escrow-accounts { escrow-id: escrow-id }) err-not-found))
            (refund-amount (- (get amount escrow) (get released-amount escrow)))
        )
        (asserts! (is-eq tx-sender (get depositor escrow)) err-unauthorized)
        (asserts! (>= stacks-block-time (get expiry escrow)) err-escrow-active)
        (asserts! (or
            (is-eq (get status escrow) STATUS-ACTIVE)
            (is-eq (get status escrow) STATUS-PARTIALLY-RELEASED)
        ) err-invalid-status)

        ;; In production, transfer STX back to depositor
        ;; (try! (as-contract (stx-transfer? refund-amount tx-sender (get depositor escrow))))

        (map-set escrow-accounts
            { escrow-id: escrow-id }
            (merge escrow { status: STATUS-REFUNDED })
        )

        (let
            (
                (history (default-to
                    { total-deposited: u0, total-received: u0, total-refunded: u0, escrows-completed: u0 }
                    (map-get? escrow-history { user: (get depositor escrow) })
                ))
            )
            (map-set escrow-history
                { user: (get depositor escrow) }
                (merge history {
                    total-refunded: (+ (get total-refunded history) refund-amount)
                })
            )
        )

        (ok refund-amount)
    )
)

(define-public (emergency-withdrawal (escrow-id uint))
    (let
        (
            (escrow (unwrap! (map-get? escrow-accounts { escrow-id: escrow-id }) err-not-found))
            (available (- (get amount escrow) (get released-amount escrow)))
            (fee (calculate-emergency-fee available))
            (withdrawal-amount (- available fee))
        )
        (asserts! (is-eq tx-sender (get depositor escrow)) err-unauthorized)
        (asserts! (is-eq (get status escrow) STATUS-ACTIVE) err-invalid-status)

        ;; In production, transfer STX minus fee
        ;; (try! (as-contract (stx-transfer? withdrawal-amount tx-sender (get depositor escrow))))
        ;; (try! (as-contract (stx-transfer? fee tx-sender contract-owner)))

        (map-set escrow-accounts
            { escrow-id: escrow-id }
            (merge escrow {
                status: STATUS-REFUNDED,
                released-amount: (get amount escrow)
            })
        )

        (ok withdrawal-amount)
    )
)

(define-public (extend-escrow-period (escrow-id uint) (additional-time uint))
    (let
        (
            (escrow (unwrap! (map-get? escrow-accounts { escrow-id: escrow-id }) err-not-found))
        )
        (asserts! (is-eq tx-sender (get depositor escrow)) err-unauthorized)
        (asserts! (is-eq (get status escrow) STATUS-ACTIVE) err-invalid-status)

        (map-set escrow-accounts
            { escrow-id: escrow-id }
            (merge escrow {
                expiry: (+ (get expiry escrow) additional-time)
            })
        )
        (ok true)
    )
)

;; Admin functions
(define-public (set-min-escrow-amount (new-min uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set min-escrow-amount new-min)
        (ok true)
    )
)

(define-public (set-emergency-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-fee u50) err-invalid-amount) ;; Max 50%
        (var-set emergency-withdrawal-fee new-fee)
        (ok true)
    )
)
