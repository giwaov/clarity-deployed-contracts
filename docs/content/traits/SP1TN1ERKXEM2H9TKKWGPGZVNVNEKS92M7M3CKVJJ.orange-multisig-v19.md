---
title: "Trait orange-multisig-v19"
draft: true
---
```
(define-map transactions uint {confirmed: bool})
(define-public (confirm (id uint)) (ok (map-set transactions id {confirmed: true})))

```
