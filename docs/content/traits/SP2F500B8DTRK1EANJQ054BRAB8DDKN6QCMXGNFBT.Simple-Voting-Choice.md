---
title: "Trait Simple-Voting-Choice"
draft: true
---
```
(define-map votes principal bool)

(define-public (vote (choice bool))
  (begin
    (map-set votes tx-sender choice)
    (ok choice)
  )
)

```
