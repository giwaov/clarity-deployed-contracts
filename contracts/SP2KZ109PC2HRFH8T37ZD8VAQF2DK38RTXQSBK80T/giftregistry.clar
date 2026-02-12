;; GiftRegistry - Wish list manager

(define-data-var gift-counter uint u0)

(define-map gifts uint {
    wisher: principal,
    item-name: (string-utf8 128),
    estimated-cost: uint,
    claimed: bool,
    claimer: (optional principal)
})

(define-public (add-gift (item-name (string-utf8 128)) (cost uint))
    (let ((gift-id (var-get gift-counter)))
        (map-set gifts gift-id {
            wisher: tx-sender,
            item-name: item-name,
            estimated-cost: cost,
            claimed: false,
            claimer: none
        })
        (var-set gift-counter (+ gift-id u1))
        (ok gift-id)))

(define-public (claim-gift (gift-id uint))
    (let ((gift (unwrap! (map-get? gifts gift-id) (err u100))))
        (ok (map-set gifts gift-id (merge gift {claimed: true, claimer: (some tx-sender)})))))

(define-read-only (get-gift (gift-id uint))
    (ok (map-get? gifts gift-id)))
