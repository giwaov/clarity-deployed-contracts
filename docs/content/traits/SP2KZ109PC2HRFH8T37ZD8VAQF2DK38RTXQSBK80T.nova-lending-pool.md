---
title: "Trait nova-lending-pool"
draft: true
---
```

;; nova-lending-pool.clar
;; Users lock STX collateral to borrow a Nova Fungible Token.
;; CLARITY VERSION: 2

(use-trait nova-trait-fungible .nova-trait-fungible.nova-trait-fungible)

(define-constant ERR-UNDERCOLLATERALIZED (err u100))
(define-constant ERR-LOAN-NOT-FOUND (err u101))

(define-map loans
    principal
    {
        collateral-stx: uint,
        borrowed-amount: uint,
        last-update: uint
    }
)

;; Simplified price: 1 STX = 1 Token (for demo)
;; In production, use an oracle!
(define-read-only (get-collateral-ratio (collateral uint) (borrowed uint))
    (if (is-eq borrowed u0)
        u999999
        (/ (* collateral u100) borrowed)) ;; Ratio in percentage
)

(define-public (borrow (borrow-amount uint) (collateral-amount uint) (token-trait <nova-trait-fungible>))
    (let (
        (sender tx-sender)
        (ratio (get-collateral-ratio collateral-amount borrow-amount))
    )
    (asserts! (>= ratio u150) ERR-UNDERCOLLATERALIZED) ;; 150% collateral requirements

    (try! (stx-transfer? collateral-amount sender (as-contract tx-sender)))
    (try! (as-contract (contract-call? token-trait transfer borrow-amount tx-sender sender none)))

    (map-set loans sender {
        collateral-stx: collateral-amount,
        borrowed-amount: borrow-amount,
        last-update: block-height
    })
    (ok true))
)

(define-public (repay (repay-amount uint) (token-trait <nova-trait-fungible>))
    (let (
        (sender tx-sender)
        (loan (unwrap! (map-get? loans sender) ERR-LOAN-NOT-FOUND))
        (current-borrowed (get borrowed-amount loan))
        (current-collateral (get collateral-stx loan))
    )
    (asserts! (>= current-borrowed repay-amount) (err u102))
    
    (try! (contract-call? token-trait transfer repay-amount sender (as-contract tx-sender) none))

    ;; Release proportional collateral
    (let (
        (collateral-to-return (/ (* repay-amount current-collateral) current-borrowed))
        (new-borrowed (- current-borrowed repay-amount))
        (new-collateral (- current-collateral collateral-to-return))
    )
        (try! (as-contract (stx-transfer? collateral-to-return tx-sender sender)))
        
        (if (is-eq new-borrowed u0)
            (map-delete loans sender)
            (map-set loans sender (merge loan { collateral-stx: new-collateral, borrowed-amount: new-borrowed }))
        )
        (ok collateral-to-return)
    )
    )
)

```
