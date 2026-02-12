---
title: "Trait market-trait-v2"
draft: true
---
```
(use-trait commission-trait 'SP3D6PV2ACBPEKYJTCMH7HEN02KP87QSP8KTEH335.commission-trait.commission) ;; 
(use-trait commission-ft-trait 'SP39WYZ7BCDD4E7XSKDFVQSERXYTT9MEFE5683JGR.commission-ft-trait.commission-ft) ;; 
(use-trait sip-010-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait) ;; 


(define-trait market-trait
    (
        (list-in-ustx (uint uint <commission-trait>) (response bool uint))
        (unlist-in-ustx (uint) (response bool uint))
        (buy-in-ustx (uint <commission-trait>) (response bool uint))
        (list-in-ft (uint uint <commission-ft-trait> <sip-010-trait>) (response bool uint))
        (buy-in-ft (uint <commission-ft-trait> <sip-010-trait>) (response bool uint))
    )
)

```
