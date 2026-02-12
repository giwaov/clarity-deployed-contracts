;; Allowlist with transfer limits
(define-map allowlist {user: principal, target: principal} uint)
(define-data-var admin principal tx-sender)

(define-read-only (get-allowance (user principal) (target principal))
  (default-to u0 (map-get? allowlist {user: user, target: target}))
)

(define-public (set-allowance (target principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (ok (map-set allowlist {user: tx-sender, target: target} amount))
  )
)

(define-public (increase-allowance (target principal) (amount uint))
  (let ((current (get-allowance tx-sender target)))
    (begin
      (ok (map-set allowlist {user: tx-sender, target: target} (+ current amount)))
    )
  )
)

(define-public (decrease-allowance (target principal) (amount uint))
  (let ((current (get-allowance tx-sender target)))
    (begin
      (asserts! (>= current amount) (err u2))
      (ok (map-set allowlist {user: tx-sender, target: target} (- current amount)))
    )
  )
)
