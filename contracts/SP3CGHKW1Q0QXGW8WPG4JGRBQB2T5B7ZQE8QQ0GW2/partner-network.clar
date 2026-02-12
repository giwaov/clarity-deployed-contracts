;; Referral System - Track referrals
(define-map referrals {referrer: principal, referred: principal} {active: bool})

(define-public (add-referral (referred principal))
  (begin
    (map-set referrals {referrer: tx-sender, referred: referred} {active: true})
    (ok true)))

(define-read-only (get-referral (referrer principal) (referred principal))
  (map-get? referrals {referrer: referrer, referred: referred}))
