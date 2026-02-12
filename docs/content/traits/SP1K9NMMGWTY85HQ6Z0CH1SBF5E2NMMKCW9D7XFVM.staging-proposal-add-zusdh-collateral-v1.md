---
title: "Trait staging-proposal-add-zusdh-collateral-v1"
draft: true
---
```
;; Proposal: Add zUSDH Collateral-Only Group (v1 - Fixed Parameters)
;; 
;; This proposal adds a new egroup for zUSDH (vault token) as collateral only.
;; Borrowing is effectively disabled (0.01% LTV = negligible).
;;
;; V1 Fix: Updated parameters to satisfy strict inequality validation:
;;   - All parameters must be strictly increasing
;;   - Cannot use all zeros
;;
;; Asset IDs:
;; - zUSDh: 9
;;
;; MASK Encoding:
;; - Bits 0-63: Collateral assets (bit position = asset ID)
;; - Bits 64-127: Debt assets (bit position = asset ID + 64)
;;
;; For this group:
;; - Collateral: zUSDH (bit 9) = 2^9 = 512
;; - Debt: None
;; - MASK = u512

(impl-trait .staging-dao-traits-v0.proposal-script)

(define-public (execute)
  (begin
    ;; -------------------------------------------------------------------------
    ;; zUSDH Collateral-Only Group
    ;; No debt assets - collateral only
    ;; MASK = 2^9 = 512
    ;; Minimal but valid parameters (effectively disables borrowing)
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u512,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u1,          ;; 0.01% (minimal)
      LIQ-PENALTY-MAX: u2,          ;; 0.02% (minimal)
      LTV-BORROW: u1,               ;; 0.01% (effectively disabled)
      LTV-LIQ-PARTIAL: u2,          ;; 0.02%
      LTV-LIQ-FULL: u3              ;; 0.03%
    }))
    
    (ok true)))

```
