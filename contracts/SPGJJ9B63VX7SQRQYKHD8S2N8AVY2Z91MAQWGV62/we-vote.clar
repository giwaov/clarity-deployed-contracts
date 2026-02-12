;; ------------------------------------------------------------
;; YES / NO VOTING CONTRACT (Clarity 4)
;; ------------------------------------------------------------

;; Store vote counts
(define-data-var yes-count uint u0)
(define-data-var no-count uint u0)

;; Track who has already voted
(define-map votes
    principal
    {
        choice: bool,
        timestamp: uint,
    }
)

;; ------------------------------------------------------------
;; PUBLIC: Cast a vote
;; true  = YES
;; false = NO
;; ------------------------------------------------------------
(define-public (vote (choice bool))
    (let (
            (sender tx-sender)
            (previous-vote (map-get? votes sender))
            (time stacks-block-time)
        )
        (begin
            ;; If user has voted before, decrement their previous choice
            (if (is-some previous-vote)
                (let ((prev-choice (get choice (unwrap-panic previous-vote))))
                    (if prev-choice
                        (var-set yes-count (- (var-get yes-count) u1))
                        (var-set no-count (- (var-get no-count) u1))
                    )
                )
                true
            )

            ;; Record new vote
            (map-set votes sender {
                choice: choice,
                timestamp: time,
            })

            ;; Increment counters for new choice
            (if choice
                (var-set yes-count (+ (var-get yes-count) u1))
                (var-set no-count (+ (var-get no-count) u1))
            )

            (ok {
                voted: choice,
                at: time,
            })
        )
    )
)

;; ------------------------------------------------------------
;; READ-ONLY: Get results
;; ------------------------------------------------------------
(define-read-only (get-results)
    (ok {
        yes: (var-get yes-count),
        no: (var-get no-count),
    })
)

;; ------------------------------------------------------------
;; READ-ONLY: Check if a user has voted (returns their latest vote)
;; ------------------------------------------------------------
(define-read-only (has-voted (user principal))
    (ok (map-get? votes user))
)
