(define-constant ERR_NOT_OWNER (err u100))

(define-data-var owner principal tx-sender)
(define-data-var admin (optional principal) none)

;; --- READ ONLY ---

(define-read-only (get-owner)
  (var-get owner))

(define-read-only (get-admin)
  (var-get admin))

(define-read-only (is-admin (user principal))
  (match (var-get admin)
    admin-principal (is-eq user admin-principal)
    false))

;; --- PUBLIC ---

(define-public (get-access (user principal))
  (ok (is-admin user)))

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_NOT_OWNER)
    (var-set admin (some new-admin))
    (ok true)))

(define-public (clear-admin)
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_NOT_OWNER)
    (var-set admin none)
    (ok true)))
