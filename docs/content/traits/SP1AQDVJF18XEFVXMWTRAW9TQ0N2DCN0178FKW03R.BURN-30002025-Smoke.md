---
title: "Trait BURN-30002025-Smoke"
draft: true
---
```

;;  ---------------------------------------------------------
;; Burn token event | Created on: stx.city/deploy $Smoke 2025
;; ---------------------------------------------------------
(define-private (send-stx (recipient principal) (amount uint))
	(begin
		(try! (stx-transfer? amount tx-sender recipient))
		(ok true)
	)
)
;; ---------------------------------------------------------
;; Burn
;; ---------------------------------------------------------
(begin
	(try! (send-stx 'SP2PYTA4H455ENBTQ3C1FWC5W5NEJ5CG821FY6G5Z u1000000))
	(contract-call? 'SP1AQDVJF18XEFVXMWTRAW9TQ0N2DCN0178FKW03R.smoke transfer u30002025000000 tx-sender 'SP000000000000000000002Q6VF78 none)
)

```
