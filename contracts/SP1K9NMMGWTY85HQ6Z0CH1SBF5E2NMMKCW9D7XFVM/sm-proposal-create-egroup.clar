;; Proposal: Create Test Egroup for Production Testing
;;
;; Creates a test egroup with zUSDH collateral + USDC debt.
;;
;; MASK calculation:
;; - zUSDH collateral: bit 9 = 2^9 = 512
;; - USDC debt: bit 70 = 2^70 = 1180591620717411303424
;; - MASK = 1180591620717411303936
;;
;; After execution, egroup ID will be 17 (0-indexed, 18th egroup)

(impl-trait .sm-dao-traits.proposal-script)

(define-public (execute)
  (begin
    (try! (contract-call? .sm-egroup insert {
      MASK: u1180591620717411303936,
      BORROW-DISABLED-MASK: u0,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u7000,
      LTV-LIQ-PARTIAL: u8500,
      LTV-LIQ-FULL: u9000
    }))
    (ok true)))
