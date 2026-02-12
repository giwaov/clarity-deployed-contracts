---
title: "Trait nova-digital-twin-registry"
draft: true
---
```

;; Nova Digital Twin Registry
;; Links physical assets to digital counterparts

(define-map digital-twins
    { asset-id: (string-ascii 64) }
    {
        owner: principal, 
        physical-verifier: principal,
        metadata-hash: (buff 32),
        last-verified: uint
    }
)

(define-public (register-twin (asset-id (string-ascii 64)) (verifier principal) (metadata-hash (buff 32)))
    (ok (map-set digital-twins
        { asset-id: asset-id }
        {
            owner: tx-sender,
            physical-verifier: verifier,
            metadata-hash: metadata-hash,
            last-verified: block-height
        }
    ))
)

(define-public (verify-asset (asset-id (string-ascii 64)))
    (let
        (
            (twin (unwrap! (map-get? digital-twins { asset-id: asset-id }) (err u404)))
        )
        (asserts! (is-eq tx-sender (get physical-verifier twin)) (err u100))
        (ok (map-set digital-twins
            { asset-id: asset-id }
            (merge twin { last-verified: block-height })
        ))
    )
)

```
