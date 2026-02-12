;; ============================================
;; ONE WALLET ONE VOTE STRATEGY
;; ============================================
;; Simple democratic voting: each wallet gets exactly 1 vote
;; Great for community DAOs focused on participation

(impl-trait .voting-strategy-trait.voting-strategy-trait)

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant ERR_INVALID_BLOCK (err u1001))
(define-constant VOTE_WEIGHT u1)

;; ============================================
;; PUBLIC FUNCTIONS
;; ============================================

;; Every valid wallet gets exactly 1 vote
(define-public (get-voting-power (voter principal) (snapshot-block uint))
  (begin
    ;; Validate snapshot block is not in the future
    (asserts! (<= snapshot-block block-height) ERR_INVALID_BLOCK)
    ;; Everyone gets 1 vote
    (ok VOTE_WEIGHT)
  )
)

;; Return strategy name
(define-public (get-strategy-name)
  (ok "One Wallet One Vote")
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-strategy-info)
  {
    name: "One Wallet One Vote",
    description: "Each wallet receives exactly one vote regardless of holdings",
    version: u1
  }
)
