

;; Governance Timelock - Time-Delayed Execution (Clarity 4)
;; This contract enforces time delays on governance actions

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u4001))
(define-constant ERR-DELAY-NOT-MET (err u4002))
(define-constant ERR-ALREADY-EXECUTED (err u4003))
(define-constant ERR-ACTION-NOT-FOUND (err u4004))
(define-constant MIN-DELAY u86400)              ;; 24 hours
(define-constant MAX-DELAY u2592000)            ;; 30 days

;; Data variables
(define-data-var action-count uint u0)
(define-data-var default-delay uint u172800)    ;; 48 hours

;; Data maps
(define-map timelocked-actions
    { action-id: uint }
    {
        proposer: principal,
        target: principal,
        action-type: (string-ascii 50),
        queued-at: uint,                    ;; Clarity 4: Unix timestamp
        execute-at: uint,                   ;; Clarity 4: Unix timestamp
        executed: bool,
        executed-at: (optional uint),       ;; Clarity 4: Unix timestamp
        cancelled: bool
    }
)

;; Read-only functions
(define-read-only (get-action (action-id uint))
    (ok (map-get? timelocked-actions { action-id: action-id }))
)

(define-read-only (can-execute (action-id uint))
    (match (map-get? timelocked-actions { action-id: action-id })
        action (ok (and
            (>= stacks-block-time (get execute-at action))
            (not (get executed action))
            (not (get cancelled action))
        ))
        (ok false)
    )
)

;; Public functions
(define-public (queue-action (target principal) (action-type (string-ascii 50)) (delay uint))
    (begin
        (asserts! (and (>= delay MIN-DELAY) (<= delay MAX-DELAY)) ERR-NOT-AUTHORIZED)

        (let
            (
                (action-id (var-get action-count))
                (execute-time (+ stacks-block-time delay))
            )
            (map-set timelocked-actions
                { action-id: action-id }
                {
                    proposer: tx-sender,
                    target: target,
                    action-type: action-type,
                    queued-at: stacks-block-time,
                    execute-at: execute-time,
                    executed: false,
                    executed-at: none,
                    cancelled: false
                }
            )

            (var-set action-count (+ action-id u1))

            (print {
                event: "action-queued",
                action-id: action-id,
                target: target,
                execute-at: execute-time,
                timestamp: stacks-block-time
            })
            (ok action-id)
        )
    )
)

(define-public (execute-action (action-id uint))
    (let
        (
            (action (unwrap! (map-get? timelocked-actions { action-id: action-id }) ERR-ACTION-NOT-FOUND))
        )
        (asserts! (>= stacks-block-time (get execute-at action)) ERR-DELAY-NOT-MET)
        (asserts! (not (get executed action)) ERR-ALREADY-EXECUTED)
        (asserts! (not (get cancelled action)) ERR-NOT-AUTHORIZED)

        (map-set timelocked-actions
            { action-id: action-id }
            (merge action {
                executed: true,
                executed-at: (some stacks-block-time)
            })
        )

        (print {
            event: "action-executed",
            action-id: action-id,
            timestamp: stacks-block-time
        })
        (ok true)
    )
)

(define-public (cancel-action (action-id uint))
    (let
        (
            (action (unwrap! (map-get? timelocked-actions { action-id: action-id }) ERR-ACTION-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (not (get executed action)) ERR-ALREADY-EXECUTED)

        (map-set timelocked-actions
            { action-id: action-id }
            (merge action { cancelled: true })
        )

        (print {
            event: "action-cancelled",
            action-id: action-id,
            timestamp: stacks-block-time
        })
        (ok true)
    )
)
