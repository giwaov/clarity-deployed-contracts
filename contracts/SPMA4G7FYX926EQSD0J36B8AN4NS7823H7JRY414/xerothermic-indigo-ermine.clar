(define-read-only (validate-stx-block-brackets-btc-block-2 (first-stx-block-height uint) (btc-block-wanted uint)) 
  (let 
    (
      (btc-block-before-stx (btc-block-for-given-stx-block-height (- first-stx-block-height u1)))
      (btc-block-in-stx (btc-block-for-given-stx-block-height u1))
    )
    (if (not (is-eq btc-block-before-stx (- btc-block-wanted u1))) 
      false
      (if (not (is-eq btc-block-in-stx btc-block-wanted))
        false
        true
      )
    )
  )
)

(define-read-only (btc-block-for-given-stx-block-height (stx-block-height uint))
  (at-block (unwrap-panic (get-stacks-block-info? id-header-hash stx-block-height)) burn-block-height)
)
