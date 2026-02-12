(impl-trait .sm-dao-traits.proposal-script)

(define-public (execute)
  (begin
    (try! (contract-call? .sm-egroup update u18 {
      MASK: u18446744073709552128,
      BORROW-DISABLED-MASK: u0,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u5000,
      LTV-LIQ-PARTIAL: u6000,
      LTV-LIQ-FULL: u7000
    }))

    (try! (contract-call? .sm-egroup update u19 {
      MASK: u4722366482869645213704,
      BORROW-DISABLED-MASK: u0,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u8500,
      LTV-LIQ-PARTIAL: u8600,
      LTV-LIQ-FULL: u8900
    }))
    (ok true)))
