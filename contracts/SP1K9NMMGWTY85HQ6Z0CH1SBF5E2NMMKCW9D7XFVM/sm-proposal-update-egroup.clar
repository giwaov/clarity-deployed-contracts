;; Proposal: Lower Test Egroup LTV for Liquidation Testing
;;
;; Lowers the LTV thresholds of the test egroup to trigger liquidation
;; on positions that were healthy under the original parameters.
;;
;; Original:
;;   LTV-BORROW: 7000 (70%)
;;   LTV-LIQ-PARTIAL: 8500 (85%)
;;   LTV-LIQ-FULL: 9000 (90%)
;;
;; New:
;;   LTV-BORROW: 5000 (50%)
;;   LTV-LIQ-PARTIAL: 6000 (60%)
;;   LTV-LIQ-FULL: 7000 (70%)
;;
;; Effect: A position at 65% LTV becomes liquidatable (65% > 60%)
;;
;; Assumes test egroup ID is 17 (0-indexed)

(impl-trait .sm-dao-traits.proposal-script)

(define-public (execute)
  (begin
    (try! (contract-call? .sm-egroup update u17 {
      MASK: u1180591620717411303936,
      BORROW-DISABLED-MASK: u0,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u5000,
      LTV-LIQ-PARTIAL: u6000,
      LTV-LIQ-FULL: u7000
    }))
    (ok true)))
