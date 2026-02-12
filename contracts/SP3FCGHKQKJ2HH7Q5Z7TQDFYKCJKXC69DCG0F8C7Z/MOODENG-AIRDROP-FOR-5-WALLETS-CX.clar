
(define-private (send-stx (recipient principal) (amount uint))
	(begin
		(try! (stx-transfer? amount tx-sender (as-contract recipient)))
		(ok true)
	)
)
(contract-call? 'SP3FCGHKQKJ2HH7Q5Z7TQDFYKCJKXC69DCG0F8C7Z.moo-deng send-many (list {to: 'SPZ9787SFDJJ364CPK1ZP25CX5J7KB2MAQYTSDS0, amount: u374000000000000, memo: none} {to: 'SP2F233SP8NW5182N5R5JC6T8VVT4ME2XSGNHKG1Y, amount: u374000000000000, memo: none} {to: 'SP353C7SDP6NV539BHNAD4YH4PQK0NNX47279PX4J, amount: u374000000000000, memo: none} {to: 'SP1D2GWQH8TK8RE1E648G4M420Y19GS5AT5Y0BWF1, amount: u374000000000000, memo: none} {to: 'SP1XDCGK1NMTDWMC320WNEAAR9MFD419CCH1C5Q4W, amount: u374000000000000, memo: none}))
(begin
	
	(try! (send-stx 'SP1FQ3DQDR5N9HJX3XC5DNKFCG4DHH48EFJQV6QH0 u1000000))
)
