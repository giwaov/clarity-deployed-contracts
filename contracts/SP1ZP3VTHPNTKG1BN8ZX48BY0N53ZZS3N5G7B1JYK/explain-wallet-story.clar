;; explain-wallet-story.clar
;; Clarity 2.05
;; Read-only helper contract for Stacks UX tooling

(define-read-only (get-name)
  "Explain Wallet Story"
)

(define-read-only (get-version)
  "1.0.0"
)

(define-read-only (describe-wallet (wallet principal))
  wallet
)

(define-read-only (describe-transaction (txid (buff 32)))
  txid
)
