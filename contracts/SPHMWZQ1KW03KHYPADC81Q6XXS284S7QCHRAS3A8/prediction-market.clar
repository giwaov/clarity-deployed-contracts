


(define-constant BET_AMOUNT u100000)
(define-constant BLOCKS_PER_DAY u144)
(define-constant ERR_ALREADY_PREDICTED u200)


(define-map predictions 
  { day: uint, user: principal } 
  { is-up: bool }
)

(define-read-only (get-day-index)
  (/ burn-block-height BLOCKS_PER_DAY)
)


(define-public (predict (is-up bool))
  (let (
    (user tx-sender)
    (today (get-day-index))
  )
    
    (asserts! (is-none (map-get? predictions { day: today, user: user })) (err ERR_ALREADY_PREDICTED))

    
    (try! (stx-transfer? BET_AMOUNT user (as-contract tx-sender)))

    
    (map-set predictions { day: today, user: user } { is-up: is-up })

    (ok true)
  )
)


(define-read-only (get-my-prediction (day uint) (user principal))
  (map-get? predictions { day: day, user: user })
)