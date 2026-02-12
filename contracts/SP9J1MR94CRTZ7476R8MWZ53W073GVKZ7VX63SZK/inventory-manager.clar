;; Inventory Manager
(define-map inventory {item-id: uint, warehouse: principal} {quantity: uint, min-stock: uint, max-stock: uint, last-updated: uint})
(define-public (update-inventory (item-id uint) (quantity uint) (min-stock uint) (max-stock uint) (last-updated uint))
  (begin (map-set inventory {item-id: item-id, warehouse: tx-sender} {quantity: quantity, min-stock: min-stock, max-stock: max-stock, last-updated: last-updated}) (ok true)))
(define-read-only (get-inventory (item-id uint) (warehouse principal))
  (map-get? inventory {item-id: item-id, warehouse: warehouse}))
