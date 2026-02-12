;; Token Stream Contract
;; Handles milestone-based token streaming for startup funding

(define-constant ERR-UNAUTHORIZED (err u2001))
(define-constant ERR-STREAM-NOT-FOUND (err u2002))
(define-constant ERR-INVALID-AMOUNT (err u2003))
(define-constant ERR-STREAM-ACTIVE (err u2004))
(define-constant ERR-STREAM-PAUSED (err u2005))

;; Stream status: 0 = pending, 1 = active, 2 = paused, 3 = completed, 4 = cancelled
(define-map streams
    { stream-id: uint }
    {
        sender: principal,
        recipient: principal,
        token-contract: principal,
        total-amount: uint,
        released-amount: uint,
        start-time: uint,
        end-time: uint,
        milestone-trigger: uint, ;; startup-id + milestone-index encoded
        status: uint,
        created-at: uint
    }
)

(define-data-var next-stream-id uint u1)

;; Create a new token stream tied to a milestone
(define-public (create-stream
    (recipient principal)
    (token-contract principal)
    (total-amount uint)
    (start-time uint)
    (end-time uint)
    (milestone-trigger uint)
)
    (let
        (
            (stream-id (var-get next-stream-id))
            (timestamp (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
        )
        (asserts! (> total-amount u0) ERR-INVALID-AMOUNT)
        (asserts! (> end-time start-time) ERR-INVALID-AMOUNT)
        (begin
            (map-set streams
                { stream-id: stream-id }
                {
                    sender: tx-sender,
                    recipient: recipient,
                    token-contract: token-contract,
                    total-amount: total-amount,
                    released-amount: u0,
                    start-time: start-time,
                    end-time: end-time,
                    milestone-trigger: milestone-trigger,
                    status: u0,
                    created-at: timestamp
                }
            )
            (var-set next-stream-id (+ stream-id u1))
            (ok stream-id)
        )
    )
)

;; Activate stream when milestone is verified
(define-public (activate-stream (stream-id uint))
    (let
        (
            (stream (unwrap! (map-get? streams { stream-id: stream-id }) ERR-STREAM-NOT-FOUND))
        )
        (asserts! (is-eq (get status stream) u0) ERR-INVALID-AMOUNT)
        (ok (map-set streams
            { stream-id: stream-id }
            {
                sender: (get sender stream),
                recipient: (get recipient stream),
                token-contract: (get token-contract stream),
                total-amount: (get total-amount stream),
                released-amount: (get released-amount stream),
                start-time: (get start-time stream),
                end-time: (get end-time stream),
                milestone-trigger: (get milestone-trigger stream),
                status: u1,
                created-at: (get created-at stream)
            }
        ))
    )
)

;; Calculate and release tokens based on time elapsed
(define-public (release-tokens (stream-id uint))
    (let
        (
            (stream (unwrap! (map-get? streams { stream-id: stream-id }) ERR-STREAM-NOT-FOUND))
            (current-time (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
            (elapsed-time (- current-time (get start-time stream)))
            (total-duration (- (get end-time stream) (get start-time stream)))
        )
        (asserts! (is-eq (get status stream) u1) ERR-STREAM-PAUSED)
        (asserts! (>= current-time (get start-time stream)) ERR-INVALID-AMOUNT)
        (let
            (
                (release-amount (if
                    (>= current-time (get end-time stream))
                    (- (get total-amount stream) (get released-amount stream))
                    (/ (* (get total-amount stream) elapsed-time) total-duration)
                ))
                (new-released (+ (get released-amount stream) release-amount))
                (final-status (if
                    (>= new-released (get total-amount stream))
                    u3
                    (get status stream)
                ))
            )
            (ok (map-set streams
                { stream-id: stream-id }
                {
                    sender: (get sender stream),
                    recipient: (get recipient stream),
                    token-contract: (get token-contract stream),
                    total-amount: (get total-amount stream),
                    released-amount: new-released,
                    start-time: (get start-time stream),
                    end-time: (get end-time stream),
                    milestone-trigger: (get milestone-trigger stream),
                    status: final-status,
                    created-at: (get created-at stream)
                }
            ))
        )
    )
)

;; Get stream information
(define-read-only (get-stream (stream-id uint))
    (map-get? streams { stream-id: stream-id })
)

;; Pause stream (sender only)
(define-public (pause-stream (stream-id uint))
    (let
        (
            (stream (unwrap! (map-get? streams { stream-id: stream-id }) ERR-STREAM-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get sender stream)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status stream) u1) ERR-STREAM-ACTIVE)
        (ok (map-set streams
            { stream-id: stream-id }
            {
                sender: (get sender stream),
                recipient: (get recipient stream),
                token-contract: (get token-contract stream),
                total-amount: (get total-amount stream),
                released-amount: (get released-amount stream),
                start-time: (get start-time stream),
                end-time: (get end-time stream),
                milestone-trigger: (get milestone-trigger stream),
                status: u2,
                created-at: (get created-at stream)
            }
        ))
    )
)

;; Cancel stream (sender only, before activation)
(define-public (cancel-stream (stream-id uint))
    (let
        (
            (stream (unwrap! (map-get? streams { stream-id: stream-id }) ERR-STREAM-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get sender stream)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status stream) u0) ERR-INVALID-AMOUNT)
        (ok (map-set streams
            { stream-id: stream-id }
            {
                sender: (get sender stream),
                recipient: (get recipient stream),
                token-contract: (get token-contract stream),
                total-amount: (get total-amount stream),
                released-amount: (get released-amount stream),
                start-time: (get start-time stream),
                end-time: (get end-time stream),
                milestone-trigger: (get milestone-trigger stream),
                status: u4,
                created-at: (get created-at stream)
            }
        ))
    )
)

