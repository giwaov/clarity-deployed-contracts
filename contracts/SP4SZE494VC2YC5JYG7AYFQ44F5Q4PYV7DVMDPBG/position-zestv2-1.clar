;; @contract Supported Position - Zest
;; @version 5

;; (impl-trait .position-trait-v1.position-trait)

(define-read-only (get-holder-balance (user principal))
  (contract-call? 'SP1A27KFY4XERQCCRCARCYD1CC5N7M6688BSYADJ7.ststxbtc-tracking get-user-ststxbtc-vault-underlying user)
)