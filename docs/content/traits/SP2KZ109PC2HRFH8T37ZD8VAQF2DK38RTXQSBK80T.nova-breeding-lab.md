---
title: "Trait nova-breeding-lab"
draft: true
---
```

;; nova-breeding-lab.clar
;; Combines two NFTs to mint a new one
;; CLARITY VERSION: 2

(use-trait nova-trait-non-fungible .nova-trait-non-fungible.nova-trait-non-fungible)

(define-public (breed (nft <nova-trait-non-fungible>) (parent1 uint) (parent2 uint))
    (let ((owner1 (unwrap! (contract-call? nft get-owner parent1) (err u100))))
        (asserts! (is-eq (some tx-sender) owner1) (err u101))
        ;; Mint logic would go here
        (ok true)
    )
)

```
