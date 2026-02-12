---
title: "Trait tusdh0"
draft: true
---
```
(impl-trait .dao-traits.proposal-script)

(define-constant TYPE-DIA 0x01)
(define-constant USDH-TOKEN 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1)
(define-constant USDH-DIA-KEY "USDh/USD")

(define-public (execute)
  (begin
    (try! (contract-call? .v0-assets update
      USDH-TOKEN
      {
        type: TYPE-DIA,
        ident: (unwrap-panic (to-consensus-buff? USDH-DIA-KEY)),
        callcode: none,
        max-staleness: u86400
      }))
    (ok true)))

```
