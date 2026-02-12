---
title: "Trait sm-proposal-create-egroup18"
draft: true
---
```
;; Proposal: Create Test Egroup for Production Testing
;;
;; Creates a test egroup with zUSDH collateral + USDC debt.
;;
;; MASK calculation:
;; - zUSDH collateral: bit 9 = 2^9 = 512
;; - STX debt: wstx=2^64 = 18446744073709551616
;; - MASK = 18446744073709552128
;;
;; After execution, egroup ID will be 18 (0-indexed, 19th egroup)

(impl-trait .sm-dao-traits.proposal-script)

(define-public (execute)
  (begin
    (try! (contract-call? .sm-egroup insert {
      MASK: u18446744073709552128,
      BORROW-DISABLED-MASK: u0,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u7000,
      LTV-LIQ-PARTIAL: u8500,
      LTV-LIQ-FULL: u9000
    }))
    (ok true)))

```
