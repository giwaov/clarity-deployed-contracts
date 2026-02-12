;; emergency-withdraw.clar
;; Emergency withdraw system for protocol safety
;; Allows guardians to enable emergency mode and users to withdraw during emergencies

;; ============================================================================
;; Constants
;; ============================================================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-GUARDIAN (err u402))
(define-constant ERR-NOT-IN-EMERGENCY (err u403))
(define-constant ERR-ALREADY-EMERGENCY (err u404))
(define-constant ERR-COOLDOWN-NOT-PASSED (err u405))
(define-constant ERR-INVALID-GUARDIAN (err u406))
(define-constant ERR-MAX-GUARDIANS (err u407))
(define-constant ERR-INSUFFICIENT-VOTES (err u408))
(define-constant ERR-ALREADY-VOTED (err u409))
(define-constant ERR-POSITION-NOT-FOUND (err u410))
(define-constant ERR-ALREADY-WITHDRAWN (err u411))
(define-constant ERR-EMERGENCY-EXPIRED (err u412))

;; Configuration
(define-constant GUARDIAN-THRESHOLD u3)  ;; Votes needed to trigger emergency
(define-constant MAX-GUARDIANS u7)
(define-constant EMERGENCY-DURATION u4320)  ;; ~30 days in blocks
(define-constant COOLDOWN-PERIOD u144)  ;; ~1 day cooldown between emergency triggers

;; ============================================================================
;; Data Variables
;; ============================================================================

(define-data-var emergency-active bool false)
(define-data-var emergency-start-block uint u0)
(define-data-var emergency-end-block uint u0)
(define-data-var last-emergency-end uint u0)
(define-data-var emergency-reason (string-ascii 256) "")
(define-data-var guardian-count uint u0)
(define-data-var current-vote-count uint u0)
(define-data-var emergency-vote-id uint u0)

;; ============================================================================
;; Data Maps
;; ============================================================================

;; Guardian registry
(define-map guardians principal bool)

;; Emergency votes (vote-id -> voter -> voted)
(define-map emergency-votes 
  { vote-id: uint, guardian: principal }
  bool)

;; Track withdrawn positions during emergency
(define-map emergency-withdrawals
  { emergency-id: uint, position-id: uint }
  { withdrawn: bool, amount: uint, timestamp: uint })

;; Guardian actions log
(define-map guardian-actions
  { guardian: principal, action-id: uint }
  { action: (string-ascii 64), timestamp: uint, details: (string-ascii 256) })

(define-data-var action-counter uint u0)

;; ============================================================================
;; Read-Only Functions
;; ============================================================================

(define-read-only (is-emergency-active)
  (and 
    (var-get emergency-active)
    (< stacks-block-height (var-get emergency-end-block))))

(define-read-only (get-emergency-status)
  {
    active: (is-emergency-active),
    start-block: (var-get emergency-start-block),
    end-block: (var-get emergency-end-block),
    reason: (var-get emergency-reason),
    blocks-remaining: (if (is-emergency-active)
                         (- (var-get emergency-end-block) stacks-block-height)
                         u0)
  })

(define-read-only (is-guardian (account principal))
  (default-to false (map-get? guardians account)))

(define-read-only (get-guardian-count)
  (var-get guardian-count))

(define-read-only (get-current-vote-count)
  (var-get current-vote-count))

(define-read-only (has-voted (guardian principal))
  (default-to false (map-get? emergency-votes { vote-id: (var-get emergency-vote-id), guardian: guardian })))

(define-read-only (get-vote-status)
  {
    vote-id: (var-get emergency-vote-id),
    current-votes: (var-get current-vote-count),
    threshold: GUARDIAN-THRESHOLD,
    votes-needed: (if (>= (var-get current-vote-count) GUARDIAN-THRESHOLD)
                     u0
                     (- GUARDIAN-THRESHOLD (var-get current-vote-count)))
  })

(define-read-only (was-position-withdrawn (emergency-id uint) (position-id uint))
  (match (map-get? emergency-withdrawals { emergency-id: emergency-id, position-id: position-id })
    withdrawal (get withdrawn withdrawal)
    false))

(define-read-only (can-trigger-emergency)
  (and
    (not (var-get emergency-active))
    (> stacks-block-height (+ (var-get last-emergency-end) COOLDOWN-PERIOD))))

;; ============================================================================
;; Guardian Management (Owner Only)
;; ============================================================================

(define-public (add-guardian (new-guardian principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-guardian new-guardian)) ERR-INVALID-GUARDIAN)
    (asserts! (< (var-get guardian-count) MAX-GUARDIANS) ERR-MAX-GUARDIANS)
    
    (map-set guardians new-guardian true)
    (var-set guardian-count (+ (var-get guardian-count) u1))
    
    (log-guardian-action new-guardian "added" "Guardian added by contract owner")
    
    (ok (var-get guardian-count))))

(define-public (remove-guardian (guardian principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-guardian guardian) ERR-INVALID-GUARDIAN)
    
    (map-delete guardians guardian)
    (var-set guardian-count (- (var-get guardian-count) u1))
    
    (log-guardian-action guardian "removed" "Guardian removed by contract owner")
    
    (ok (var-get guardian-count))))

;; ============================================================================
;; Emergency Voting Functions
;; ============================================================================

;; Guardians vote to trigger emergency
(define-public (vote-emergency (reason (string-ascii 256)))
  (let
    (
      (vote-id (var-get emergency-vote-id))
    )
    (asserts! (is-guardian tx-sender) ERR-NOT-GUARDIAN)
    (asserts! (can-trigger-emergency) ERR-COOLDOWN-NOT-PASSED)
    (asserts! (not (has-voted tx-sender)) ERR-ALREADY-VOTED)
    
    ;; Record vote
    (map-set emergency-votes 
      { vote-id: vote-id, guardian: tx-sender }
      true)
    (var-set current-vote-count (+ (var-get current-vote-count) u1))
    
    ;; Update reason (last voter's reason is used)
    (var-set emergency-reason reason)
    
    (log-guardian-action tx-sender "voted-emergency" reason)
    
    ;; Check if threshold reached
    (if (>= (var-get current-vote-count) GUARDIAN-THRESHOLD)
      (activate-emergency reason)
      (ok { 
        votes: (var-get current-vote-count), 
        threshold: GUARDIAN-THRESHOLD,
        activated: false 
      }))))

;; Internal: Activate emergency mode
(define-private (activate-emergency (reason (string-ascii 256)))
  (begin
    (var-set emergency-active true)
    (var-set emergency-start-block stacks-block-height)
    (var-set emergency-end-block (+ stacks-block-height EMERGENCY-DURATION))
    (var-set emergency-reason reason)
    
    ;; Reset vote count and increment vote-id for next emergency
    (var-set current-vote-count u0)
    (var-set emergency-vote-id (+ (var-get emergency-vote-id) u1))
    
    (print {
      event: "emergency-activated",
      start-block: stacks-block-height,
      end-block: (+ stacks-block-height EMERGENCY-DURATION),
      reason: reason
    })
    
    (ok { 
      votes: GUARDIAN-THRESHOLD, 
      threshold: GUARDIAN-THRESHOLD,
      activated: true 
    })))

;; Cancel ongoing vote (owner only)
(define-public (cancel-emergency-vote)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get emergency-active)) ERR-ALREADY-EMERGENCY)
    
    (var-set current-vote-count u0)
    (var-set emergency-vote-id (+ (var-get emergency-vote-id) u1))
    
    (ok true)))

;; ============================================================================
;; Emergency Mode Functions
;; ============================================================================

;; End emergency early (requires owner + majority guardians)
(define-public (end-emergency-early)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-emergency-active) ERR-NOT-IN-EMERGENCY)
    
    (var-set emergency-active false)
    (var-set last-emergency-end stacks-block-height)
    
    (print {
      event: "emergency-ended-early",
      end-block: stacks-block-height,
      original-end: (var-get emergency-end-block)
    })
    
    (ok true)))

;; Extend emergency (owner only, during active emergency)
(define-public (extend-emergency (additional-blocks uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-emergency-active) ERR-NOT-IN-EMERGENCY)
    (asserts! (<= additional-blocks EMERGENCY-DURATION) ERR-NOT-AUTHORIZED)  ;; Max extension
    
    (var-set emergency-end-block (+ (var-get emergency-end-block) additional-blocks))
    
    (print {
      event: "emergency-extended",
      new-end-block: (var-get emergency-end-block),
      extension: additional-blocks
    })
    
    (ok (var-get emergency-end-block))))

;; ============================================================================
;; Emergency Withdrawal Functions
;; ============================================================================

;; Emergency withdraw - bypasses normal timelock
;; Users can withdraw their locked tokens during emergency
;; Note: This would call the main timelock-exchange contract
(define-public (emergency-withdraw (position-id uint))
  (let
    (
      (emergency-id (var-get emergency-vote-id))
    )
    (asserts! (is-emergency-active) ERR-NOT-IN-EMERGENCY)
    (asserts! (not (was-position-withdrawn emergency-id position-id)) ERR-ALREADY-WITHDRAWN)
    
    ;; Mark as withdrawn
    (map-set emergency-withdrawals
      { emergency-id: emergency-id, position-id: position-id }
      { withdrawn: true, amount: u0, timestamp: stacks-block-height })
    
    (print {
      event: "emergency-withdrawal",
      position-id: position-id,
      user: tx-sender,
      block: stacks-block-height
    })
    
    ;; In production, this would call:
    ;; (contract-call? .timelock-exchange emergency-release position-id)
    (ok position-id)))

;; Batch emergency withdraw for multiple positions
(define-public (batch-emergency-withdraw (position-ids (list 10 uint)))
  (begin
    (asserts! (is-emergency-active) ERR-NOT-IN-EMERGENCY)
    (ok (map emergency-withdraw-single position-ids))))

(define-private (emergency-withdraw-single (position-id uint))
  (let
    (
      (emergency-id (var-get emergency-vote-id))
    )
    (if (was-position-withdrawn emergency-id position-id)
      false
      (begin
        (map-set emergency-withdrawals
          { emergency-id: emergency-id, position-id: position-id }
          { withdrawn: true, amount: u0, timestamp: stacks-block-height })
        true))))

;; ============================================================================
;; Logging Functions
;; ============================================================================

(define-private (log-guardian-action (guardian principal) (action (string-ascii 64)) (details (string-ascii 256)))
  (let
    (
      (action-id (var-get action-counter))
    )
    (map-set guardian-actions
      { guardian: guardian, action-id: action-id }
      { action: action, timestamp: stacks-block-height, details: details })
    (var-set action-counter (+ action-id u1))
    action-id))

;; ============================================================================
;; Recovery Functions (Post-Emergency)
;; ============================================================================

;; Check and auto-end expired emergency
(define-public (check-emergency-expiry)
  (begin
    (if (and 
          (var-get emergency-active)
          (>= stacks-block-height (var-get emergency-end-block)))
      (begin
        (var-set emergency-active false)
        (var-set last-emergency-end stacks-block-height)
        (print { event: "emergency-expired", end-block: stacks-block-height })
        (ok true))
      (ok false))))

;; Get emergency history for audit
(define-read-only (get-emergency-history)
  {
    total-emergencies: (var-get emergency-vote-id),
    last-end-block: (var-get last-emergency-end),
    current-state: (get-emergency-status)
  })
