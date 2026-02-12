



(define-constant STAKE_AMOUNT u100000)


(define-map user-stakes principal uint)


(define-public (stake-stx)
  (let (
    (user tx-sender)
    (current-stake (default-to u0 (map-get? user-stakes user)))
  )

    (try! (stx-transfer? STAKE_AMOUNT user (as-contract tx-sender)))


    (map-set user-stakes user (+ current-stake STAKE_AMOUNT))

    (ok STAKE_AMOUNT)
  )
)


(define-read-only (get-my-stake (user principal))
  (ok (default-to u0 (map-get? user-stakes user)))
)


(define-read-only (get-pool-balance)
  (ok (stx-get-balance (as-contract tx-sender)))
)