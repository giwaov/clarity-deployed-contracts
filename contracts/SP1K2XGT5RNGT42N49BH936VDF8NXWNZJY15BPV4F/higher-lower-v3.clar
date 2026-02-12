;; title: higher-lower-v3
;; version: 1.0.0
;; summary: Commit-reveal higher or lower guessing game.
;; clarity: 4

;; constants
(define-constant contract-version "1.0.0")
(define-constant min-bet u1000000)
(define-constant max-bet u100000000)
(define-constant max-number u9)
(define-constant choice-lower u0)
(define-constant choice-higher u1)
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
    target: (optional uint),
    draw: (optional uint),
    outcome: (optional uint)
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

(define-private (num-byte (value uint))
  (if (is-eq value u0) 0x00
    (if (is-eq value u1) 0x01
      (if (is-eq value u2) 0x02
        (if (is-eq value u3) 0x03
          (if (is-eq value u4) 0x04
            (if (is-eq value u5) 0x05
              (if (is-eq value u6) 0x06
                (if (is-eq value u7) 0x07
                  (if (is-eq value u8) 0x08 0x09))))))))))

(define-private (choice-byte (choice uint))
  (if (is-eq choice choice-lower) 0x00 0x01))

(define-private (commit-hash (secret (buff 32)) (choice uint) (target uint))
  (sha256 (concat (concat secret (choice-byte choice)) (num-byte target))))

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
            target: none,
            draw: none,
            outcome: none
          })
        (var-set next-game-id (+ game-id u1))
        (ok game-id)))))

(define-public (reveal (game-id uint) (choice uint) (target uint) (secret (buff 32)))
  (let ((game (unwrap! (map-get? games {id: game-id}) err-not-found)))
    (begin
      (unwrap! (assert-not-paused) err-paused)
      (asserts! (or (is-eq choice choice-lower) (is-eq choice choice-higher)) err-invalid-guess)
      (asserts! (<= target max-number) err-invalid-guess)
      (asserts! (is-eq (get status game) status-open) err-not-open)
      (asserts! (is-eq (get player game) tx-sender) err-not-player)
      (asserts! (is-eq (commit-hash secret choice target) (get commit game)) err-commit-mismatch)
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
              (outcome (if (is-eq draw target) u2 (if (and (is-eq choice choice-higher) (> draw target)) u1 (if (and (is-eq choice choice-lower) (< draw target)) u1 u0))))
              (payout (if (is-eq outcome u1) (* (get wager game) u2) (if (is-eq outcome u2) (get wager game) u0)))
            )
            (begin
              (if (> payout u0)
                (begin
                  (let ((balance (stx-get-balance (as-contract tx-sender))))
                    (asserts! (>= balance payout) err-insufficient-treasury))
                  (unwrap! (transfer-from-contract payout (get player game)) err-transfer))
                true)
              (map-set games {id: game-id} (merge game {status: status-settled, target: (some target), draw: (some draw), outcome: (some outcome)}))
              (ok {draw: draw, outcome: outcome, payout: payout}))))))))

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
