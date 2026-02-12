(define-map contracts (string-ascii 64) principal)
(define-map contract-dependencies (string-ascii 64) (list 20 (string-ascii 64)))

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-already-exists (err u101))
(define-constant err-not-found (err u102))

(define-read-only (get-contract (name (string-ascii 64)))
  (ok (unwrap! (map-get? contracts name) err-not-found)))

(define-read-only (get-dependencies (name (string-ascii 64)))
  (ok (default-to (list) (map-get? contract-dependencies name))))

(define-public (add-contract (name (string-ascii 64)) (address principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-owner)
    (asserts! (is-none (map-get? contracts name)) err-already-exists)
    (map-set contracts name address)
    (ok true)))

(define-public (add-proxy-contract (name (string-ascii 64)) (proxy-address principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-owner)
    (map-set contracts name proxy-address)
    (ok true)))

(define-public (inject-dependencies (name (string-ascii 64)) (deps (list 20 (string-ascii 64))))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-owner)
    (map-set contract-dependencies name deps)
    (ok true)))

(define-public (upgrade-contract (name (string-ascii 64)) (new-impl principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-owner)
    (map-set contracts name new-impl)
    (ok true)))

(define-read-only (get-contract-hash)
  (contract-hash? .sc-dependencies-registry))

(define-read-only (get-block-time)
  stacks-block-time)
