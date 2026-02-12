(define-constant ERR-UNAUTHORIZED u100)
(define-constant ERR-NOT-FOUND u101)

(define-data-var governor principal tx-sender)
(define-data-var next-vault-id uint u1)

(define-map vaults
  { id: uint }
  { vault: principal, risk-tier: uint, cap: uint, active: bool }
)

(define-read-only (is-governor)
  (is-eq tx-sender (var-get governor))
)

(define-public (set-governor (new-governor principal))
  (begin
    (asserts! (is-governor) (err ERR-UNAUTHORIZED))
    (var-set governor new-governor)
    (ok true)
  )
)

(define-read-only (get-vault (id uint))
  (map-get? vaults { id: id })
)

(define-public (register-vault (vault principal) (risk-tier uint) (cap uint))
  (let ((id (var-get next-vault-id)))
    (begin
      (asserts! (is-governor) (err ERR-UNAUTHORIZED))
      (map-set vaults { id: id } { vault: vault, risk-tier: risk-tier, cap: cap, active: true })
      (var-set next-vault-id (+ id u1))
      (ok id)
    )
  )
)

(define-public (set-vault-active (id uint) (active bool))
  (begin
    (asserts! (is-governor) (err ERR-UNAUTHORIZED))
    (asserts! (is-some (map-get? vaults { id: id })) (err ERR-NOT-FOUND))
    (map-set vaults { id: id }
      (merge (unwrap-panic (map-get? vaults { id: id })) { active: active })
    )
    (ok true)
  )
)

(define-public (set-vault-cap (id uint) (cap uint))
  (begin
    (asserts! (is-governor) (err ERR-UNAUTHORIZED))
    (asserts! (is-some (map-get? vaults { id: id })) (err ERR-NOT-FOUND))
    (map-set vaults { id: id }
      (merge (unwrap-panic (map-get? vaults { id: id })) { cap: cap })
    )
    (ok true)
  )
)
