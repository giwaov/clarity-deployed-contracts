;; Payment Methods
(define-map methods {user: principal, method-id: uint} {type: (string-ascii 20), active: bool})
(define-public (add-method (method-id uint) (type (string-ascii 20)))
  (begin (map-set methods {user: tx-sender, method-id: method-id} {type: type, active: true}) (ok true)))
(define-read-only (get-method (user principal) (method-id uint))
  (map-get? methods {user: user, method-id: method-id}))
