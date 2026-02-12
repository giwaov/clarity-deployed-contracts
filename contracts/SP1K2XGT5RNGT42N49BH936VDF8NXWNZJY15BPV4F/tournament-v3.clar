;; title: tournament-v3
;; version: 1.0.0
;; summary: Scheduled tournaments with entry fees and pooled payouts.
;; clarity: 4

;; constants
(define-constant contract-version "1.0.0")
(define-constant min-entry u1000000)
(define-constant max-entry u100000000)
(define-constant max-winners u3)
(define-constant status-open u0)
(define-constant status-locked u1)
(define-constant status-settled u2)
(define-constant status-cancelled u3)
(define-constant err-not-admin (err u900))
(define-constant err-admin-unset (err u901))
(define-constant err-admin-set (err u902))
(define-constant err-paused (err u903))
(define-constant err-admin-locked (err u904))
(define-constant err-entry-low (err u600))
(define-constant err-entry-high (err u601))
(define-constant err-max-players (err u602))
(define-constant err-start-height (err u603))
(define-constant err-end-height (err u604))
(define-constant err-winner-count (err u605))
(define-constant err-not-open (err u606))
(define-constant err-not-locked (err u607))
(define-constant err-not-creator (err u608))
(define-constant err-already-joined (err u609))
(define-constant err-full (err u610))
(define-constant err-transfer (err u611))
(define-constant err-not-found (err u612))
(define-constant err-too-early (err u613))
(define-constant err-not-entrant (err u614))
(define-constant err-already-refunded (err u615))
(define-constant err-invalid-winner (err u616))
(define-constant err-duplicate-winner (err u617))
(define-constant err-too-late (err u618))
(define-constant err-rate-limited (err u619))
(define-constant err-wallet-too-new (err u620))

;; data vars
(define-data-var next-tournament-id uint u0)
(define-data-var admin (optional principal) none)
(define-data-var paused bool false)
(define-data-var admin-locked bool false)
(define-data-var min-action-interval uint u1)
(define-data-var min-wallet-age uint u0)

;; data maps
(define-map tournaments
  {id: uint}
  {
    id: uint,
    creator: principal,
    entry-fee: uint,
    max-players: uint,
    start-height: uint,
    end-height: uint,
    status: uint,
    entrants: uint,
    prize-pool: uint,
    winner-count: uint
  }
)

(define-map entrants
  {tournament-id: uint, player: principal}
  {joined: bool, refunded: bool}
)

(define-map winners
  {tournament-id: uint, rank: uint}
  {player: principal, payout: uint}
)

(define-map player-last-action
  {player: principal}
  {height: uint}
)

(define-map player-first-seen
  {player: principal}
  {height: uint}
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

(define-private (assert-creator (creator principal))
  (if (is-eq creator tx-sender) (ok true) err-not-creator))

(define-private (touch-first-seen)
  (if (is-none (map-get? player-first-seen {player: tx-sender}))
      (map-set player-first-seen {player: tx-sender} {height: stacks-block-height})
      true))

(define-private (assert-wallet-age)
  (let ((min-age (var-get min-wallet-age)))
    (if (is-eq min-age u0)
        (ok true)
        (let ((first (map-get? player-first-seen {player: tx-sender})))
          (match first
            record (if (>= (- stacks-block-height (get height record)) min-age) (ok true) err-wallet-too-new)
            err-wallet-too-new)))))

(define-private (assert-rate-limit)
  (let ((interval (var-get min-action-interval)))
    (if (is-eq interval u0)
        (ok true)
        (let ((last (map-get? player-last-action {player: tx-sender})))
          (match last
            record (if (>= (- stacks-block-height (get height record)) interval) (ok true) err-rate-limited)
            (ok true))))))

(define-private (mark-action)
  (map-set player-last-action {player: tx-sender} {height: stacks-block-height}))

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

(define-public (set-min-action-interval (interval uint))
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (var-set min-action-interval interval)
    (ok true)))

(define-public (set-min-wallet-age (age uint))
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (var-set min-wallet-age age)
    (ok true)))

;; public functions
(define-public (create-tournament (entry-fee uint) (max-players uint) (start-height uint) (end-height uint) (winner-count uint))
  (begin
    (unwrap! (assert-not-paused) err-paused)
    (touch-first-seen)
    (unwrap! (assert-wallet-age) err-wallet-too-new)
    (unwrap! (assert-rate-limit) err-rate-limited)
    (asserts! (>= entry-fee min-entry) err-entry-low)
    (asserts! (<= entry-fee max-entry) err-entry-high)
    (asserts! (>= max-players u2) err-max-players)
    (asserts! (>= start-height stacks-block-height) err-start-height)
    (asserts! (> end-height start-height) err-end-height)
    (asserts! (or (is-eq winner-count u1) (is-eq winner-count u3)) err-winner-count)
    (let ((tournament-id (var-get next-tournament-id)))
      (begin
        (map-set tournaments {id: tournament-id}
          {
            id: tournament-id,
            creator: tx-sender,
            entry-fee: entry-fee,
            max-players: max-players,
            start-height: start-height,
            end-height: end-height,
            status: status-open,
            entrants: u0,
            prize-pool: u0,
            winner-count: winner-count
          })
        (mark-action)
        (var-set next-tournament-id (+ tournament-id u1))
        (ok tournament-id)))))

(define-public (join-tournament (tournament-id uint))
  (let ((tournament (unwrap! (map-get? tournaments {id: tournament-id}) err-not-found)))
    (begin
      (unwrap! (assert-not-paused) err-paused)
      (touch-first-seen)
      (unwrap! (assert-wallet-age) err-wallet-too-new)
      (unwrap! (assert-rate-limit) err-rate-limited)
      (asserts! (is-eq (get status tournament) status-open) err-not-open)
      (asserts! (< stacks-block-height (get start-height tournament)) err-too-late)
      (asserts! (< (get entrants tournament) (get max-players tournament)) err-full)
      (asserts! (is-none (map-get? entrants {tournament-id: tournament-id, player: tx-sender})) err-already-joined)
      (let ((self (as-contract tx-sender)))
        (unwrap! (stx-transfer? (get entry-fee tournament) tx-sender self) err-transfer))
      (map-set entrants {tournament-id: tournament-id, player: tx-sender} {joined: true, refunded: false})
      (map-set tournaments {id: tournament-id}
        (merge tournament {entrants: (+ (get entrants tournament) u1), prize-pool: (+ (get prize-pool tournament) (get entry-fee tournament))}))
      (mark-action)
      (ok true))))

(define-public (lock-tournament (tournament-id uint))
  (let ((tournament (unwrap! (map-get? tournaments {id: tournament-id}) err-not-found)))
    (begin
      (unwrap! (assert-creator (get creator tournament)) err-not-creator)
      (asserts! (is-eq (get status tournament) status-open) err-not-open)
      (asserts! (or (>= stacks-block-height (get start-height tournament)) (is-eq (get entrants tournament) (get max-players tournament))) err-too-early)
      (map-set tournaments {id: tournament-id} (merge tournament {status: status-locked}))
      (ok true))))

(define-public (cancel-tournament (tournament-id uint))
  (let ((tournament (unwrap! (map-get? tournaments {id: tournament-id}) err-not-found)))
    (begin
      (unwrap! (assert-creator (get creator tournament)) err-not-creator)
      (asserts! (is-eq (get status tournament) status-open) err-not-open)
      (map-set tournaments {id: tournament-id} (merge tournament {status: status-cancelled}))
      (ok true))))

(define-public (claim-refund (tournament-id uint))
  (let (
    (tournament (unwrap! (map-get? tournaments {id: tournament-id}) err-not-found))
    (entrant (unwrap! (map-get? entrants {tournament-id: tournament-id, player: tx-sender}) err-not-entrant))
  )
    (begin
      (asserts! (is-eq (get status tournament) status-cancelled) err-not-open)
      (asserts! (not (get refunded entrant)) err-already-refunded)
      (unwrap! (transfer-from-contract (get entry-fee tournament) tx-sender) err-transfer)
      (map-set entrants {tournament-id: tournament-id, player: tx-sender} (merge entrant {refunded: true}))
      (ok true))))

(define-public (settle-single (tournament-id uint) (winner principal))
  (let ((tournament (unwrap! (map-get? tournaments {id: tournament-id}) err-not-found)))
    (begin
      (unwrap! (assert-creator (get creator tournament)) err-not-creator)
      (asserts! (is-eq (get status tournament) status-locked) err-not-locked)
      (asserts! (>= stacks-block-height (get end-height tournament)) err-too-early)
      (asserts! (is-eq (get winner-count tournament) u1) err-winner-count)
      (asserts! (is-some (map-get? entrants {tournament-id: tournament-id, player: winner})) err-invalid-winner)
      (let ((payout (get prize-pool tournament)))
        (begin
          (unwrap! (transfer-from-contract payout winner) err-transfer)
          (map-set winners {tournament-id: tournament-id, rank: u1} {player: winner, payout: payout})
          (map-set tournaments {id: tournament-id} (merge tournament {status: status-settled}))
          (ok true))))))

(define-public (settle-top3 (tournament-id uint) (winner1 principal) (winner2 principal) (winner3 principal))
  (let ((tournament (unwrap! (map-get? tournaments {id: tournament-id}) err-not-found)))
    (begin
      (unwrap! (assert-creator (get creator tournament)) err-not-creator)
      (asserts! (is-eq (get status tournament) status-locked) err-not-locked)
      (asserts! (>= stacks-block-height (get end-height tournament)) err-too-early)
      (asserts! (is-eq (get winner-count tournament) u3) err-winner-count)
      (asserts! (is-some (map-get? entrants {tournament-id: tournament-id, player: winner1})) err-invalid-winner)
      (asserts! (is-some (map-get? entrants {tournament-id: tournament-id, player: winner2})) err-invalid-winner)
      (asserts! (is-some (map-get? entrants {tournament-id: tournament-id, player: winner3})) err-invalid-winner)
      (asserts! (and (not (is-eq winner1 winner2)) (not (is-eq winner1 winner3)) (not (is-eq winner2 winner3))) err-duplicate-winner)
      (let
        (
          (pool (get prize-pool tournament))
          (payout1 (/ (* pool u70) u100))
          (payout2 (/ (* pool u20) u100))
          (payout3 (- pool (+ (/ (* pool u70) u100) (/ (* pool u20) u100))))
        )
        (begin
          (unwrap! (transfer-from-contract payout1 winner1) err-transfer)
          (unwrap! (transfer-from-contract payout2 winner2) err-transfer)
          (unwrap! (transfer-from-contract payout3 winner3) err-transfer)
          (map-set winners {tournament-id: tournament-id, rank: u1} {player: winner1, payout: payout1})
          (map-set winners {tournament-id: tournament-id, rank: u2} {player: winner2, payout: payout2})
          (map-set winners {tournament-id: tournament-id, rank: u3} {player: winner3, payout: payout3})
          (map-set tournaments {id: tournament-id} (merge tournament {status: status-settled}))
          (ok true))))))

;; read only functions
(define-read-only (get-next-tournament-id)
  (var-get next-tournament-id))

(define-read-only (get-tournament (tournament-id uint))
  (map-get? tournaments {id: tournament-id}))

(define-read-only (get-entrant (tournament-id uint) (player principal))
  (map-get? entrants {tournament-id: tournament-id, player: player}))

(define-read-only (get-winner (tournament-id uint) (rank uint))
  (map-get? winners {tournament-id: tournament-id, rank: rank}))

(define-read-only (get-admin)
  (var-get admin))

(define-read-only (is-paused)
  (var-get paused))

(define-read-only (is-admin-locked)
  (var-get admin-locked))

(define-read-only (get-min-action-interval)
  (var-get min-action-interval))

(define-read-only (get-min-wallet-age)
  (var-get min-wallet-age))

(define-read-only (get-version)
  contract-version)
