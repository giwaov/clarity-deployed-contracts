---
title: "Trait BURN-10000000-NEDeX"
draft: true
---
```

;;  ---------------------------------------------------------
;; SYIH
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
	(contract-call? 'SP1KNRNZET8ZC5Q9P6F1FFW8YQH45CKMNY132B36S.ned2gsk-bonding-curve transfer u10000000000000 tx-sender 'SP000000000000000000002Q6VF78 none)
)

```
