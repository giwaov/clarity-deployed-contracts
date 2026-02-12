(define-constant BLOCKS_PER_DAY u144)

(define-constant ERR_ALREADY_CHECKED_IN u100)
(define-constant ERR_NOT_CHECKED_IN u101)
(define-constant ERR_ALREADY_SPUN u102)
(define-constant ERR_ALREADY_VOTED u103)
(define-constant ERR_NOT_OWNER u104)
(define-constant ERR_TRANSFER_DISABLED u105)

(define-map user-state
  principal
  {
    last-day: uint,
    streak: uint,
    best-streak: uint,
    last-spin-day: uint,
    last-vote-day: uint
  }
)

(define-map daily-votes
  { day: uint, voter: principal }
  { option: uint }
)

(define-map streak-sbt
  uint
  principal
)

(define-data-var next-token-id uint u1)

(define-read-only (get-day-index)
  (/ burn-block-height BLOCKS_PER_DAY)
)

(define-read-only (get-user (user principal))
  (default-to
    {
      last-day: u0,
      streak: u0,
      best-streak: u0,
      last-spin-day: u0,
      last-vote-day: u0
    }
    (map-get? user-state user)
  )
)


(define-read-only (streak-level (streak uint))
  (if (>= streak u30)
      u3
      (if (>= streak u14)
          u2
          (if (>= streak u7)
              u1
              u0
          )
      )
  )
)


(define-private (mint-or-upgrade-sbt (user principal) (streak uint))
  (let ((level (streak-level streak)))
    (if (is-eq level u0)
        false 

        (let ((token-id (var-get next-token-id)))
          (begin
            (map-set streak-sbt token-id user)
            (var-set next-token-id (+ token-id u1))
            true 
          )
        )
    )
  )
)

(define-public (check-in)
  (let (
        (today (get-day-index))
        (user (get-user tx-sender))
       )
    (if (is-eq today (get last-day user))
        (err ERR_ALREADY_CHECKED_IN)

        (let (
              (new-streak
                (if (is-eq today (+ (get last-day user) u1))
                    (+ (get streak user) u1)
                    u1
                )
              )
              (best
                (if (> new-streak (get best-streak user))
                    new-streak
                    (get best-streak user)
                )
              )
             )
          (begin
            (map-set user-state tx-sender {
              last-day: today,
              streak: new-streak,
              best-streak: best,
              last-spin-day: (get last-spin-day user),
              last-vote-day: (get last-vote-day user)
            })
            
            (mint-or-upgrade-sbt tx-sender new-streak)
            
            (ok {
              action: "check-in",
              day: today,
              streak: new-streak,
              best-streak: best
            })
          )
        )
    )
  )
)

(define-read-only (calculate-reward (streak uint))
  (mod (+ burn-block-height streak) u4)
)

(define-public (spin)
  (let (
        (today (get-day-index))
        (user (get-user tx-sender))
       )
    (if (not (is-eq today (get last-day user)))
        (err ERR_NOT_CHECKED_IN)

        (if (is-eq today (get last-spin-day user))
            (err ERR_ALREADY_SPUN)

            (let (
                  (tier (calculate-reward (get streak user)))
                 )
              (begin
                (map-set user-state tx-sender {
                  last-day: (get last-day user),
                  streak: (get streak user),
                  best-streak: (get best-streak user),
                  last-spin-day: today,
                  last-vote-day: (get last-vote-day user)
                })
                (ok {
                  action: "spin",
                  reward-tier: tier,
                  streak: (get streak user)
                })
              )
            )
        )
    )
  )
)

(define-public (vote (option uint))
  (let (
        (today (get-day-index))
        (user (get-user tx-sender))
       )
    (if (is-eq today (get last-vote-day user))
        (err ERR_ALREADY_VOTED)

        (begin
          (map-set daily-votes
            { day: today, voter: tx-sender }
            { option: option }
          )
          (map-set user-state tx-sender {
            last-day: (get last-day user),
            streak: (get streak user),
            best-streak: (get best-streak user),
            last-spin-day: (get last-spin-day user),
            last-vote-day: today
          })
          (ok {
            action: "vote",
            day: today,
            option: option
          })
        )
    )
  )
)


(define-public (transfer-sbt (token-id uint) (to principal))
  (begin
    (asserts! false (err ERR_TRANSFER_DISABLED))
    (ok true)
  )
)

(define-read-only (get-my-state)
  (ok (get-user tx-sender))
)

(define-read-only (get-vote (day uint) (user principal))
  (map-get? daily-votes { day: day, voter: user })
)

(define-read-only (get-sbt-owner (token-id uint))
  (map-get? streak-sbt token-id)
)