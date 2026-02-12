;; WAGER CONTRACT
;; 1v1 betting system - winner takes all

;; ============================================================================
;; CONSTANTS
;; ============================================================================

(define-constant ERR_NOT_AUTHORIZED (err u900))
(define-constant ERR_NOT_FOUND (err u901))
(define-constant ERR_WAGER_EXPIRED (err u902))
(define-constant ERR_WAGER_NOT_ACTIVE (err u903))
(define-constant ERR_ALREADY_ACCEPTED (err u904))

(define-constant WAGER_EXPIRY_BLOCKS u1440) ;; ~10 days

;; ============================================================================
;; DATA VARS
;; ============================================================================

(define-data-var wager-id-nonce uint u0)

;; ============================================================================
;; DATA MAPS
;; ============================================================================

(define-map wagers
  { wager-id: uint }
  {
    challenger: principal,
    opponent: principal,
    difficulty: uint,
    stake: uint,
    status: (string-ascii 20), ;; "pending", "active", "finished", "cancelled"
    board-seed: (optional (buff 32)),
    
    challenger-game-id: (optional uint),
    opponent-game-id: (optional uint),
    
    challenger-time: (optional uint),
    opponent-time: (optional uint),
    challenger-score: (optional uint),
    opponent-score: (optional uint),
    
    winner: (optional principal),
    created-at: uint,
    expires-at: uint,
    finished-at: (optional uint)
  }
)

;; ============================================================================
;; WAGER CREATION
;; ============================================================================

(define-public (create-wager 
  (opponent principal)
  (difficulty uint)
  (stake uint))
  (let
    (
      (wager-id (+ (var-get wager-id-nonce) u1))
    )
    ;; Lock challenger stake in economy
    (unwrap! (contract-call? .economy-02 lock-funds wager-id stake) ERR_NOT_AUTHORIZED)
    
    ;; Create wager
    (map-set wagers
      {wager-id: wager-id}
      {
        challenger: tx-sender,
        opponent: opponent,
        difficulty: difficulty,
        stake: stake,
        status: "pending",
        board-seed: none,
        challenger-game-id: none,
        opponent-game-id: none,
        challenger-time: none,
        opponent-time: none,
        challenger-score: none,
        opponent-score: none,
        winner: none,
        created-at: stacks-block-height,
        expires-at: (+ stacks-block-height WAGER_EXPIRY_BLOCKS),
        finished-at: none
      }
    )
    
    (var-set wager-id-nonce wager-id)
    (print {event: "create-wager", wager-id: wager-id, challenger: tx-sender, opponent: opponent, difficulty: difficulty, stake: stake})
    (ok wager-id)
  )
)

;; ============================================================================
;; WAGER ACCEPTANCE
;; ============================================================================

(define-public (accept-wager (wager-id uint))
  (let
    (
      (wager (unwrap! (map-get? wagers {wager-id: wager-id}) ERR_NOT_FOUND))
      (stake (get stake wager))
    )
    ;; Validate
    (asserts! (is-eq tx-sender (get opponent wager)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status wager) "pending") ERR_ALREADY_ACCEPTED)
    (asserts! (< stacks-block-height (get expires-at wager)) ERR_WAGER_EXPIRED)
    
    ;; Lock opponent stake in economy
    (unwrap! (contract-call? .economy-02 lock-funds wager-id stake) ERR_NOT_AUTHORIZED)
    
    ;; Generate shared board seed
    (let
      (
        (seed (sha256 (concat 
          (unwrap-panic (to-consensus-buff? wager-id))
          (unwrap-panic (to-consensus-buff? stacks-block-height))
        )))
      )
      ;; Update wager
      (map-set wagers
        {wager-id: wager-id}
        (merge wager {
          status: "active",
          board-seed: (some seed)
        })
      )
      (print {event: "accept-wager", wager-id: wager-id, opponent: tx-sender, seed: seed})
      (ok seed)
    )
  )
)

;; ============================================================================
;; WAGER EXECUTION
;; ============================================================================

(define-public (submit-wager-result (wager-id uint) (game-id uint))
  (let
    (
      (wager (unwrap! (map-get? wagers {wager-id: wager-id}) ERR_NOT_FOUND))
      ;; Get game information
      (game (unwrap! (contract-call? .game-core-02 get-game-info game-id) ERR_NOT_FOUND))
      (is-challenger (is-eq tx-sender (get challenger wager)))
      (is-opponent (is-eq tx-sender (get opponent wager)))
    )
    ;; Validate
    (asserts! (is-eq (get status wager) "active") ERR_WAGER_NOT_ACTIVE)
    (asserts! (or is-challenger is-opponent) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get player game) tx-sender) ERR_NOT_AUTHORIZED)
    
    ;; Update wager with result
    (if is-challenger
      (map-set wagers
        {wager-id: wager-id}
        (merge wager {
          challenger-game-id: (some game-id),
          challenger-time: (get final-time game),
          challenger-score: (get final-score game)
        })
      )
      (map-set wagers
        {wager-id: wager-id}
        (merge wager {
          opponent-game-id: (some game-id),
          opponent-time: (get final-time game),
          opponent-score: (get final-score game)
        })
      )
    )
    
    ;; Check if both completed
    (let
      (
        (updated-wager (unwrap-panic (map-get? wagers {wager-id: wager-id})))
      )
      (if (and 
        (is-some (get challenger-time updated-wager))
        (is-some (get opponent-time updated-wager)))
        ;; Both completed - determine winner
        (begin
          (unwrap-panic (determine-wager-winner wager-id))
          (print {event: "submit-wager-result", wager-id: wager-id, player: tx-sender, game-id: game-id})
          (ok true)
        )
        (begin
          (print {event: "submit-wager-result", wager-id: wager-id, player: tx-sender, game-id: game-id})
          (ok true)
        )
      )
    )
  )
)

;; Determine winner and distribute prize
(define-private (determine-wager-winner (wager-id uint))
  (let
    (
      (wager (unwrap-panic (map-get? wagers {wager-id: wager-id})))
      (challenger-time (unwrap-panic (get challenger-time wager)))
      (opponent-time (unwrap-panic (get opponent-time wager)))
      (winner (if (< challenger-time opponent-time)
        (get challenger wager)
        (get opponent wager)
      ))
      (total-pot (* (get stake wager) u2))
    )
    ;; Update wager
    (map-set wagers
      {wager-id: wager-id}
      (merge wager {
        status: "finished",
        winner: (some winner),
        finished-at: (some stacks-block-height)
      })
    )
    
    ;; Distribute prize to winner via economy
    (unwrap! (contract-call? .economy-02 release-funds wager-id winner total-pot) ERR_NOT_AUTHORIZED)
    
    ;; Award achievement for high stakes
    (and (> (get stake wager) u100)
         (is-ok (contract-call? .achievement-nft-02 award-achievement winner u14)))
    
    (ok winner)
  )
)

;; ============================================================================
;; WAGER CANCELLATION
;; ============================================================================

(define-public (cancel-wager (wager-id uint))
  (let
    (
      (wager (unwrap! (map-get? wagers {wager-id: wager-id}) ERR_NOT_FOUND))
    )
    ;; Validate
    (asserts! (is-eq tx-sender (get challenger wager)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status wager) "pending") ERR_NOT_AUTHORIZED)
    
    ;; Refund stake via economy
    (unwrap! (contract-call? .economy-02 refund-funds wager-id) ERR_NOT_AUTHORIZED)
    
    ;; Update status
    (map-set wagers
      {wager-id: wager-id}
      (merge wager {status: "cancelled"})
    )
    
    (print {event: "cancel-wager", wager-id: wager-id, challenger: tx-sender})
    (ok true)
  )
)

;; ============================================================================
;; READ-ONLY FUNCTIONS
;; ============================================================================

(define-read-only (get-wager-info (wager-id uint))
  (ok (map-get? wagers {wager-id: wager-id}))
)

(define-read-only (get-active-wagers (player principal))
  ;; In production, would return list of active wagers
  (ok (list))
)
