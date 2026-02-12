;; nft-rental.clar
;; Rent NFT for time

(define-map rentals uint { renter: principal, expiry: uint })

(define-public (rent (token-id uint) (duration uint))
    (begin
        (asserts! (> duration u0) (err u100))
        ;; Payment logic here
        (ok (map-set rentals token-id { renter: tx-sender, expiry: (+ block-height duration) }))
    )
)

(define-read-only (get-rental (token-id uint))
    (ok (map-get? rentals token-id))
)
