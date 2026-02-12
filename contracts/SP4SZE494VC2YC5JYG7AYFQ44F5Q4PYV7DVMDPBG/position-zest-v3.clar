;; @contract Supported Position - Zest
;; @version 3

;; (impl-trait .position-trait-v1.position-trait)

(define-read-only (get-holder-balance (user principal))
  (contract-call? 'SP3YCQZYWQR0CA6TT35301B28DV9D926VBZBBJWR7.vault-ststxbtc get-balance user)
)