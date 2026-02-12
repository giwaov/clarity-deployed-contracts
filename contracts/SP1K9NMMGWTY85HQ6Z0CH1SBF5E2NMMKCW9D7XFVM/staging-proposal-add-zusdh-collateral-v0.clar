;; Proposal: Add zUSDH Collateral-Only Group
;; 
;; This proposal adds a new egroup for zUSDH (vault token) as collateral only.
;; No borrowing is enabled (all LTVs set to 0).
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
    ;; All LTVs and penalties set to 0 (no borrowing enabled)
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u512,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u0,
      LIQ-PENALTY-MAX: u0,
      LTV-BORROW: u0,
      LTV-LIQ-PARTIAL: u0,
      LTV-LIQ-FULL: u0
    }))
    
    (ok true)))
