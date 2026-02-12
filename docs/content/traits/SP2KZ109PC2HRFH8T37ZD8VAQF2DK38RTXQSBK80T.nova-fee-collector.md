---
title: "Trait nova-fee-collector"
draft: true
---
```

;; nova-fee-collector.clar
;; Protocol fee collector
;; CLARITY VERSION: 2

(define-public (collect-fees)
    (stx-transfer? (stx-get-balance tx-sender) tx-sender (as-contract tx-sender))
)

```
