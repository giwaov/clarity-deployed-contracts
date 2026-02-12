---
title: "Trait voting-strategy-trait"
draft: true
---
```
;; ============================================
;; VOTING STRATEGY TRAIT
;; ============================================
;; Defines the interface for pluggable voting strategies
;; DAOs can implement custom voting power calculations

(define-trait voting-strategy-trait
  (
    ;; Get voting power for a voter at a specific snapshot block
    ;; Returns the voting weight (0 if not eligible)
    (get-voting-power (principal uint) (response uint uint))
    
    ;; Get the strategy name for display purposes
    (get-strategy-name () (response (string-ascii 64) uint))
  )
)

```
