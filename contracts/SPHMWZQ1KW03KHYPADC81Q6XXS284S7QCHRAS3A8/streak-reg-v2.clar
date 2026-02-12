;; contracts/streak-reg-v2.clar

(define-constant BLOCKS_PER_DAY u144)

(define-constant ERR_ALREADY_CHECKED_IN u100)
(define-constant ERR_NOT_CHECKED_IN u101)
(define-constant ERR_ALREADY_SPUN u102)
(define-constant ERR_ALREADY_VOTED u103)

(define-constant SHIELD_PRICE u5000000)

(define-map user-state
  principal
  {
    last-day: uint,
    streak: uint,
    best-streak: uint,
    last-spin-day: uint,
    last-vote-day: uint,
    shields: uint
  }
)

(define-map daily-votes { day: uint, voter: principal } { option: uint })
(define-map streak-sbt uint principal)
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
      last-vote-day: u0,
      shields: u0
    }
    (map-get? user-state user)
  )
)

(define-read-only (streak-level (streak uint))
  (if (>= streak u30) u3 (if (>= streak u14) u2 (if (>= streak u7) u1 u0)))
)

(define-private (mint-or-upgrade-sbt (user principal) (streak uint))
  (let ((level (streak-level streak)))
    (if (is-eq level u0) false 
        (let ((token-id (var-get next-token-id)))
          (begin (map-set streak-sbt token-id user) (var-set next-token-id (+ token-id u1)) true)
        )
    )
  )
)


(define-public (check-in)
  (let (
        (today (get-day-index))
        (user (get-user tx-sender))
        (last-day (get last-day user))
        (current-streak (get streak user))
        (current-shields (get shields user))
       )
    (if (is-eq today last-day)
        (err ERR_ALREADY_CHECKED_IN)

        (let (
              (calc-result 
                (if (is-eq today (+ last-day u1))
                    { s: (+ current-streak u1), sh: current-shields }
                    (if (and (> current-shields u0) (> current-streak u0))
                        { s: (+ current-streak u1), sh: (- current-shields u1) }
                        { s: u1, sh: current-shields }
                    )
                )
              )
              (new-streak (get s calc-result))
              (new-shields (get sh calc-result))
              (best (if (> new-streak (get best-streak user)) new-streak (get best-streak user)))
              
              (reward-amount (+ u10 (* new-streak u2)))
             )
          (begin
            (map-set user-state tx-sender {
              last-day: today,
              streak: new-streak,
              best-streak: best,
              last-spin-day: (get last-spin-day user),
              last-vote-day: (get last-vote-day user),
              shields: new-shields
            })
            
            (mint-or-upgrade-sbt tx-sender new-streak)
            
            (try! (as-contract (contract-call? .streak-token-v2 mint reward-amount tx-sender)))
            
            (ok {
              action: "check-in",
              day: today,
              streak: new-streak,
              shields: new-shields,
              token-reward: reward-amount
            })
          )
        )
    )
  )
)

(define-public (buy-shield)
  (let (
    (user (get-user tx-sender))
  )
    (try! (stx-transfer? SHIELD_PRICE tx-sender (as-contract tx-sender)))
    (map-set user-state tx-sender (merge user { shields: (+ (get shields user) u1) }))
    (ok true)
  )
)

(define-read-only (calculate-reward (streak uint)) (mod (+ burn-block-height streak) u4))

(define-public (spin)
  (let ((today (get-day-index)) (user (get-user tx-sender)))
    (if (not (is-eq today (get last-day user))) (err ERR_NOT_CHECKED_IN)
        (if (is-eq today (get last-spin-day user)) (err ERR_ALREADY_SPUN)
            (let ((tier (calculate-reward (get streak user))))
              (begin
                (map-set user-state tx-sender (merge user { last-spin-day: today }))
                (ok { action: "spin", reward-tier: tier, streak: (get streak user) })
              )
            )
        )
    )
  )
)

(define-public (vote (option uint))
  (let ((today (get-day-index)) (user (get-user tx-sender)))
    (if (is-eq today (get last-vote-day user)) (err ERR_ALREADY_VOTED)
        (begin
          (map-set daily-votes { day: today, voter: tx-sender } { option: option })
          (map-set user-state tx-sender (merge user { last-vote-day: today }))
          (ok { action: "vote", day: today, option: option })
        )
    )
  )
)