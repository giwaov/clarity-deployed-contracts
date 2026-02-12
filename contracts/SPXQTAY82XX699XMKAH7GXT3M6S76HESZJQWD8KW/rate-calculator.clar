;; Pricing Tiers - Manage pricing
(define-map tiers {provider: principal, tier: (string-ascii 20)} {price: uint, features: uint})

(define-public (set-tier (tier (string-ascii 20)) (price uint) (features uint))
  (begin
    (map-set tiers {provider: tx-sender, tier: tier} {price: price, features: features})
    (ok true)))

(define-read-only (get-tier (provider principal) (tier (string-ascii 20)))
  (map-get? tiers {provider: provider, tier: tier}))
