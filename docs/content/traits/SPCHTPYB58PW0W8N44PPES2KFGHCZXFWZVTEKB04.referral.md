---
title: "Trait referral"
draft: true
---
```
;; Referral System Contract
;; Track and reward referrals

(define-constant err-self-referral (err u100))
(define-constant err-already-referred (err u101))

(define-data-var referral-reward uint u1000000)

(define-map referrals
    principal
    {
        referrer: (optional principal),
        referral-count: uint,
        total-earned: uint,
        registration-block: uint
    }
)

(define-map referral-codes (string-ascii 20) principal)

(define-public (register-with-referral (referrer-code (optional (string-ascii 20))))
    (begin
        (asserts! (is-none (map-get? referrals tx-sender)) err-already-referred)

        (match referrer-code
            code
            (match (map-get? referral-codes code)
                referrer
                (begin
                    (asserts! (not (is-eq tx-sender referrer)) err-self-referral)
                    (map-set referrals tx-sender {
                        referrer: (some referrer),
                        referral-count: u0,
                        total-earned: u0,
                        registration-block: block-height
                    })
                    (try! (reward-referrer referrer))
                    (ok (some referrer))
                )
                (ok none)
            )
            (begin
                (map-set referrals tx-sender {
                    referrer: none,
                    referral-count: u0,
                    total-earned: u0,
                    registration-block: block-height
                })
                (ok none)
            )
        )
    )
)

(define-public (create-referral-code (code (string-ascii 20)))
    (begin
        (asserts! (is-none (map-get? referral-codes code)) err-already-referred)
        (map-set referral-codes code tx-sender)
        (ok true)
    )
)

(define-private (reward-referrer (referrer principal))
    (let (
        (referrer-data (unwrap-panic (map-get? referrals referrer)))
    )
        (try! (as-contract
            (stx-transfer? (var-get referral-reward) tx-sender referrer)))

        (map-set referrals referrer {
            referrer: (get referrer referrer-data),
            referral-count: (+ (get referral-count referrer-data) u1),
            total-earned: (+ (get total-earned referrer-data) (var-get referral-reward)),
            registration-block: (get registration-block referrer-data)
        })

        (ok true)
    )
)

(define-read-only (get-referral-stats (user principal))
    (map-get? referrals user)
)

(define-read-only (resolve-code (code (string-ascii 20)))
    (map-get? referral-codes code)
)

(define-read-only (get-referrer (user principal))
    (match (map-get? referrals user)
        data (get referrer data)
        none
    )
)

```
