---
title: "Trait reputation-srt"
draft: true
---
```
;; Reputation system contract
(define-map reputation principal uint)
(define-map user-history {user: principal, action: (string-ascii 32)} uint)

(define-read-only (get-reputation (user principal))
  (default-to u0 (map-get? reputation user))
)

(define-public (increase-reputation (user principal) (amount uint))
  (let ((current (get-reputation user)))
    (begin
      (asserts! (> amount u0) (err u1))
      (ok (map-set reputation user (+ current amount)))
    )
  )
)

(define-public (decrease-reputation (user principal) (amount uint))
  (let ((current (get-reputation user)))
    (begin
      (asserts! (>= current amount) (err u2))
      (ok (map-set reputation user (- current amount)))
    )
  )
)

(define-public (log-action (action (string-ascii 32)))
  (let ((count (default-to u0 (map-get? user-history {user: tx-sender, action: action}))))
    (ok (map-set user-history {user: tx-sender, action: action} (+ count u1)))
  )
)

```
