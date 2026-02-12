---
title: "Trait bounty"
draft: true
---
```
;; Bounty program contract
(define-map bounties {id: uint} {creator: principal, amount: uint, completed: bool, winner: (optional principal)})
(define-data-var bounty-counter uint u0)

(define-read-only (get-bounty (id uint))
  (map-get? bounties {id: id})
)

(define-public (create-bounty (amount uint))
  (let ((id (var-get bounty-counter)))
    (begin
      (map-set bounties {id: id} {
        creator: tx-sender,
        amount: amount,
        completed: false,
        winner: none
      })
      (ok (var-set bounty-counter (+ id u1)))
    )
  )
)

(define-public (claim-bounty (id uint))
  (let ((bounty (unwrap! (map-get? bounties {id: id}) (err u1))))
    (begin
      (asserts! (not (get completed bounty)) (err u2))
      (ok (map-set bounties {id: id} (merge bounty {completed: true, winner: (some tx-sender)})))
    )
  )
)

```
