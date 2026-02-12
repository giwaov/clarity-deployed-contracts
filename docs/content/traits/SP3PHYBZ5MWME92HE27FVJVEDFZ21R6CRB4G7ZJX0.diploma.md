---
title: "Trait diploma"
draft: true
---
```
;; Contract: Digital Diploma
;; Description: NFT that can only be minted by authorized professors.

(define-non-fungible-token degree uint)
(define-data-var degree-count uint u0)

(define-public (issue-degree (student principal))
    (let
        (
            ;; Call University contract to check if sender is a professor
            (is-prof (contract-call? .university is-authorized tx-sender))
            (new-id (+ (var-get degree-count) u1))
        )
        ;; Strict check
        (asserts! is-prof (err u403))
        
        ;; Mint the degree
        (try! (nft-mint? degree new-id student))
        (var-set degree-count new-id)
        (ok "Degree Issued")
    )
)
```
