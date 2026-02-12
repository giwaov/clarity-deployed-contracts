(define-constant zstSTXbtc u11)

(define-constant ERR-NO-POSITION (err u900003))

(define-private (find-collateral-amount-iter
  (entry { aid: uint, amount: uint })
  (acc { target: uint, amount: uint }))
  (if (is-eq (get aid entry) (get target acc))
      { target: (get target acc), amount: (get amount entry) }
      acc))

(define-read-only (get-user-ststxbtc-vault-underlying (account principal))
  (let (
    (vault-shares (unwrap-panic (contract-call? .vault-ststxbtc get-balance account)))
    (vault-underlying (unwrap-panic (contract-call? .vault-ststxbtc convert-to-assets vault-shares))))
    (ok vault-underlying)))

(define-read-only (get-user-ststxbtc-market-underlying (account principal))
  (let (
    (enabled-mask (contract-call? .assets get-bitmap))
    (market-zststxbtc-shares
      (match (contract-call? .market-vault get-position account enabled-mask)
        position
          (get amount (fold find-collateral-amount-iter
                           (get collateral position)
                           {target: zstSTXbtc, amount: u0}))
        err-no-position u0))
    (market-ststxbtc-underlying (unwrap-panic (contract-call? .vault-ststxbtc convert-to-assets market-zststxbtc-shares))))
    (ok market-ststxbtc-underlying)))
