(define-map contracts principal {is-active: bool, admin: principal})
(define-map contract-roles {contract: principal, account: principal, role: (buff 32)} bool)

(define-constant contract-owner tx-sender)
(define-constant err-already-registered (err u100))
(define-constant err-not-registered (err u101))
(define-constant err-not-admin (err u102))
(define-constant err-invalid-address (err u103))
(define-constant err-arrays-mismatch (err u104))

(define-read-only (get-contract-info (contract principal))
  (let ((info (unwrap! (map-get? contracts contract) err-not-registered)))
    (ok {is-active: (get is-active info), admin: (get admin info)})))

(define-read-only (get-role-info (contract principal) (account principal) (role (buff 32)))
  (default-to false (map-get? contract-roles {contract: contract, account: account, role: role})))

(define-read-only (is-admin (contract principal) (admin principal))
  (match (map-get? contracts contract)
    info (is-eq (get admin info) admin)
    false))

(define-public (register-contract (admin principal))
  (let ((contract-addr tx-sender))
    (asserts! (is-none (map-get? contracts contract-addr)) err-already-registered)
    (map-set contracts contract-addr {is-active: true, admin: admin})
    (ok true)))

(define-public (unregister-contract (contract principal))
  (let ((info (unwrap! (map-get? contracts contract) err-not-registered)))
    (asserts! (is-admin contract tx-sender) err-not-admin)
    (map-set contracts contract {is-active: false, admin: contract-owner})
    (ok true)))

(define-public (grant-role (contract principal) (role (buff 32)) (account principal))
  (begin
    (asserts! (or (is-admin contract tx-sender) (is-eq tx-sender contract)) err-not-admin)
    (map-set contract-roles {contract: contract, account: account, role: role} true)
    (ok true)))

(define-public (revoke-role (contract principal) (role (buff 32)) (account principal))
  (begin
    (asserts! (or (is-admin contract tx-sender) (is-eq tx-sender contract)) err-not-admin)
    (map-set contract-roles {contract: contract, account: account, role: role} false)
    (ok true)))

(define-public (grant-roles (contract-list (list 20 principal)) (roles (list 20 (buff 32))) (accounts (list 20 principal)))
  (begin
    (ok true)))

(define-public (revoke-roles (contract-list (list 20 principal)) (roles (list 20 (buff 32))) (accounts (list 20 principal)))
  (begin
    (ok true)))

(define-read-only (get-contract-hash)
  (contract-hash? .ac-registry))

(define-read-only (get-block-time)
  stacks-block-time)

(define-private (zip (list-a (list 20 principal)) (list-b (list 20 {r: (buff 32), a: principal})))
  (map make-tuple list-a list-b))

(define-private (make-tuple (a principal) (b {r: (buff 32), a: principal}))
  {c: a, r-a: b})
