---
title: "Trait nova-fee-distributor"
draft: true
---
```

;; nova-fee-distributor.clar
;; Distributes protocol fees to simulated stakers
;; CLARITY VERSION: 2

(define-map balances principal uint)
(define-data-var total-shares uint u0)

(define-public (deposit-fees (amount uint))
    (stx-transfer? amount tx-sender (as-contract tx-sender))
)

(define-public (claim-rewards)
    (let (
        (share (default-to u0 (map-get? balances tx-sender)))
        (contract-bal (stx-get-balance (as-contract tx-sender)))
        (total (var-get total-shares))
    )
    (asserts! (> total u0) (err u100))
    (asserts! (> share u0) (err u101))
    
    (let ((payout (/ (* contract-bal share) total)))
        (try! (as-contract (stx-transfer? payout tx-sender tx-sender)))
        (ok payout)
    )
    )
)

(define-public (add-shareholder (user principal) (shares uint))
    (begin
        (map-set balances user shares)
        (var-set total-shares (+ (var-get total-shares) shares))
        (ok true)
    )
)

```
