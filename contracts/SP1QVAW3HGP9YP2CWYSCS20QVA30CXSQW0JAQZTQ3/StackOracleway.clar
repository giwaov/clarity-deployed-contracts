;; title: StackOracleway
;; version:
;; summary:
;; description:

(define-map contacts {owner: principal, contact-id: uint} {name: (string-ascii 50), address: principal})
(define-public (add-contact (contact-id uint) (name (string-ascii 50)) (address principal))
  (begin (map-set contacts {owner: tx-sender, contact-id: contact-id} {name: name, address: address}) (ok true)))
(define-read-only (get-contact (owner principal) (contact-id uint))
  (map-get? contacts {owner: owner, contact-id: contact-id}))