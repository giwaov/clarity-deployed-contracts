;; Daily Check-in Contract
;; Users can check in once per day and track their streak
;; clarity-version: 3

;; Error codes
(define-constant ERR-ALREADY-CHECKED-IN (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-UNAUTHORIZED (err u102))

;; Data variables
(define-data-var total-checkins uint u0)

;; Data maps
(define-map user-checkins
    principal
    {
        last-checkin-block: uint,
        total-checkins: uint,
        current-streak: uint,
        longest-streak: uint,
    }
)

;; Blocks per day (approximately 144 blocks = 1 day on Bitcoin/Stacks)
(define-constant BLOCKS-PER-DAY u144)

;; Public functions

;; Check in function - allows user to check in once per day
(define-public (check-in)
    (let (
            (caller tx-sender)
            (current-block stacks-block-height)
            (user-data (map-get? user-checkins caller))
        )
        (match user-data
            existing-data
            (let ((blocks-since-last (- current-block (get last-checkin-block existing-data))))
                ;; Check if already checked in today
                (asserts! (>= blocks-since-last BLOCKS-PER-DAY)
                    ERR-ALREADY-CHECKED-IN
                )

                ;; Calculate new streak
                (let (
                        (new-streak (if (< blocks-since-last (* BLOCKS-PER-DAY u2))
                            ;; Within 2 days, continue streak
                            (+ (get current-streak existing-data) u1)
                            ;; More than 2 days, reset streak
                            u1
                        ))
                        (new-longest (if (> new-streak (get longest-streak existing-data))
                            new-streak
                            (get longest-streak existing-data)
                        ))
                    )
                    ;; Update user data
                    (map-set user-checkins caller {
                        last-checkin-block: current-block,
                        total-checkins: (+ (get total-checkins existing-data) u1),
                        current-streak: new-streak,
                        longest-streak: new-longest,
                    })

                    ;; Increment total checkins
                    (var-set total-checkins (+ (var-get total-checkins) u1))
                    (ok true)
                )
            )
            ;; First time check-in
            (begin
                (map-set user-checkins caller {
                    last-checkin-block: current-block,
                    total-checkins: u1,
                    current-streak: u1,
                    longest-streak: u1,
                })
                (var-set total-checkins (+ (var-get total-checkins) u1))
                (ok true)
            )
        )
    )
)

;; Read-only functions

;; Get user's check-in data
(define-read-only (get-user-data (user principal))
    (ok (map-get? user-checkins user))
)

;; Get user's current streak
(define-read-only (get-current-streak (user principal))
    (match (map-get? user-checkins user)
        data (ok (get current-streak data))
        ERR-NOT-FOUND
    )
)

;; Get user's longest streak
(define-read-only (get-longest-streak (user principal))
    (match (map-get? user-checkins user)
        data (ok (get longest-streak data))
        ERR-NOT-FOUND
    )
)

;; Get total checkins across all users
(define-read-only (get-total-checkins)
    (ok (var-get total-checkins))
)

;; Check if user can check in now
(define-read-only (can-check-in (user principal))
    (match (map-get? user-checkins user)
        data
        (let ((blocks-since-last (- stacks-block-height (get last-checkin-block data))))
            (ok (>= blocks-since-last BLOCKS-PER-DAY))
        )
        (ok true) ;; First time users can always check in
    )
)

;; Get blocks until next check-in is available
(define-read-only (blocks-until-next-checkin (user principal))
    (match (map-get? user-checkins user)
        data
        (let ((blocks-since-last (- stacks-block-height (get last-checkin-block data))))
            (if (>= blocks-since-last BLOCKS-PER-DAY)
                (ok u0)
                (ok (- BLOCKS-PER-DAY blocks-since-last))
            )
        )
        (ok u0) ;; First time users have 0 blocks to wait
    )
)
