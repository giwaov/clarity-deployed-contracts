;; Mini-Marketplace: List and Buy
(define-map listings principal {item-name: (string-ascii 20), price: uint})

;; Public: List an item for sale
(define-public (list-item (name (string-ascii 20)) (price uint))
  (begin
    (map-set listings tx-sender {item-name: name, price: price})
    (ok "Item listed!")
  )
)

;; Public: Buy an item from a seller
(define-public (buy-item (seller principal))
  (let (
    (listing (unwrap! (map-get? listings seller) (err u404))) ;; Item not found
    (amount (get price listing))
  )
    ;; 1. Transfer STX from buyer (tx-sender) to seller
    (try! (stx-transfer? amount tx-sender seller))
    
    ;; 2. Remove the listing after purchase
    (map-delete listings seller)
    (ok "Purchase complete!")
  )
)

;; Read-only: Check a listing
(define-read-only (get-listing (seller principal))
  (map-get? listings seller)
)
