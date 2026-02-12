;; title: hot-potato-v3
;; version: 1.0.0
;; summary: Timed pot game where the last holder before timeout wins the pot.
;; clarity: 4

;; constants
(define-constant contract-version "1.0.0")
(define-constant min-stake u1000000)
(define-constant max-stake u100000000)
(define-constant round-blocks u36) ;; ~6 hours at 10m blocks
(define-constant status-open u0)
(define-constant status-settled u1)
(define-constant status-canceled u2)
(define-constant err-not-admin (err u900))
(define-constant err-admin-unset (err u901))
(define-constant err-admin-set (err u902))
(define-constant err-paused (err u903))
(define-constant err-admin-locked (err u904))
(define-constant err-stake-low (err u400))
(define-constant err-stake-high (err u401))
(define-constant err-not-open (err u402))
(define-constant err-not-holder (err u403))
(define-constant err-transfer (err u404))
(define-constant err-too-early (err u405))
(define-constant err-not-found (err u406))

;; data vars
(define-data-var next-game-id uint u0)
(define-data-var admin (optional principal) none)
(define-data-var paused bool false)
(define-data-var admin-locked bool false)

;; data maps
(define-map games
  {id: uint}
  {
    id: uint,
    holder: principal,
    stake: uint,
    pot: uint,
    passes: uint,
    expires-at: uint,
    status: uint
  }
)

;; private helpers
;; transfer STX out of the contract
(define-private (transfer-from-contract (amount uint) (recipient principal))
  (as-contract (stx-transfer? amount tx-sender recipient)))


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
(define-public (create-game (stake uint))
  (begin
    (unwrap! (assert-not-paused) err-paused)
    (asserts! (>= stake min-stake) err-stake-low)
    (asserts! (<= stake max-stake) err-stake-high)
    (let
      (
        (game-id (var-get next-game-id))
        (self (as-contract tx-sender))
      )
      (begin
        (unwrap! (stx-transfer? stake tx-sender self) err-transfer)
        (map-set games {id: game-id}
          {
            id: game-id,
            holder: tx-sender,
            stake: stake,
            pot: stake,
            passes: u0,
            expires-at: (+ stacks-block-height round-blocks),
            status: status-open
          })
        (var-set next-game-id (+ game-id u1))
        (ok game-id)))))

(define-public (take-potato (game-id uint))
  (let ((game (unwrap! (map-get? games {id: game-id}) err-not-found)))
    (begin
      (unwrap! (assert-not-paused) err-paused)
      (asserts! (is-eq (get status game) status-open) err-not-open)
      (let
        (
          (self (as-contract tx-sender))
          (stake (get stake game))
        )
        (begin
          (unwrap! (stx-transfer? stake tx-sender self) err-transfer)
          (map-set games {id: game-id}
            (merge game {holder: tx-sender, pot: (+ (get pot game) stake), passes: (+ (get passes game) u1), expires-at: (+ stacks-block-height round-blocks)}))
          (ok true))))))

(define-public (settle (game-id uint))
  (let ((game (unwrap! (map-get? games {id: game-id}) err-not-found)))
    (begin
      (asserts! (is-eq (get status game) status-open) err-not-open)
      (asserts! (> stacks-block-height (get expires-at game)) err-too-early)
      (let
        (
          (recipient (get holder game))
          (pot (get pot game))
        )
        (begin
          (unwrap! (transfer-from-contract pot recipient) err-transfer)
          (map-set games {id: game-id} (merge game {status: status-settled}))
          (ok true))))))

(define-public (cancel-game (game-id uint))
  (let ((game (unwrap! (map-get? games {id: game-id}) err-not-found)))
    (begin
      (asserts! (is-eq (get status game) status-open) err-not-open)
      (asserts! (is-eq (get holder game) tx-sender) err-not-holder)
      (asserts! (is-eq (get passes game) u0) err-too-early)
      (unwrap! (transfer-from-contract (get pot game) (get holder game)) err-transfer)
      (map-set games {id: game-id} (merge game {status: status-canceled}))
      (ok true))))

;; read only functions
(define-read-only (get-next-game-id)
  (var-get next-game-id))

(define-read-only (get-game (game-id uint))
  (map-get? games {id: game-id}))

(define-read-only (get-admin)
  (var-get admin))

(define-read-only (is-paused)
  (var-get paused))

(define-read-only (is-admin-locked)
  (var-get admin-locked))

(define-read-only (get-version)
  contract-version)
