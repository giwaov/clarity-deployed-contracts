;; title: scoreboard-v3
;; version: 1.0.0
;; summary: Admin-managed scoreboard-v3 for arcade games.
;; clarity: 4

;; constants
(define-constant contract-version "1.0.0")
(define-constant err-not-admin (err u900))
(define-constant err-admin-unset (err u901))
(define-constant err-admin-set (err u902))
(define-constant err-paused (err u903))
(define-constant err-admin-locked (err u904))

;; data vars
(define-data-var admin (optional principal) none)
(define-data-var paused bool false)
(define-data-var admin-locked bool false)

;; data maps
(define-map scores {player: principal} {score: uint})

;; private helpers
(define-private (assert-admin)
  (match (var-get admin)
    admin-principal (if (is-eq admin-principal tx-sender) (ok true) err-not-admin)
    err-admin-unset))

(define-private (assert-not-paused)
  (if (var-get paused) err-paused (ok true)))

;; admin
(define-public (init-admin)
  (begin
    (asserts! (is-none (var-get admin)) err-admin-set)
    (var-set admin (some tx-sender))
    (ok true)))

(define-public (set-admin (new-admin principal))
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (asserts! (not (var-get admin-locked)) err-admin-locked)
    (var-set admin (some new-admin))
    (ok true)))

(define-public (lock-admin)
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (var-set admin-locked true)
    (ok true)))

(define-public (pause)
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (var-set paused true)
    (ok true)))

(define-public (unpause)
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (var-set paused false)
    (ok true)))

;; public functions
(define-public (set-score (player principal) (score uint))
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (unwrap! (assert-not-paused) err-paused)
    (map-set scores {player: player} {score: score})
    (ok true)))

(define-public (add-score (player principal) (delta uint))
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (unwrap! (assert-not-paused) err-paused)
    (let ((current (default-to u0 (get score (map-get? scores {player: player})))))
      (map-set scores {player: player} {score: (+ current delta)}))
    (ok true)))

;; read only functions
(define-read-only (get-score (player principal))
  (default-to u0 (get score (map-get? scores {player: player}))))

(define-read-only (get-admin)
  (var-get admin))

(define-read-only (is-paused)
  (var-get paused))

(define-read-only (is-admin-locked)
  (var-get admin-locked))

(define-read-only (get-version)
  contract-version)
