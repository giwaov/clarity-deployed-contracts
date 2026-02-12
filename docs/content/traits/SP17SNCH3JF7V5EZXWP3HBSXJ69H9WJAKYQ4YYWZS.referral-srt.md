---
title: "Trait referral-srt"
draft: true
---
```
;; Referral program contract
(define-map referrals principal principal)
(define-map referral-counts principal uint)
(define-data-var referral-reward uint u10)

(define-read-only (get-referrer (user principal))
  (map-get? referrals user)
)

(define-read-only (get-referral-count (user principal))
  (default-to u0 (map-get? referral-counts user))
)

(define-public (join-with-referral (referrer principal))
  (begin
    (asserts! (is-none (map-get? referrals tx-sender)) (err u1))
    (asserts! (not (is-eq tx-sender referrer)) (err u2))
    (map-set referrals tx-sender referrer)
    (let ((current (get-referral-count referrer)))
      (map-set referral-counts referrer (+ current u1))
    )
    (ok true)
  )
)

(define-read-only (calculate-reward (user principal))
  (* (get-referral-count user) (var-get referral-reward))
)

```
