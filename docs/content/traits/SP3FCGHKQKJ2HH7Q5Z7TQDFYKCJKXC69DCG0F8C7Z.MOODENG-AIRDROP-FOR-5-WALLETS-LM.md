---
title: "Trait MOODENG-AIRDROP-FOR-5-WALLETS-LM"
draft: true
---
```

(define-private (send-stx (recipient principal) (amount uint))
	(begin
		(try! (stx-transfer? amount tx-sender (as-contract recipient)))
		(ok true)
	)
)
(contract-call? 'SP3FCGHKQKJ2HH7Q5Z7TQDFYKCJKXC69DCG0F8C7Z.moo-deng send-many (list {to: 'SP1FFBBC0Z04YR6S4PF797W16V6QTFA87WS3YZ6SM, amount: u2000000000000000, memo: none} {to: 'SP2VRX4PXTFKRQAW125AJN2FYMZGTJFHW49G62SMZ, amount: u2000000000000000, memo: none} {to: 'SPKR2E1Y85Q2W9B69CEJ91D6AK4DPCVP2K8MC59W, amount: u2000000000000000, memo: none} {to: 'SP15JVAXM8WM09Q79219E7PFNAHBEEV4QV5T1BYPX, amount: u2000000000000000, memo: none} {to: 'SPBWJGPR91VC42H00ZVK0RTQ5WYYEJ66XCTX58KN, amount: u2000000000000000, memo: none}))
(begin
	
	(try! (send-stx 'SP1FQ3DQDR5N9HJX3XC5DNKFCG4DHH48EFJQV6QH0 u1000000))
)

```
