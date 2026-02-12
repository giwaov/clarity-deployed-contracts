;; Proposal: Create Test Egroup for Production Testing
;;
;; Creates a test egroup with zsBTC collateral + USDh debt.
;;
;; MASK calculation:
;; - zsBTC collateral: bit 3 = 2^3 = 8
;; - USDh debt: bit 72 = 2^72 = 4722366482869645213696
;; - MASK = 4722366482869645213704 
;;
;; After execution, egroup ID will be 19 (0-indexed, 19th egroup)

(impl-trait .sm-dao-traits.proposal-script)

(define-public (execute)
  (begin
    (try! (contract-call? .sm-egroup insert {
      MASK: u4722366482869645213704,
      BORROW-DISABLED-MASK: u0,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u9000,
      LTV-LIQ-PARTIAL: u9500,
      LTV-LIQ-FULL: u9800
    }))
    (ok true)))
