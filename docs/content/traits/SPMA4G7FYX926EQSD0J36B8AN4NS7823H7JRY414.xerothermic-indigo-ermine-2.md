---
title: "Trait xerothermic-indigo-ermine-2"
draft: true
---
```
;; eg btc block missing 925719
;; btc block 925721 -> stx 5037800
;; btc block 925720 -> stx 5037746
;; btc block 925719 -> stx 5037746
;; btc block 925718 -> stx 5037582
(define-read-only (validate-stx-block-brackets-btc-block-2
    (first-stx-block-height uint)
    (btc-block-wanted uint)
  )
  (let (
      (btc-block-before-stx (btc-block-for-given-stx-block-height (- first-stx-block-height u1)))
      (btc-block-in-stx (btc-block-for-given-stx-block-height u1))
    )
    (if (not (<= btc-block-before-stx (- btc-block-wanted u1)))
      false
      (if (not (>= btc-block-in-stx btc-block-wanted))
        false
        true
      )
    )
  )
)

(define-read-only (btc-block-for-given-stx-block-height (stx-block-height uint))
  (at-block
    (unwrap-panic (get-stacks-block-info? id-header-hash stx-block-height))
    burn-block-height
  )
)
```
