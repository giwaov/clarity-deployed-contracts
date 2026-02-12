---
title: "Trait dice"
draft: true
---
```

(define-public (roll-dice (sides uint))
    (let (
          ;; Pseudo-random seed from block data
          (seed (+ stacks-block-height stacks-block-time))
         )
        (begin
            ;; Dice must have at least 2 sides
            (asserts! (> sides u1) (err u400))

            
            (ok (+ (mod seed sides) u1))
        )
    )
)

```
