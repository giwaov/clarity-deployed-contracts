;; Referral Program
(define-map referrals {referrer: principal, referred: principal} {reward-earned: uint, signup-date: uint, converted: bool})
(define-public (add-referral (referred principal) (reward-earned uint) (signup-date uint) (converted bool))
  (begin (map-set referrals {referrer: tx-sender, referred: referred} {reward-earned: reward-earned, signup-date: signup-date, converted: converted}) (ok true)))
(define-read-only (get-referral (referrer principal) (referred principal))
  (map-get? referrals {referrer: referrer, referred: referred}))
