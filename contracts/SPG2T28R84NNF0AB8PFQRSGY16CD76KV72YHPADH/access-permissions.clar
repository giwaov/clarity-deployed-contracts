;; Access Permissions
(define-map permissions {resource-id: uint, user: principal} {can-read: bool, can-write: bool, can-admin: bool, granted-at: uint})
(define-public (set-permission (resource-id uint) (user principal) (can-read bool) (can-write bool) (can-admin bool) (granted-at uint))
  (begin (map-set permissions {resource-id: resource-id, user: user} {can-read: can-read, can-write: can-write, can-admin: can-admin, granted-at: granted-at}) (ok true)))
(define-read-only (get-permission (resource-id uint) (user principal))
  (map-get? permissions {resource-id: resource-id, user: user}))
