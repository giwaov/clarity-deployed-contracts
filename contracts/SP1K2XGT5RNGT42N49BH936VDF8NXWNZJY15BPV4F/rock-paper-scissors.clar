;; title: rock-paper-scissors
;; version: 1.0.0
;; summary: Two-player RPS with commit-reveal and escrowed stakes.
;; clarity: 4

;; constants
(define-constant contract-version "1.0.0")
(define-constant min-stake u1000000)
(define-constant max-stake u100000000)
(define-constant reveal-window u144)
(define-constant status-open u0)
(define-constant status-locked u1)
(define-constant status-settled u2)
(define-constant status-expired u3)
(define-constant choice-rock u0)
(define-constant choice-paper u1)
(define-constant choice-scissors u2)
(define-constant err-not-admin (err u900))
(define-constant err-admin-unset (err u901))
(define-constant err-admin-set (err u902))
(define-constant err-paused (err u903))
(define-constant err-admin-locked (err u904))
(define-constant err-invalid-choice (err u400))
(define-constant err-stake-low (err u401))
(define-constant err-stake-high (err u402))
(define-constant err-not-open (err u403))
(define-constant err-already-joined (err u404))
(define-constant err-self-join (err u405))
(define-constant err-transfer (err u406))
(define-constant err-not-player (err u407))
(define-constant err-commit-mismatch (err u408))
(define-constant err-too-early (err u409))
(define-constant err-expired (err u410))
(define-constant err-not-found (err u411))

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
    creator: principal,
    challenger: (optional principal),
    stake: uint,
    commit1: (buff 32),
    commit2: (optional (buff 32)),
    reveal1: (optional uint),
    reveal2: (optional uint),
    status: uint,
    join-height: (optional uint)
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

(define-private (choice-byte (choice uint))
  (if (is-eq choice choice-rock) 0x00
      (if (is-eq choice choice-paper) 0x01 0x02)))

(define-private (commit-hash (secret (buff 32)) (choice uint))
  (sha256 (concat secret (choice-byte choice))))

(define-private (beats? (a uint) (b uint))
  (or (and (is-eq a choice-rock) (is-eq b choice-scissors))
      (and (is-eq a choice-scissors) (is-eq b choice-paper))
      (and (is-eq a choice-paper) (is-eq b choice-rock))))

(define-private (resolve (a uint) (b uint))
  (if (is-eq a b) u0 (if (beats? a b) u1 u2)))

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
(define-public (create-game (stake uint) (commit (buff 32)))
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
            creator: tx-sender,
            challenger: none,
            stake: stake,
            commit1: commit,
            commit2: none,
            reveal1: none,
            reveal2: none,
            status: status-open,
            join-height: none
          })
        (var-set next-game-id (+ game-id u1))
        (ok game-id)))))

(define-public (join-game (game-id uint) (commit (buff 32)))
  (let ((game (unwrap! (map-get? games {id: game-id}) err-not-found)))
    (begin
      (unwrap! (assert-not-paused) err-paused)
      (asserts! (is-eq (get status game) status-open) err-not-open)
      (asserts! (is-none (get challenger game)) err-already-joined)
      (asserts! (not (is-eq tx-sender (get creator game))) err-self-join)
      (let ((self (as-contract tx-sender)))
        (unwrap! (stx-transfer? (get stake game) tx-sender self) err-transfer))
      (map-set games {id: game-id}
        (merge game {challenger: (some tx-sender), commit2: (some commit), status: status-locked, join-height: (some stacks-block-height)}))
      (ok true))))

(define-public (reveal (game-id uint) (choice uint) (secret (buff 32)))
  (let ((game (unwrap! (map-get? games {id: game-id}) err-not-found)))
    (begin
      (unwrap! (assert-not-paused) err-paused)
      (asserts! (or (is-eq choice choice-rock) (is-eq choice choice-paper) (is-eq choice choice-scissors)) err-invalid-choice)
      (asserts! (is-eq (get status game) status-locked) err-not-open)
      (let
        (
          (is-creator (is-eq tx-sender (get creator game)))
          (challenger (default-to tx-sender (get challenger game)))
          (deadline (+ (default-to stacks-block-height (get join-height game)) reveal-window))
        )
        (begin
          (asserts! (or is-creator (is-eq tx-sender challenger)) err-not-player)
          (asserts! (<= stacks-block-height deadline) err-expired)
          (if is-creator
              (begin
                (asserts! (is-eq (commit-hash secret choice) (get commit1 game)) err-commit-mismatch)
                (map-set games {id: game-id} (merge game {reveal1: (some choice)})))
              (begin
                (asserts! (is-eq (commit-hash secret choice) (unwrap-panic (get commit2 game))) err-commit-mismatch)
                (map-set games {id: game-id} (merge game {reveal2: (some choice)}))))
          (let
            (
              (updated (unwrap-panic (map-get? games {id: game-id})))
              (r1 (get reveal1 updated))
              (r2 (get reveal2 updated))
            )
            (if (and (is-some r1) (is-some r2))
                (let
                  (
                    (choice1 (unwrap-panic r1))
                    (choice2 (unwrap-panic r2))
                    (outcome (resolve choice1 choice2))
                    (stake (get stake updated))
                    (creator (get creator updated))
                    (challenger-player (default-to creator (get challenger updated)))
                  )
                  (begin
                    (if (is-eq outcome u0)
                        (begin
                          (unwrap! (transfer-from-contract stake creator) err-transfer)
                          (unwrap! (transfer-from-contract stake challenger-player) err-transfer))
                        (let ((winner (if (is-eq outcome u1) creator challenger-player)))
                          (unwrap! (transfer-from-contract (* stake u2) winner) err-transfer)))
                    (map-set games {id: game-id} (merge updated {status: status-settled}))
                    (ok {result: outcome})))
                (ok {result: u0}))))))))

(define-public (expire-game (game-id uint))
  (let ((game (unwrap! (map-get? games {id: game-id}) err-not-found)))
    (begin
      (asserts! (is-eq (get status game) status-locked) err-not-open)
      (let
        (
          (deadline (+ (default-to stacks-block-height (get join-height game)) reveal-window))
          (stake (get stake game))
          (creator (get creator game))
          (challenger (default-to creator (get challenger game)))
        )
        (begin
          (asserts! (> stacks-block-height deadline) err-too-early)
          (if (and (is-some (get reveal1 game)) (is-none (get reveal2 game)))
              (unwrap! (transfer-from-contract (* stake u2) creator) err-transfer)
              (if (and (is-none (get reveal1 game)) (is-some (get reveal2 game)))
                  (unwrap! (transfer-from-contract (* stake u2) challenger) err-transfer)
                  (begin
                    (unwrap! (transfer-from-contract stake creator) err-transfer)
                    (unwrap! (transfer-from-contract stake challenger) err-transfer))))
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
