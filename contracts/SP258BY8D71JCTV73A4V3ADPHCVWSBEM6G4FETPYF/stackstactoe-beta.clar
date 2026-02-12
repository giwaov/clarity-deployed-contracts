;; StacksTacToe - Decentralized PvP Tic-Tac-Toe Game
;; A winner-takes-all betting game on Stacks blockchain
;; Supports STX only

;; ============================================
;; Constants
;; ============================================

;; Contract owner
(define-constant CONTRACT_OWNER tx-sender)

;; Game parameters
(define-constant DEFAULT_MOVE_TIMEOUT u144) ;; ~24 hours in blocks (assuming 10 min blocks)
(define-constant MAX_TIMEOUT u1008) ;; ~7 days in blocks
(define-constant DEFAULT_BOARD_SIZE u3)

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
(define-constant ERR_NOT_ADMIN (err u116))
(define-constant ERR_INVALID_TIMEOUT (err u117))
(define-constant ERR_INVALID_FEE (err u118))
(define-constant ERR_NO_REWARD (err u123))
(define-constant ERR_REWARD_CLAIMED (err u124))
(define-constant ERR_NOT_WINNER (err u125))
(define-constant ERR_INVALID_BOARD_SIZE (err u126))
(define-constant ERR_GAME_NOT_FINISHED (err u127))
(define-constant ERR_PAUSED (err u129))

;; ============================================
;; Data Variables
;; ============================================

;; Admin and configuration
(define-data-var contract-paused bool false)
(define-data-var move-timeout uint DEFAULT_MOVE_TIMEOUT)
(define-data-var platform-fee-percent uint u0) ;; Default: no fee
(define-data-var platform-fee-recipient principal CONTRACT_OWNER)

;; Counters
(define-data-var game-id-counter uint u0)

;; ============================================
;; Data Maps
;; ============================================

;; Admin management
(define-map admins principal bool)

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

;; ============================================
;; Initialization
;; ============================================

;; Set contract owner as admin
(map-set admins CONTRACT_OWNER true)

;; ============================================
;; Private Helper Functions
;; ============================================

(define-private (is-admin (caller principal))
    (or 
        (is-eq caller CONTRACT_OWNER)
        (default-to false (map-get? admins caller))
    )
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
;; Game Functions
;; ============================================

(define-public (create-game (bet-amount uint) (move-index uint) (board-size uint))
    (let
        (
            (game-id (var-get game-id-counter))
            (max-cells (* board-size board-size))
        )
        (asserts! (not (var-get contract-paused)) ERR_PAUSED)
        (asserts! (> bet-amount u0) ERR_INVALID_BET)
        (asserts! (or (is-eq board-size u3) (is-eq board-size u5)) ERR_INVALID_BOARD_SIZE)
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
        
        (ok true)
    )
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
        (try! (transfer-payout winner reward-amount))
        
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
                (try! (transfer-payout (var-get platform-fee-recipient) fee-amount))
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