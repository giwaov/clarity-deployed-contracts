
;; nova-nft-auction.clar
;; Simple auction mechanism
;; CLARITY VERSION: 2

(use-trait nova-trait-non-fungible .nova-trait-non-fungible.nova-trait-non-fungible)

(define-map auctions
    uint
    {
        asset: principal,
        token-id: uint,
        highest-bid: uint,
        highest-bidder: (optional principal),
        end-time: uint
    }
)

(define-public (place-bid (auction-id uint) (amount uint))
    (let (
        (auction (unwrap! (map-get? auctions auction-id) (err u404)))
    )
    (asserts! (> amount (get highest-bid auction)) (err u100))
    ;; Transfer logic
    (map-set auctions auction-id (merge auction {highest-bid: amount, highest-bidder: (some tx-sender)}))
    (ok true)
    )
)
