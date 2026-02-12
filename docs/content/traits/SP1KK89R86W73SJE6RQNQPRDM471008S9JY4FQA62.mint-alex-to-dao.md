---
title: "Trait mint-alex-to-dao"
draft: true
---
```
;; SPDX-License-Identifier: BUSL-1.1
(impl-trait 'SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.proposal-trait.proposal-trait)

(define-constant ONE_8 u100000000)

;; Amount to mint: 66362176.00765991 age000-governance-token
;; In fixed-point (8 decimals): 6636217600765991
(define-constant mint-amount u6636217600765991)

(define-public (execute (sender principal))
	(begin
		;; Mint age000-governance-token to legacy executor-dao
		(try! (contract-call? 'SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.age000-governance-token mint-fixed mint-amount 'SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.executor-dao))
		(ok true)
	)
)


```
