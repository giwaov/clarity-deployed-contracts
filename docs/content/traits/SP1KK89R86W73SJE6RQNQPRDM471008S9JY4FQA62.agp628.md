---
title: "Trait agp628"
draft: true
---
```
;; SPDX-License-Identifier: BUSL-1.1

(impl-trait 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.proposal-trait.proposal-trait)

(define-constant ONE_8 u100000000) ;; 8 decimal places

(define-constant emissions (list 
	{ token-id: u13, amount: (* (+ u141900 u103200) ONE_8) } ;; STX-ALEX
	{ token-id: u44, amount: (* u103200 ONE_8) } ;; ALEX-LiALEX
	{ token-id: u104, amount: (* u283800 ONE_8) } ;; aBTC-aUSD
	{ token-id: u120, amount: u0 } ;; aBTC-LiaBTC
	{ token-id: u43, amount: (* u10000 ONE_8) } ;; ALEX-LEO
	{ token-id: u171, amount: (* u10000 ONE_8) } ;; ALEX-WELSH
))
(define-constant pool-token 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-amm-pool-v2-01)

(define-public (execute (sender principal))
	(begin
		;; Set farming emissions
		(try! (fold set-farming-iter emissions (ok true)))
		
		;; Finalise ALEX token migration for the following addresses
		(try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SP242EYG60RDPPY74JSZRZGT3VEAZAVY2XJ37HJW9))
		(try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SP1NGMS9Z48PRXFAG2MKBSP0PWERF07C0KV9SPJ66))
		(try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SP3TTKA1M6XH00DZXEZK3B77TA957DBDPY1K6321W))
		(try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SP22AB49K0D6VBHZY7BB2FBH38XFHNGHXG4MTPCED))
		(try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SP3YPW9ME7VJJBR0K1S71F92P0E8BW7GNZ9MAYRA2))
		(try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SPZ8XVGVFSQXXM5ZN7VQWCX19TDQ36QDPFW4P83R))
		
		(ok true)))

(define-private (set-farming-iter (farm { token-id: uint, amount: uint }) (prior (response bool uint)))
	(match prior
		ok-value
		(begin
			(try! (contract-call? 'SP1KK89R86W73SJE6RQNQPRDM471008S9JY4FQA62.alex-farming-v2 set-coinbase-amount pool-token (get token-id farm) (get amount farm) (get amount farm) (get amount farm) (get amount farm) (/ (get amount farm) u2)))
			(print (merge farm { reward-cycle: (contract-call? 'SP1KK89R86W73SJE6RQNQPRDM471008S9JY4FQA62.alex-farming-v2 get-reward-cycle pool-token (get token-id farm) tenure-height) }))
			(ok true))
		err-value (err err-value)))



```
