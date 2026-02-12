---
title: "Trait nova-asset-tokenizer"
draft: true
---
```

;; Nova Asset Tokenizer
;; Tokenizes real-world assets into Clarity tokens

(define-constant ERR-NOT-AUTHORIZED (err u100))

(define-map asset-tokens
    { token-id: uint }
    {
        name: (string-ascii 64),
        underlying-asset: (string-ascii 128),
        valuation: uint,
        custodian: principal
    }
)

(define-data-var last-id uint u0)

(define-public (tokenize-asset (name (string-ascii 64)) (asset-ref (string-ascii 128)) (valuation uint))
    (let
        (
            (token-id (+ (var-get last-id) u1))
        )
        (var-set last-id token-id)
        (map-set asset-tokens
            { token-id: token-id }
            {
                name: name,
                underlying-asset: asset-ref,
                valuation: valuation,
                custodian: tx-sender
            }
        )
        (ok token-id)
    )
)

(define-public (update-valuation (token-id uint) (new-valuation uint))
    (let
        (
            (asset (unwrap! (map-get? asset-tokens { token-id: token-id }) (err u404)))
        )
        (asserts! (is-eq tx-sender (get custodian asset)) ERR-NOT-AUTHORIZED)
        (ok (map-set asset-tokens
            { token-id: token-id }
            (merge asset { valuation: new-valuation })
        ))
    )
)

```
