---
title: "Trait charity-split"
draft: true
---
```
;; charity-split.clar
;; Split incoming funds to 2 addresses

(define-constant ADDR1 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)
(define-constant ADDR2 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)

(define-public (donate (amount uint))
    (let
        (
            (half (/ amount u2))
        )
        (try! (stx-transfer? half tx-sender ADDR1))
        (try! (stx-transfer? half tx-sender ADDR2))
        (ok true)
    )
)

```
