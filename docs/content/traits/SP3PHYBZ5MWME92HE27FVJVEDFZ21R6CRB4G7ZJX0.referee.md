---
title: "Trait referee"
draft: true
---
```
;; Contract: Match Referee
;; Description: Sets the winner of the game.

(define-data-var winner (string-ascii 10) "PENDING")
(define-constant admin tx-sender)

(define-public (set-winner (team (string-ascii 10)))
    (begin
        (asserts! (is-eq tx-sender admin) (err u403))
        (var-set winner team)
        (ok "Winner Decided")
    )
)

(define-read-only (get-result)
    (ok (var-get winner))
)
```
