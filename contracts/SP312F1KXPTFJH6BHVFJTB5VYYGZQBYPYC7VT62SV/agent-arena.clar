;; Agent Arena - On-chain agent registration for AI competitions
;; Agents call `register` to join the arena
;; 
;; Future: rounds, betting, eliminations, prize pools

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_ALREADY_REGISTERED (err u100))
(define-constant ERR_NOT_REGISTERED (err u101))
(define-constant ERR_ARENA_FULL (err u102))
(define-constant ERR_INVALID_NAME (err u103))
(define-constant MAX_AGENTS u8)

;; Data vars
(define-data-var agent-count uint u0)
(define-data-var arena-open bool true)
(define-data-var current-round uint u0)

;; Data maps
(define-map agents 
  principal 
  {
    name: (string-utf8 50),
    agent-type: (string-utf8 30),
    registered-at: uint,
    is-active: bool
  }
)

(define-map agent-by-index uint principal)

;; Read-only functions

(define-read-only (get-agent-count)
  (ok (var-get agent-count))
)

(define-read-only (get-agent (who principal))
  (ok (map-get? agents who))
)

(define-read-only (get-agent-by-index (index uint))
  (ok (map-get? agent-by-index index))
)

(define-read-only (is-registered (who principal))
  (is-some (map-get? agents who))
)

(define-read-only (is-arena-open)
  (ok (var-get arena-open))
)

(define-read-only (get-current-round)
  (ok (var-get current-round))
)

(define-read-only (get-all-agents)
  (ok {
    count: (var-get agent-count),
    is-open: (var-get arena-open),
    round: (var-get current-round)
  })
)

;; Public functions

;; Register as an agent in the arena
(define-public (register (name (string-utf8 50)) (agent-type (string-utf8 30)))
  (let
    (
      (caller tx-sender)
      (current-count (var-get agent-count))
    )
    ;; Check arena is open
    (asserts! (var-get arena-open) ERR_ARENA_FULL)
    ;; Check not already registered
    (asserts! (not (is-registered caller)) ERR_ALREADY_REGISTERED)
    ;; Check arena not full
    (asserts! (< current-count MAX_AGENTS) ERR_ARENA_FULL)
    ;; Check name is not empty
    (asserts! (> (len name) u0) ERR_INVALID_NAME)
    
    ;; Register the agent
    (map-set agents caller {
      name: name,
      agent-type: agent-type,
      registered-at: stacks-block-height,
      is-active: true
    })
    
    ;; Track by index for enumeration
    (map-set agent-by-index current-count caller)
    
    ;; Increment count
    (var-set agent-count (+ current-count u1))
    
    ;; Auto-close if full
    (if (is-eq (+ current-count u1) MAX_AGENTS)
      (var-set arena-open false)
      true
    )
    
    (ok {
      index: current-count,
      total: (+ current-count u1)
    })
  )
)

;; Unregister from the arena (only before game starts)
(define-public (unregister)
  (let
    (
      (caller tx-sender)
      (agent-data (unwrap! (map-get? agents caller) ERR_NOT_REGISTERED))
    )
    ;; Can only unregister if round is 0 (game hasn't started)
    (asserts! (is-eq (var-get current-round) u0) (err u104))
    
    ;; Mark as inactive (don't actually remove to preserve indices)
    (map-set agents caller (merge agent-data { is-active: false }))
    
    (ok true)
  )
)

;; Admin: Reset the arena for a new game
(define-public (reset-arena)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err u403))
    (var-set agent-count u0)
    (var-set arena-open true)
    (var-set current-round u0)
    (ok true)
  )
)

;; Admin: Close registration manually
(define-public (close-registration)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err u403))
    (var-set arena-open false)
    (ok true)
  )
)

;; Admin: Start the next round
(define-public (start-round)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err u403))
    (var-set arena-open false)
    (var-set current-round (+ (var-get current-round) u1))
    (ok (var-get current-round))
  )
)
