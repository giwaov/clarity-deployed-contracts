;; @contract Supported Position - Zest
;; @version 6

;; (impl-trait .position-trait-v1.position-trait)

(define-read-only (get-holder-balance (user principal))
  (contract-call? 'SP1A27KFY4XERQCCRCARCYD1CC5N7M6688BSYADJ7.v0-1-data get-user-ststxbtc-balances user)
)