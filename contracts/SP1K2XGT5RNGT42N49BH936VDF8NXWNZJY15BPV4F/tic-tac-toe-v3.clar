;; title: tic-tac-toe-v3
;; version: 1.0.0
;; summary: Two-player tic-tac-toe-v3 with compact bitboard storage.
;; clarity: 4

;; constants
(define-constant contract-version "1.0.0")
(define-constant status-open u0)
(define-constant status-locked u1)
(define-constant status-finished u2)
(define-constant status-canceled u3)
(define-constant turn-p1 u0)
(define-constant turn-p2 u1)
(define-constant board-full u511) ;; 9 bits set
(define-constant err-not-admin (err u900))
(define-constant err-admin-unset (err u901))
(define-constant err-admin-set (err u902))
(define-constant err-paused (err u903))
(define-constant err-admin-locked (err u904))
(define-constant err-not-open (err u400))
(define-constant err-not-player (err u401))
(define-constant err-not-your-turn (err u402))
(define-constant err-invalid-move (err u403))
(define-constant err-not-found (err u404))

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
    player1: principal,
    player2: (optional principal),
    board1: uint,
    board2: uint,
    turn: uint,
    status: uint,
    winner: (optional principal)
  }
)

;; private helpers
(define-private (assert-admin)
  (match (var-get admin)
    admin-principal (if (is-eq admin-principal tx-sender) (ok true) err-not-admin)
    err-admin-unset))

(define-private (assert-not-paused)
  (if (var-get paused) err-paused (ok true)))

(define-private (pos-mask (pos uint))
  (if (is-eq pos u0) u1
    (if (is-eq pos u1) u2
      (if (is-eq pos u2) u4
        (if (is-eq pos u3) u8
          (if (is-eq pos u4) u16
            (if (is-eq pos u5) u32
              (if (is-eq pos u6) u64
                (if (is-eq pos u7) u128 u256)))))))))

(define-private (is-winner (board uint))
  (or
    (is-eq (bit-and board u7) u7)
    (is-eq (bit-and board u56) u56)
    (is-eq (bit-and board u448) u448)
    (is-eq (bit-and board u73) u73)
    (is-eq (bit-and board u146) u146)
    (is-eq (bit-and board u292) u292)
    (is-eq (bit-and board u273) u273)
    (is-eq (bit-and board u84) u84)))

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
(define-public (create-game)
  (begin
    (unwrap! (assert-not-paused) err-paused)
    (let ((game-id (var-get next-game-id)))
      (begin
        (map-set games {id: game-id}
          {
            id: game-id,
            player1: tx-sender,
            player2: none,
            board1: u0,
            board2: u0,
            turn: turn-p1,
            status: status-open,
            winner: none
          })
        (var-set next-game-id (+ game-id u1))
        (ok game-id)))))

(define-public (join-game (game-id uint))
  (let ((game (unwrap! (map-get? games {id: game-id}) err-not-found)))
    (begin
      (unwrap! (assert-not-paused) err-paused)
      (asserts! (is-eq (get status game) status-open) err-not-open)
      (asserts! (not (is-eq tx-sender (get player1 game))) err-not-player)
      (map-set games {id: game-id}
        (merge game {player2: (some tx-sender), status: status-locked}))
      (ok true))))

(define-public (play (game-id uint) (pos uint))
  (let ((game (unwrap! (map-get? games {id: game-id}) err-not-found)))
    (begin
      (unwrap! (assert-not-paused) err-paused)
      (asserts! (is-eq (get status game) status-locked) err-not-open)
      (asserts! (<= pos u8) err-invalid-move)
      (let
        (
          (player1 (get player1 game))
          (player2 (default-to (get player1 game) (get player2 game)))
          (mask (pos-mask pos))
          (occupied (bit-or (get board1 game) (get board2 game)))
        )
        (begin
          (asserts! (is-eq (bit-and mask occupied) u0) err-invalid-move)
          (if (is-eq (get turn game) turn-p1)
              (begin
                (asserts! (is-eq tx-sender player1) err-not-your-turn)
                (let ((new-board (bit-or (get board1 game) mask)))
                  (if (is-winner new-board)
                      (begin
                        (map-set games {id: game-id} (merge game {board1: new-board, status: status-finished, winner: (some player1)}))
                        (ok true))
                      (if (is-eq (bit-or new-board (get board2 game)) board-full)
                          (begin
                            (map-set games {id: game-id} (merge game {board1: new-board, status: status-finished, winner: none}))
                            (ok true))
                          (begin
                            (map-set games {id: game-id} (merge game {board1: new-board, turn: turn-p2}))
                            (ok true))))))
              (begin
                (asserts! (is-eq tx-sender player2) err-not-your-turn)
                (let ((new-board (bit-or (get board2 game) mask)))
                  (if (is-winner new-board)
                      (begin
                        (map-set games {id: game-id} (merge game {board2: new-board, status: status-finished, winner: (some player2)}))
                        (ok true))
                      (if (is-eq (bit-or new-board (get board1 game)) board-full)
                          (begin
                            (map-set games {id: game-id} (merge game {board2: new-board, status: status-finished, winner: none}))
                            (ok true))
                          (begin
                            (map-set games {id: game-id} (merge game {board2: new-board, turn: turn-p1}))
                            (ok true))))))))))))

(define-public (cancel-game (game-id uint))
  (let ((game (unwrap! (map-get? games {id: game-id}) err-not-found)))
    (begin
      (asserts! (is-eq (get status game) status-open) err-not-open)
      (asserts! (is-eq (get player1 game) tx-sender) err-not-player)
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
