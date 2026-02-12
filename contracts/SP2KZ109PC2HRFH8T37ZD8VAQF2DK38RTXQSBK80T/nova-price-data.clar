
;; nova-price-data.clar
;; Trusted source for asset prices with authorized updaters.
;; CLARITY VERSION: 2

(define-constant ERR-NOT-AUTHORIZED (err u100))

(define-data-var oracle-owner principal tx-sender)

(define-map prices
    (string-ascii 10) ;; Asset symbol e.g., "BTC", "STX"
    {
        price: uint, ;; Price in cents or appropriate precision
        last-update: uint
    }
)

(define-map authorized-feeders principal bool)

(define-public (set-feeder (feeder principal) (active bool))
    (begin
        (asserts! (is-eq tx-sender (var-get oracle-owner)) ERR-NOT-AUTHORIZED)
        (map-set authorized-feeders feeder active)
        (ok true)
    )
)

(define-public (update-price (symbol (string-ascii 10)) (price uint))
    (let (
        (sender tx-sender)
    )
    (asserts! (default-to false (map-get? authorized-feeders sender)) ERR-NOT-AUTHORIZED)
    
    (map-set prices symbol {
        price: price,
        last-update: block-height
    })
    (ok true))
)

(define-read-only (get-price (symbol (string-ascii 10)))
    (map-get? prices symbol)
)
