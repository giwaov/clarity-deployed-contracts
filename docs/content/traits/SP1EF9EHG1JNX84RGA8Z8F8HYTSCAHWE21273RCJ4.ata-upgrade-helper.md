---
title: "Trait ata-upgrade-helper"
draft: true
---
```
(use-trait ata-standard-resource .ata-standard-resource-trait-v0.ata-standard-resource-trait-v0)

(define-public (upgrade-5x
    (resource <ata-standard-resource>)
    (index uint)
  )
  (begin
    (try! (contract-call? resource upgrade-factory index))
    (try! (contract-call? resource upgrade-factory index))
    (try! (contract-call? resource upgrade-factory index))
    (try! (contract-call? resource upgrade-factory index))
    (try! (contract-call? resource upgrade-factory index))
    (ok true)
  )
)

```
