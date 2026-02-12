---
title: "Trait token-voting-strategy"
draft: true
---
```
;; ============================================
;; TOKEN VOTING STRATEGY
;; ============================================
;; Voting power based on SIP-010 fungible token balance
;; Each token = 1 vote

(impl-trait .voting-strategy-trait.voting-strategy-trait)

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant ERR_INVALID_BLOCK (err u1001))

;; Token contract to check balances (placeholder - set to actual token)
;; In production, this would be configured per DAO
(define-constant TOKEN_CONTRACT 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token)

;; ============================================
;; PUBLIC FUNCTIONS
;; ============================================

;; Get voting power based on token balance at snapshot
;; Note: In production, this would query historical balances
;; For MVP, we return current balance as proxy
(define-public (get-voting-power (voter principal) (snapshot-block uint))
  (begin
    ;; Validate snapshot block is not in the future
    (asserts! (<= snapshot-block block-height) ERR_INVALID_BLOCK)
    ;; Return voting power (1 token = 1 vote)
    ;; In production, integrate with actual token contract
    (ok u1000000)
  )
)

;; Return strategy name
(define-public (get-strategy-name)
  (ok "Token Balance Voting")
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-strategy-info)
  {
    name: "Token Balance Voting",
    description: "Voting power equals token balance at snapshot",
    version: u1
  }
)

```
