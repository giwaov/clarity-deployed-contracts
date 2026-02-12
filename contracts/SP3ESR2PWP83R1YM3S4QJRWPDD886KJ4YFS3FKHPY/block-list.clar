;; Block List

(define-map blocked
  { blocker: principal, blocked: principal }
  { active: bool }
)

(define-public (block-user (user principal))
  (begin
    (asserts! (is-none (map-get? blocked { blocker: tx-sender, blocked: user })) (err u409))
    (map-set blocked { blocker: tx-sender, blocked: user } { active: true })
    (ok true)
  )
)

(define-public (unblock-user (user principal))
  (begin
    (asserts! (is-some (map-get? blocked { blocker: tx-sender, blocked: user })) (err u404))
    (map-delete blocked { blocker: tx-sender, blocked: user })
    (ok true)
  )
)

(define-read-only (is-blocked (blocker principal) (user principal))
  (is-some (map-get? blocked { blocker: blocker, blocked: user }))
)
