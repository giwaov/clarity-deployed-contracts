;; Subscription Plans
(define-map subscriptions principal {plan: (string-ascii 20), expires-at: uint})
(define-public (subscribe (plan (string-ascii 20)) (expires-at uint))
  (begin (map-set subscriptions tx-sender {plan: plan, expires-at: expires-at}) (ok true)))
(define-read-only (get-subscription (user principal))
  (map-get? subscriptions user))
