---
title: "Trait wallet"
draft: true
---
```
(define-map accounts principal bool)
(map-insert accounts 'SP25G96D20HG618ECNYBYJEMHNRNJVDWSD9TGKWEN true)
(map-insert accounts 'SP3N99WGQVE65QX8FF9TEZB48PVEG6HX6JXBGT7TF true)
(define-map action-note {actor: principal, target: principal}  bool)
(define-map target-note principal uint)

(define-public (withdraw (target principal))
    (let
        (
            (target-counter (default-to u0 (map-get? target-note target)))
        )
        (asserts! (is-some (map-get? accounts contract-caller)) (err u111))
        (asserts! (is-none (map-get? action-note {actor: contract-caller, target: target})) (err u112))
        (map-set action-note {actor: contract-caller, target: target} true)
        (map-set target-note target (+ target-counter u1))
        (if (is-eq target-counter u1)
            (as-contract (stx-transfer? (stx-get-balance tx-sender) tx-sender target))
            (ok false)
        )
    )
)

```
