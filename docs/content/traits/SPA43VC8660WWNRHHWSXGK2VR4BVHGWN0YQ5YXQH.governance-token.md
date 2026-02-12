---
title: "Trait governance-token"
draft: true
---
```
;; governance-token
;; Governance and DAO Management

(define-constant err-not-member (err u200))

(define-map proposals 
  { id: uint }
  { title: (string-ascii 64), description: (string-ascii 256), votes-for: uint, votes-against: uint, status: (string-ascii 10) }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { amount: uint, side: bool }
)

(define-data-var proposal-count uint u0)

(define-public (create-proposal (title (string-ascii 64)) (desc (string-ascii 256)))
  (let ((pid (+ (var-get proposal-count) u1)))
    (map-set proposals { id: pid } 
      { title: title, description: desc, votes-for: u0, votes-against: u0, status: "active" }
    )
    (var-set proposal-count pid)
    (ok pid)
  )
)

(define-public (vote (proposal-id uint) (amount uint) (for bool))
  (let ((prop (unwrap! (map-get? proposals { id: proposal-id }) (err u404))))
    (map-set votes { proposal-id: proposal-id, voter: tx-sender } { amount: amount, side: for })
    (ok (map-set proposals { id: proposal-id }
      (merge prop {
        votes-for: (if for (+ (get votes-for prop) amount) (get votes-for prop)),
        votes-against: (if for (get votes-against prop) (+ (get votes-against prop) amount))
      })
    ))
  )
)
```
