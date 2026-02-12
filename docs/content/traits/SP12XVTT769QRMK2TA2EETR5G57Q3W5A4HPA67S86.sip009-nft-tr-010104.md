---
title: "Trait sip009-nft-tr-010104"
draft: true
---
```
;; SIP009 NFT Trait - Standard NFT interface
(define-trait nft-trait
	(
		(get-last-token-id () (response uint uint))
		(get-token-uri (uint) (response (optional (string-ascii 256)) uint))
		(get-owner (uint) (response (optional principal) uint))
		(transfer (uint principal principal) (response bool uint))
	)
)
```
