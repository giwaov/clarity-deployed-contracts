;; title: guess-the-number
;; version: 1.0.0
;; summary: Commit-reveal number guessing with escrowed wager.
;; clarity: 4

;; constants
(define-constant contract-version "1.0.0")
(define-constant min-bet u1000000) ;; 0.01 STX
(define-constant max-bet u100000000) ;; 1 STX
(define-constant max-number u9)
(define-constant reveal-delay u1)
(define-constant reveal-window u144)
(define-constant status-open u0)
(define-constant status-settled u1)
(define-constant status-expired u2)
(define-constant err-not-admin (err u900))
(define-constant err-admin-unset (err u901))
(define-constant err-admin-set (err u902))
(define-constant err-paused (err u903))
(define-constant err-admin-locked (err u904))
(define-constant err-invalid-guess (err u400))
(define-constant err-bet-low (err u401))
(define-constant err-bet-high (err u402))
(define-constant err-not-open (err u403))
(define-constant err-not-player (err u404))
(define-constant err-transfer (err u405))
(define-constant err-commit-mismatch (err u406))
(define-constant err-too-early (err u407))
(define-constant err-expired (err u408))
(define-constant err-not-found (err u409))
(define-constant err-insufficient-treasury (err u410))

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
    player: principal,
    wager: uint,
    commit: (buff 32),
    commit-height: uint,
    status: uint,
    draw: (optional uint),
    winner: bool
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

(define-private (num-byte (guess uint))
  (if (is-eq guess u0) 0x00
    (if (is-eq guess u1) 0x01
      (if (is-eq guess u2) 0x02
        (if (is-eq guess u3) 0x03
          (if (is-eq guess u4) 0x04
            (if (is-eq guess u5) 0x05
              (if (is-eq guess u6) 0x06
                (if (is-eq guess u7) 0x07
                  (if (is-eq guess u8) 0x08 0x09))))))))))

(define-private (commit-hash (secret (buff 32)) (guess uint))
  (sha256 (concat secret (num-byte guess))))

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

(define-public (treasury-withdraw (amount uint))
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (let ((balance (stx-get-balance (as-contract tx-sender))))
      (asserts! (>= balance amount) err-insufficient-treasury))
    (let ((recipient tx-sender))
      (unwrap! (transfer-from-contract amount recipient) err-transfer))
    (ok true)))

;; public functions
(define-public (create-game (wager uint) (commit (buff 32)))
  (begin
    (unwrap! (assert-not-paused) err-paused)
    (asserts! (>= wager min-bet) err-bet-low)
    (asserts! (<= wager max-bet) err-bet-high)
    (let
      (
        (game-id (var-get next-game-id))
        (self (as-contract tx-sender))
      )
      (begin
        (unwrap! (stx-transfer? wager tx-sender self) err-transfer)
        (map-set games {id: game-id}
          {
            id: game-id,
            player: tx-sender,
            wager: wager,
            commit: commit,
            commit-height: stacks-block-height,
            status: status-open,
            draw: none,
            winner: false
          })
        (var-set next-game-id (+ game-id u1))
        (ok game-id)))))

(define-public (reveal (game-id uint) (guess uint) (secret (buff 32)))
  (let ((game (unwrap! (map-get? games {id: game-id}) err-not-found)))
    (begin
      (unwrap! (assert-not-paused) err-paused)
      (asserts! (<= guess max-number) err-invalid-guess)
      (asserts! (is-eq (get status game) status-open) err-not-open)
      (asserts! (is-eq (get player game) tx-sender) err-not-player)
      (asserts! (is-eq (commit-hash secret guess) (get commit game)) err-commit-mismatch)
      (let
        (
          (reveal-height (+ (get commit-height game) reveal-delay))
          (expire-height (+ (get commit-height game) reveal-window))
        )
        (begin
          (asserts! (>= stacks-block-height reveal-height) err-too-early)
          (asserts! (<= stacks-block-height expire-height) err-expired)
          (let
            (
              (draw (mod (random-from-height reveal-height) (+ max-number u1)))
              (winner (is-eq guess draw))
              (payout (if (is-eq guess draw) (* (get wager game) u2) u0))
            )
            (begin
              (if (> payout u0)
                (begin
                  (let ((balance (stx-get-balance (as-contract tx-sender))))
                    (asserts! (>= balance payout) err-insufficient-treasury))
                  (unwrap! (transfer-from-contract payout (get player game)) err-transfer))
                true)
              (map-set games {id: game-id} (merge game {status: status-settled, draw: (some draw), winner: winner}))
              (ok {draw: draw, winner: winner, payout: payout}))))))))

(define-public (expire-game (game-id uint))
  (let ((game (unwrap! (map-get? games {id: game-id}) err-not-found)))
    (begin
      (asserts! (is-eq (get status game) status-open) err-not-open)
      (asserts! (> stacks-block-height (+ (get commit-height game) reveal-window)) err-too-early)
      (let
        (
          (recipient (match (var-get admin) admin-principal admin-principal (get player game)))
          (wager (get wager game))
        )
        (begin
          (unwrap! (transfer-from-contract wager recipient) err-transfer)
          (map-set games {id: game-id} (merge game {status: status-expired}))
          (ok true))))))

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
