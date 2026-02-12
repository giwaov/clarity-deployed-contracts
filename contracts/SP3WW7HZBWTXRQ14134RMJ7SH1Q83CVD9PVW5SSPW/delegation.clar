;; Delegation Contract

(define-constant err-self-delegate (err u100))

(define-map delegations principal principal)

(define-read-only (get-delegate (delegator principal))
  (map-get? delegations delegator)
)

(define-public (delegate (to principal))
  (begin
    (asserts! (not (is-eq tx-sender to)) err-self-delegate)
    (map-set delegations tx-sender to)
    (ok true)
  )
)

(define-public (undelegate)
  (begin
    (map-delete delegations tx-sender)
    (ok true)
  )
)
