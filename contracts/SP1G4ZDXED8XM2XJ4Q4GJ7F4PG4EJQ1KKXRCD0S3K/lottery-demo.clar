;; title: lottery-demo
;; version: 1.0.0
;; summary: Simple raffle with ticket purchases and block-hash draw.
;; clarity: 4

;; constants
(define-constant contract-version "1.0.0")
(define-constant min-ticket u1000000)
(define-constant max-ticket u100000000)
(define-constant status-open u0)
(define-constant status-drawn u1)
(define-constant status-canceled u2)
(define-constant err-not-admin (err u900))
(define-constant err-admin-unset (err u901))
(define-constant err-admin-set (err u902))
(define-constant err-paused (err u903))
(define-constant err-admin-locked (err u904))
(define-constant err-ticket-low (err u400))
(define-constant err-ticket-high (err u401))
(define-constant err-not-open (err u402))
(define-constant err-transfer (err u403))
(define-constant err-too-early (err u404))
(define-constant err-no-tickets (err u405))
(define-constant err-not-found (err u406))

;; data vars
(define-data-var next-round-id uint u0)
(define-data-var admin (optional principal) none)
(define-data-var paused bool false)
(define-data-var admin-locked bool false)

;; data maps
(define-map rounds
  {id: uint}
  {
    id: uint,
    ticket-price: uint,
    total: uint,
    close-height: uint,
    status: uint
  }
)

(define-map tickets
  {round-id: uint, index: uint}
  {player: principal}
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

(define-private (random-from-height (height uint))
  (let (
    (hash-opt (get-stacks-block-info? header-hash height))
  )
    (match hash-opt
      hash
      (let ((part (unwrap-panic (slice? hash u0 u16))))
        (buff-to-uint-be (unwrap-panic (as-max-len? part u16))))
      u0)))

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
(define-public (create-round (ticket-price uint) (duration uint))
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (unwrap! (assert-not-paused) err-paused)
    (asserts! (>= ticket-price min-ticket) err-ticket-low)
    (asserts! (<= ticket-price max-ticket) err-ticket-high)
    (let
      (
        (round-id (var-get next-round-id))
      )
      (begin
        (map-set rounds {id: round-id}
          {
            id: round-id,
            ticket-price: ticket-price,
            total: u0,
            close-height: (+ stacks-block-height duration),
            status: status-open
          })
        (var-set next-round-id (+ round-id u1))
        (ok round-id)))))

(define-public (buy-ticket (round-id uint))
  (let ((round (unwrap! (map-get? rounds {id: round-id}) err-not-found)))
    (begin
      (unwrap! (assert-not-paused) err-paused)
      (asserts! (is-eq (get status round) status-open) err-not-open)
      (let
        (
          (self (as-contract tx-sender))
          (ticket (get ticket-price round))
          (index (get total round))
        )
        (begin
          (unwrap! (stx-transfer? ticket tx-sender self) err-transfer)
          (map-set tickets {round-id: round-id, index: index} {player: tx-sender})
          (map-set rounds {id: round-id} (merge round {total: (+ index u1)}))
          (ok true))))))

(define-public (draw (round-id uint))
  (let ((round (unwrap! (map-get? rounds {id: round-id}) err-not-found)))
    (begin
      (unwrap! (assert-admin) err-not-admin)
      (asserts! (is-eq (get status round) status-open) err-not-open)
      (asserts! (> stacks-block-height (get close-height round)) err-too-early)
      (asserts! (> (get total round) u0) err-no-tickets)
      (let
        (
          (total (get total round))
          (ticket (get ticket-price round))
          (winner-index (mod (random-from-height (+ (get close-height round) u1)) total))
          (winner (get player (unwrap-panic (map-get? tickets {round-id: round-id, index: winner-index}))))
          (payout (* ticket total))
        )
        (begin
          (unwrap! (transfer-from-contract payout winner) err-transfer)
          (map-set rounds {id: round-id} (merge round {status: status-drawn}))
          (ok {winner: winner, payout: payout}))))))

(define-public (cancel-round (round-id uint))
  (let ((round (unwrap! (map-get? rounds {id: round-id}) err-not-found)))
    (begin
      (unwrap! (assert-admin) err-not-admin)
      (asserts! (is-eq (get status round) status-open) err-not-open)
      (asserts! (is-eq (get total round) u0) err-no-tickets)
      (map-set rounds {id: round-id} (merge round {status: status-canceled}))
      (ok true))))

;; read only functions
(define-read-only (get-next-round-id)
  (var-get next-round-id))

(define-read-only (get-round (round-id uint))
  (map-get? rounds {id: round-id}))

(define-read-only (get-admin)
  (var-get admin))

(define-read-only (is-paused)
  (var-get paused))

(define-read-only (is-admin-locked)
  (var-get admin-locked))

(define-read-only (get-version)
  contract-version)
