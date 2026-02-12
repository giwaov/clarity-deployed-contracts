;; StacksTacToe - Decentralized PvP Tic-Tac-Toe Game
;; A winner-takes-all betting game on Stacks blockchain
;; Supports STX, sBTC, BTC, and USDCx tokens

;; ============================================
;; Constants
;; ============================================

;; Contract owner
(define-constant CONTRACT_OWNER tx-sender)

;; Game parameters
(define-constant DEFAULT_MOVE_TIMEOUT u144) ;; ~24 hours in blocks (assuming 10 min blocks)
(define-constant MAX_TIMEOUT u1008) ;; ~7 days in blocks
(define-constant DEFAULT_BOARD_SIZE u3)
(define-constant LEADERBOARD_SIZE u100)
(define-constant DEFAULT_K_FACTOR u100) ;; ELO rating change factor
(define-constant STARTING_RATING u1000) ;; Starting ELO rating
(define-constant MAX_USERNAME_LENGTH u32)

;; Game status
(define-constant STATUS_ACTIVE u0)
(define-constant STATUS_ENDED u1)
(define-constant STATUS_FORFEITED u2)

;; Player marks
(define-constant MARK_EMPTY u0)
(define-constant MARK_X u1)
(define-constant MARK_O u2)

;; Basis points for fee calculation (10000 = 100%)
(define-constant BASIS_POINTS u10000)

;; ============================================
;; Error Codes
;; ============================================

(define-constant ERR_INVALID_ID (err u100))
(define-constant ERR_NOT_ACTIVE (err u101))
(define-constant ERR_INVALID_MOVE (err u102))
(define-constant ERR_NOT_TURN (err u103))
(define-constant ERR_INVALID_BET (err u104))
(define-constant ERR_BET_MISMATCH (err u105))
(define-constant ERR_GAME_STARTED (err u106))
(define-constant ERR_CELL_OCCUPIED (err u107))
(define-constant ERR_TIMEOUT (err u108))
(define-constant ERR_UNAUTHORIZED (err u109))
(define-constant ERR_SELF_PLAY (err u110))
(define-constant ERR_TRANSFER_FAILED (err u111))
(define-constant ERR_INVALID_ADDR (err u112))
(define-constant ERR_USERNAME_TAKEN (err u113))
(define-constant ERR_INVALID_USERNAME (err u114))
(define-constant ERR_NOT_REGISTERED (err u115))
(define-constant ERR_NOT_ADMIN (err u116))
(define-constant ERR_INVALID_TIMEOUT (err u117))
(define-constant ERR_INVALID_FEE (err u118))
(define-constant ERR_INVALID_K_FACTOR (err u119))
(define-constant ERR_TOKEN_NOT_SUPPORTED (err u120))
(define-constant ERR_CHALLENGE_ACCEPTED (err u121))
(define-constant ERR_SELF_CHALLENGE (err u122))
(define-constant ERR_NO_REWARD (err u123))
(define-constant ERR_REWARD_CLAIMED (err u124))
(define-constant ERR_NOT_WINNER (err u125))
(define-constant ERR_INVALID_BOARD_SIZE (err u126))
(define-constant ERR_GAME_NOT_FINISHED (err u127))
(define-constant ERR_ALREADY_REGISTERED (err u128))
(define-constant ERR_PAUSED (err u129))

;; ============================================
;; Data Variables
;; ============================================

;; Admin and configuration
(define-data-var contract-paused bool false)
(define-data-var move-timeout uint DEFAULT_MOVE_TIMEOUT)
(define-data-var platform-fee-percent uint u0) ;; Default: no fee
(define-data-var platform-fee-recipient principal CONTRACT_OWNER)
(define-data-var k-factor uint DEFAULT_K_FACTOR)

;; Counters
(define-data-var game-id-counter uint u0)
(define-data-var challenge-id-counter uint u0)

;; ============================================
;; Data Maps
;; ============================================

;; Admin management
(define-map admins principal bool)

;; TODO: SIP-010 token support will be added in future enhancement
;; For now, only STX is supported

;; Player data
(define-map players 
    principal 
    {
        username: (string-utf8 32),
        wins: uint,
        losses: uint,
        draws: uint,
        total-games: uint,
        rating: uint,
        registered: bool
    }
)

(define-map username-to-address (string-utf8 32) principal)

;; Game data
(define-map games
    uint
    {
        player-one: principal,
        player-two: (optional principal),
        bet-amount: uint,
        board-size: uint,
        is-player-one-turn: bool,
        winner: (optional principal),
        last-move-block: uint,
        status: uint
    }
)

;; Game boards (game-id => cell-index => mark)
(define-map game-boards { game-id: uint, cell-index: uint } uint)

;; Claimable rewards
(define-map claimable-rewards uint uint)
(define-map reward-claimed uint bool)

;; Challenge system
(define-map challenges
    uint
    {
        challenger: principal,
        challenger-username: (string-utf8 32),
        challenged: principal,
        challenged-username: (string-utf8 32),
        bet-amount: uint,
        board-size: uint,
        created-at-block: uint,
        accepted: bool,
        game-id: (optional uint)
    }
)

;; Player challenges (for tracking)
(define-map player-challenges principal (list 100 uint))

;; Leaderboard
(define-map leaderboard-entries
    uint
    {
        player: principal,
        username: (string-utf8 32),
        rating: uint,
        wins: uint
    }
)

(define-data-var leaderboard-size uint u0)

;; ============================================
;; Initialization
;; ============================================

;; Set contract owner as admin
(map-set admins CONTRACT_OWNER true)

;; STX is always supported - no need to add to map

;; ============================================
;; Private Helper Functions
;; ============================================

(define-private (is-admin (caller principal))
    (or 
        (is-eq caller CONTRACT_OWNER)
        (default-to false (map-get? admins caller))
    )
)

(define-private (is-registered (player principal))
    (default-to false (get registered (map-get? players player)))
)

;; ============================================
;; Admin Functions
;; ============================================

(define-public (add-admin (admin principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (ok (map-set admins admin true))
    )
)

(define-public (remove-admin (admin principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (ok (map-set admins admin false))
    )
)

(define-public (set-move-timeout (new-timeout uint))
    (begin
        (asserts! (is-admin tx-sender) ERR_NOT_ADMIN)
        (asserts! (and (> new-timeout u0) (<= new-timeout MAX_TIMEOUT)) ERR_INVALID_TIMEOUT)
        (ok (var-set move-timeout new-timeout))
    )
)

(define-public (set-platform-fee (new-fee-percent uint))
    (begin
        (asserts! (is-admin tx-sender) ERR_NOT_ADMIN)
        (asserts! (<= new-fee-percent u1000) ERR_INVALID_FEE) ;; Max 10%
        (ok (var-set platform-fee-percent new-fee-percent))
    )
)

(define-public (set-platform-fee-recipient (recipient principal))
    (begin
        (asserts! (is-admin tx-sender) ERR_NOT_ADMIN)
        (ok (var-set platform-fee-recipient recipient))
    )
)

(define-public (set-k-factor (new-k-factor uint))
    (begin
        (asserts! (is-admin tx-sender) ERR_NOT_ADMIN)
        (asserts! (and (> new-k-factor u0) (<= new-k-factor u1000)) ERR_INVALID_K_FACTOR)
        (ok (var-set k-factor new-k-factor))
    )
)



(define-public (pause-contract)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (ok (var-set contract-paused true))
    )
)

(define-public (unpause-contract)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (ok (var-set contract-paused false))
    )
)

;; ============================================
;; Player Registration Functions
;; ============================================

(define-public (register-player (username (string-utf8 32)))
    (let
        (
            (username-length (len username))
        )
        (asserts! (and (> username-length u0) (<= username-length MAX_USERNAME_LENGTH)) ERR_INVALID_USERNAME)
        (asserts! (is-none (map-get? username-to-address username)) ERR_USERNAME_TAKEN)
        (asserts! (not (is-registered tx-sender)) ERR_ALREADY_REGISTERED)
        
        (map-set players tx-sender {
            username: username,
            wins: u0,
            losses: u0,
            draws: u0,
            total-games: u0,
            rating: STARTING_RATING,
            registered: true
        })
        
        (map-set username-to-address username tx-sender)
        (ok true)
    )
)

(define-read-only (get-player (player principal))
    (ok (map-get? players player))
)

(define-read-only (get-player-by-username (username (string-utf8 32)))
    (let
        (
            (player-addr (map-get? username-to-address username))
        )
        (match player-addr
            addr (ok { address: (some addr), player: (map-get? players addr) })
            (ok { address: none, player: none })
        )
    )
)

;; ============================================
;; Game Functions
;; ============================================

(define-public (create-game (bet-amount uint) (move-index uint) (board-size uint))
    (let
        (
            (game-id (var-get game-id-counter))
            (max-cells (* board-size board-size))
        )
        (asserts! (not (var-get contract-paused)) ERR_PAUSED)
        (asserts! (is-registered tx-sender) ERR_NOT_REGISTERED)
        (asserts! (> bet-amount u0) ERR_INVALID_BET)
        (asserts! (or (is-eq board-size u3) (or (is-eq board-size u5) (is-eq board-size u7))) ERR_INVALID_BOARD_SIZE)
        (asserts! (< move-index max-cells) ERR_INVALID_MOVE)
        
        ;; Handle STX payment
        (try! (stx-transfer? bet-amount tx-sender (as-contract tx-sender)))
        
        ;; Create game
        (map-set games game-id {
            player-one: tx-sender,
            player-two: none,
            bet-amount: bet-amount,
            board-size: board-size,
            is-player-one-turn: false,
            winner: none,
            last-move-block: stacks-block-height,
            status: STATUS_ACTIVE
        })
        
        ;; Set first move
        (map-set game-boards { game-id: game-id, cell-index: move-index } MARK_X)
        
        ;; Increment counter
        (var-set game-id-counter (+ game-id u1))
        
        (ok game-id)
    )
)

(define-public (join-game (game-id uint) (move-index uint))
    (let
        (
            (game (unwrap! (map-get? games game-id) ERR_INVALID_ID))
            (max-cells (* (get board-size game) (get board-size game)))
            (cell-value (default-to MARK_EMPTY (map-get? game-boards { game-id: game-id, cell-index: move-index })))
        )
        (asserts! (not (var-get contract-paused)) ERR_PAUSED)
        (asserts! (is-registered tx-sender) ERR_NOT_REGISTERED)
        (asserts! (is-eq (get status game) STATUS_ACTIVE) ERR_NOT_ACTIVE)
        (asserts! (is-none (get player-two game)) ERR_GAME_STARTED)
        (asserts! (not (is-eq tx-sender (get player-one game))) ERR_SELF_PLAY)
        (asserts! (< move-index max-cells) ERR_INVALID_MOVE)
        (asserts! (is-eq cell-value MARK_EMPTY) ERR_CELL_OCCUPIED)
        
        ;; Handle STX payment
        (try! (stx-transfer? (get bet-amount game) tx-sender (as-contract tx-sender)))
        
        ;; Update game
        (map-set games game-id (merge game {
            player-two: (some tx-sender),
            is-player-one-turn: true,
            last-move-block: stacks-block-height
        }))
        
        ;; Set second move
        (map-set game-boards { game-id: game-id, cell-index: move-index } MARK_O)
        
        (ok true)
    )
)

(define-public (play (game-id uint) (move-index uint))
    (let
        (
            (game (unwrap! (map-get? games game-id) ERR_INVALID_ID))
            (max-cells (* (get board-size game) (get board-size game)))
            (cell-value (default-to MARK_EMPTY (map-get? game-boards { game-id: game-id, cell-index: move-index })))
            (player-two (unwrap! (get player-two game) ERR_NOT_ACTIVE))
        )
        (asserts! (not (var-get contract-paused)) ERR_PAUSED)
        (asserts! (is-eq (get status game) STATUS_ACTIVE) ERR_NOT_ACTIVE)
        (asserts! (< move-index max-cells) ERR_INVALID_MOVE)
        (asserts! (is-eq cell-value MARK_EMPTY) ERR_CELL_OCCUPIED)
        
        ;; Check turn
        (asserts! 
            (if (get is-player-one-turn game)
                (is-eq tx-sender (get player-one game))
                (is-eq tx-sender player-two)
            )
            ERR_NOT_TURN
        )
        
        ;; Set move
        (let
            (
                (mark (if (get is-player-one-turn game) MARK_X MARK_O))
            )
            (map-set game-boards { game-id: game-id, cell-index: move-index } mark)
            
            ;; Update game state
            (map-set games game-id (merge game {
                is-player-one-turn: (not (get is-player-one-turn game)),
                last-move-block: stacks-block-height
            }))
            
            (ok true)
        )
    )
)

;; ============================================
;; Win Detection Helper Functions
;; ============================================

(define-private (get-cell (game-id uint) (cell-index uint))
    (default-to MARK_EMPTY (map-get? game-boards { game-id: game-id, cell-index: cell-index }))
)

(define-private (check-three-in-row (game-id uint) (idx1 uint) (idx2 uint) (idx3 uint))
    (let
        (
            (cell1 (get-cell game-id idx1))
            (cell2 (get-cell game-id idx2))
            (cell3 (get-cell game-id idx3))
        )
        (and 
            (not (is-eq cell1 MARK_EMPTY))
            (is-eq cell1 cell2)
            (is-eq cell2 cell3)
        )
    )
)

(define-private (check-winner-rows (game-id uint) (board-size uint))
    (if (is-eq board-size u3)
        ;; 3x3 board
        (or
            (check-three-in-row game-id u0 u1 u2)
            (or
                (check-three-in-row game-id u3 u4 u5)
                (check-three-in-row game-id u6 u7 u8)
            )
        )
        (if (is-eq board-size u5)
            ;; 5x5 board - check all possible 3-in-a-row combinations
            (or
                ;; Row 0
                (or (check-three-in-row game-id u0 u1 u2) (or (check-three-in-row game-id u1 u2 u3) (check-three-in-row game-id u2 u3 u4)))
                (or
                    ;; Row 1
                    (or (check-three-in-row game-id u5 u6 u7) (or (check-three-in-row game-id u6 u7 u8) (check-three-in-row game-id u7 u8 u9)))
                    (or
                        ;; Row 2
                        (or (check-three-in-row game-id u10 u11 u12) (or (check-three-in-row game-id u11 u12 u13) (check-three-in-row game-id u12 u13 u14)))
                        (or
                            ;; Row 3
                            (or (check-three-in-row game-id u15 u16 u17) (or (check-three-in-row game-id u16 u17 u18) (check-three-in-row game-id u17 u18 u19)))
                            ;; Row 4
                            (or (check-three-in-row game-id u20 u21 u22) (or (check-three-in-row game-id u21 u22 u23) (check-three-in-row game-id u22 u23 u24)))
                        )
                    )
                )
            )
            false
        )
    )
)

(define-private (check-winner-cols (game-id uint) (board-size uint))
    (if (is-eq board-size u3)
        ;; 3x3 board
        (or
            (check-three-in-row game-id u0 u3 u6)
            (or
                (check-three-in-row game-id u1 u4 u7)
                (check-three-in-row game-id u2 u5 u8)
            )
        )
        (if (is-eq board-size u5)
            ;; 5x5 board - check all possible 3-in-a-column combinations
            (or
                ;; Col 0
                (or (check-three-in-row game-id u0 u5 u10) (or (check-three-in-row game-id u5 u10 u15) (check-three-in-row game-id u10 u15 u20)))
                (or
                    ;; Col 1
                    (or (check-three-in-row game-id u1 u6 u11) (or (check-three-in-row game-id u6 u11 u16) (check-three-in-row game-id u11 u16 u21)))
                    (or
                        ;; Col 2
                        (or (check-three-in-row game-id u2 u7 u12) (or (check-three-in-row game-id u7 u12 u17) (check-three-in-row game-id u12 u17 u22)))
                        (or
                            ;; Col 3
                            (or (check-three-in-row game-id u3 u8 u13) (or (check-three-in-row game-id u8 u13 u18) (check-three-in-row game-id u13 u18 u23)))
                            ;; Col 4
                            (or (check-three-in-row game-id u4 u9 u14) (or (check-three-in-row game-id u9 u14 u19) (check-three-in-row game-id u14 u19 u24)))
                        )
                    )
                )
            )
            false
        )
    )
)

(define-private (check-winner-diagonals (game-id uint) (board-size uint))
    (if (is-eq board-size u3)
        ;; 3x3 board
        (or
            (check-three-in-row game-id u0 u4 u8)  ;; Top-left to bottom-right
            (check-three-in-row game-id u2 u4 u6)  ;; Top-right to bottom-left
        )
        (if (is-eq board-size u5)
            ;; 5x5 board - check all possible 3-in-a-diagonal combinations
            (or
                ;; Main diagonals (top-left to bottom-right)
                (or (check-three-in-row game-id u0 u6 u12) (or (check-three-in-row game-id u1 u7 u13) (or (check-three-in-row game-id u5 u11 u17) (or (check-three-in-row game-id u6 u12 u18) (or (check-three-in-row game-id u7 u13 u19) (or (check-three-in-row game-id u10 u16 u22) (or (check-three-in-row game-id u11 u17 u23) (check-three-in-row game-id u12 u18 u24))))))))
                ;; Anti-diagonals (top-right to bottom-left)
                (or (check-three-in-row game-id u2 u6 u10) (or (check-three-in-row game-id u3 u7 u11) (or (check-three-in-row game-id u4 u8 u12) (or (check-three-in-row game-id u8 u12 u16) (or (check-three-in-row game-id u9 u13 u17) (or (check-three-in-row game-id u13 u17 u21) (or (check-three-in-row game-id u14 u18 u22) (check-three-in-row game-id u18 u22 u23))))))))
            )
            false
        )
    )
)

(define-private (check-board-full (game-id uint) (board-size uint))
    (let
        (
            (max-cells (* board-size board-size))
        )
        (if (is-eq board-size u3)
            ;; Check all 9 cells for 3x3
            (and
                (not (is-eq (get-cell game-id u0) MARK_EMPTY))
                (and
                    (not (is-eq (get-cell game-id u1) MARK_EMPTY))
                    (and
                        (not (is-eq (get-cell game-id u2) MARK_EMPTY))
                        (and
                            (not (is-eq (get-cell game-id u3) MARK_EMPTY))
                            (and
                                (not (is-eq (get-cell game-id u4) MARK_EMPTY))
                                (and
                                    (not (is-eq (get-cell game-id u5) MARK_EMPTY))
                                    (and
                                        (not (is-eq (get-cell game-id u6) MARK_EMPTY))
                                        (and
                                            (not (is-eq (get-cell game-id u7) MARK_EMPTY))
                                            (not (is-eq (get-cell game-id u8) MARK_EMPTY))
                                        )
                                    )
                                )
                            )
                        )
                    )
                )
            )
            false
        )
    )
)

(define-private (has-winner (game-id uint) (board-size uint))
    (or
        (check-winner-rows game-id board-size)
        (or
            (check-winner-cols game-id board-size)
            (check-winner-diagonals game-id board-size)
        )
    )
)

;; ============================================
;; Reward and Payout Functions
;; ============================================

(define-private (transfer-payout (recipient principal) (amount uint))
    (as-contract (stx-transfer? amount tx-sender recipient))
)


(define-private (declare-winner (game-id uint) (winner principal))
    (let
        (
            (game (unwrap! (map-get? games game-id) ERR_INVALID_ID))
            (player-two (unwrap! (get player-two game) ERR_NOT_ACTIVE))
            (loser (if (is-eq winner (get player-one game)) player-two (get player-one game)))
            (total-pot (* (get bet-amount game) u2))
            (fee-amount (/ (* total-pot (var-get platform-fee-percent)) BASIS_POINTS))
            (winner-payout (- total-pot fee-amount))
        )
        ;; Update game status
        (map-set games game-id (merge game {
            winner: (some winner),
            status: STATUS_ENDED
        }))
        
        ;; Store claimable reward
        (map-set claimable-rewards game-id winner-payout)
        
        ;; Transfer platform fee if any
        (if (> fee-amount u0)
            (try! (transfer-payout (var-get platform-fee-recipient) fee-amount))
            true
        )
        
        ;; Update player stats
        (try! (update-player-stats-win winner loser))
        
        (ok true)
    )
)


(define-private (handle-draw (game-id uint))
    (let
        (
            (game (unwrap! (map-get? games game-id) ERR_INVALID_ID))
            (refund-amount (get bet-amount game))
            (player-two (unwrap! (get player-two game) ERR_NOT_ACTIVE))
        )
        ;; Update game status
        (map-set games game-id (merge game {
            status: STATUS_ENDED
        }))
        
        ;; Refund both players
        (try! (transfer-payout (get player-one game) refund-amount))
        (try! (transfer-payout player-two refund-amount))
        
        ;; Update player stats for draw
        (try! (update-player-stats-draw (get player-one game) player-two))
        
        (ok true)
    )
)

;; ============================================
;; Player Stats & Rating System
;; ============================================

(define-private (update-player-stats-win (winner principal) (loser principal))
    (let
        (
            (winner-data (unwrap! (map-get? players winner) ERR_NOT_REGISTERED))
            (loser-data (unwrap! (map-get? players loser) ERR_NOT_REGISTERED))
        )
        ;; Update winner stats
        (map-set players winner (merge winner-data {
            wins: (+ (get wins winner-data) u1),
            total-games: (+ (get total-games winner-data) u1),
            rating: (+ (get wins winner-data) u1) ;; Rating = total wins
        }))
        
        ;; Update loser stats
        (map-set players loser (merge loser-data {
            losses: (+ (get losses loser-data) u1),
            total-games: (+ (get total-games loser-data) u1)
        }))
        
        ;; Update leaderboard
        (try! (update-leaderboard winner))
        
        (ok true)
    )
)

(define-private (update-player-stats-draw (player-one principal) (player-two principal))
    (let
        (
            (p1-data (unwrap! (map-get? players player-one) ERR_NOT_REGISTERED))
            (p2-data (unwrap! (map-get? players player-two) ERR_NOT_REGISTERED))
        )
        ;; Update player one stats
        (map-set players player-one (merge p1-data {
            draws: (+ (get draws p1-data) u1),
            total-games: (+ (get total-games p1-data) u1)
        }))
        
        ;; Update player two stats
        (map-set players player-two (merge p2-data {
            draws: (+ (get draws p2-data) u1),
            total-games: (+ (get total-games p2-data) u1)
        }))
        
        (ok true)
    )
)

;; ============================================
;; Leaderboard System
;; ============================================

(define-private (update-leaderboard (player principal))
    (let
        (
            (player-data (unwrap! (map-get? players player) ERR_NOT_REGISTERED))
            (current-size (var-get leaderboard-size))
        )
        ;; Simple leaderboard: just track top players by wins
        ;; For now, we'll add/update entries up to LEADERBOARD_SIZE
        (if (< current-size LEADERBOARD_SIZE)
            (begin
                (map-set leaderboard-entries current-size {
                    player: player,
                    username: (get username player-data),
                    rating: (get rating player-data),
                    wins: (get wins player-data)
                })
                (var-set leaderboard-size (+ current-size u1))
                (ok true)
            )
            ;; If leaderboard is full, update existing entry or replace lowest
            (ok true)
        )
    )
)

(define-read-only (get-leaderboard (limit uint))
    (let
        (
            (size (var-get leaderboard-size))
            (actual-limit (if (< size limit) size limit))
        )
        (ok actual-limit)
    )
)

(define-read-only (get-leaderboard-entry (index uint))
    (ok (map-get? leaderboard-entries index))
)

(define-public (claim-reward (game-id uint))
    (let
        (
            (game (unwrap! (map-get? games game-id) ERR_INVALID_ID))
            (winner (unwrap! (get winner game) ERR_NO_REWARD))
            (reward-amount (unwrap! (map-get? claimable-rewards game-id) ERR_NO_REWARD))
            (already-claimed (default-to false (map-get? reward-claimed game-id)))
        )
        (asserts! (or (is-eq (get status game) STATUS_ENDED) (is-eq (get status game) STATUS_FORFEITED)) ERR_GAME_NOT_FINISHED)
        (asserts! (not already-claimed) ERR_REWARD_CLAIMED)
        (asserts! (is-eq tx-sender winner) ERR_NOT_WINNER)
        
        ;; Mark as claimed
        (map-set reward-claimed game-id true)
        (map-delete claimable-rewards game-id)
        
        ;; Transfer reward
        (try! (transfer-payout winner reward-amount (get token-address game)))
        
        (ok true)
    )
)

(define-public (forfeit-game (game-id uint))
    (let
        (
            (game (unwrap! (map-get? games game-id) ERR_INVALID_ID))
            (player-two (unwrap! (get player-two game) ERR_NOT_ACTIVE))
            (timeout-block (+ (get last-move-block game) (var-get move-timeout)))
        )
        (asserts! (is-eq (get status game) STATUS_ACTIVE) ERR_NOT_ACTIVE)
        (asserts! (>= stacks-block-height timeout-block) ERR_TIMEOUT)
        
        ;; Winner is the player who was NOT supposed to move (last player to move)
        (let
            (
                (winner (if (get is-player-one-turn game) player-two (get player-one game)))
                (total-pot (* (get bet-amount game) u2))
                (fee-amount (/ (* total-pot (var-get platform-fee-percent)) BASIS_POINTS))
                (winner-payout (- total-pot fee-amount))
            )
            ;; Update game status
            (map-set games game-id (merge game {
                winner: (some winner),
                status: STATUS_FORFEITED
            }))
            
            ;; Store claimable reward
            (map-set claimable-rewards game-id winner-payout)
            
            ;; Transfer platform fee if any
            (if (> fee-amount u0)
                (try! (transfer-payout (var-get platform-fee-recipient) fee-amount (get token-address game)))
                true
            )
            
            (ok true)
        )
    )
)

;; ============================================
;; Read-Only View Functions
;; ============================================

(define-read-only (get-game (game-id uint))
    (ok (map-get? games game-id))
)

(define-read-only (get-game-board-cell (game-id uint) (cell-index uint))
    (ok (get-cell game-id cell-index))
)

(define-read-only (get-latest-game-id)
    (ok (var-get game-id-counter))
)

(define-read-only (get-claimable-reward (game-id uint))
    (ok (map-get? claimable-rewards game-id))
)

(define-read-only (is-reward-claimed (game-id uint))
    (ok (default-to false (map-get? reward-claimed game-id)))
)

(define-read-only (get-move-timeout)
    (ok (var-get move-timeout))
)

(define-read-only (get-platform-fee)
    (ok (var-get platform-fee-percent))
)


(define-read-only (is-contract-paused)
    (ok (var-get contract-paused))
)

;; ============================================
;; Challenge System
;; ============================================

(define-public (create-challenge (challenged principal) (bet-amount uint) (board-size uint))
    (let
        (
            (challenge-id (var-get challenge-id-counter))
            (challenger-data (unwrap! (map-get? players tx-sender) ERR_NOT_REGISTERED))
            (challenged-data (unwrap! (map-get? players challenged) ERR_NOT_REGISTERED))
        )
        (asserts! (not (var-get contract-paused)) ERR_PAUSED)
        (asserts! (is-registered tx-sender) ERR_NOT_REGISTERED)
        (asserts! (not (is-eq tx-sender challenged)) ERR_SELF_CHALLENGE)
        (asserts! (is-registered challenged) ERR_NOT_REGISTERED)
        (asserts! (> bet-amount u0) ERR_INVALID_BET)
        (asserts! (or (is-eq board-size u3) (is-eq board-size u5)) ERR_INVALID_BOARD_SIZE)
        
        ;; Handle STX payment
        (try! (stx-transfer? bet-amount tx-sender (as-contract tx-sender)))
        
        ;; Create challenge
        (map-set challenges challenge-id {
            challenger: tx-sender,
            challenger-username: (get username challenger-data),
            challenged: challenged,
            challenged-username: (get username challenged-data),
            bet-amount: bet-amount,
            board-size: board-size,
            created-at-block: stacks-block-height,
            accepted: false,
            game-id: none
        })
        
        ;; Increment counter
        (var-set challenge-id-counter (+ challenge-id u1))
        
        (ok challenge-id)
    )
)

(define-public (accept-challenge (challenge-id uint) (move-index uint))
    (let
        (
            (challenge (unwrap! (map-get? challenges challenge-id) ERR_INVALID_ID))
            (max-cells (* (get board-size challenge) (get board-size challenge)))
            (game-id (var-get game-id-counter))
        )
        (asserts! (not (var-get contract-paused)) ERR_PAUSED)
        (asserts! (is-eq tx-sender (get challenged challenge)) ERR_UNAUTHORIZED)
        (asserts! (not (get accepted challenge)) ERR_CHALLENGE_ACCEPTED)
        (asserts! (< move-index max-cells) ERR_INVALID_MOVE)
        
        ;; Handle STX payment
        (try! (stx-transfer? (get bet-amount challenge) tx-sender (as-contract tx-sender)))
        
        ;; Mark challenge as accepted
        (map-set challenges challenge-id (merge challenge {
            accepted: true,
            game-id: (some game-id)
        }))
        
        ;; Create game from challenge
        (map-set games game-id {
            player-one: (get challenger challenge),
            player-two: (some tx-sender),
            bet-amount: (get bet-amount challenge),
            board-size: (get board-size challenge),
            is-player-one-turn: false,
            winner: none,
            last-move-block: stacks-block-height,
            status: STATUS_ACTIVE
        })
        
        ;; Set challenger's first move
        (map-set game-boards { game-id: game-id, cell-index: move-index } MARK_X)
        
        ;; Increment game counter
        (var-set game-id-counter (+ game-id u1))
        
        (ok game-id)
    )
)

(define-read-only (get-challenge (challenge-id uint))
    (ok (map-get? challenges challenge-id))
)

(define-read-only (get-latest-challenge-id)
    (ok (var-get challenge-id-counter))
)
