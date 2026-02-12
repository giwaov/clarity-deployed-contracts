;; Token Auction Platform
;; Decentralized auction system for STX and tokens

(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u200))
(define-constant err-auction-not-found (err u201))
(define-constant err-auction-ended (err u202))
(define-constant err-bid-too-low (err u203))
(define-constant err-auction-active (err u204))

(define-map auctions
    { auction-id: uint }
    {
        seller: principal,
        reserve-price: uint,
        highest-bid: uint,
        highest-bidder: (optional principal),
        end-block: uint,
        settled: bool
    }
)

(define-data-var auction-counter uint u0)

;; Create auction
(define-public (create-auction (reserve-price uint) (duration uint))
    (let
        (
            (auction-id (+ (var-get auction-counter) u1))
        )
        (map-set auctions
            { auction-id: auction-id }
            {
                seller: tx-sender,
                reserve-price: reserve-price,
                highest-bid: u0,
                highest-bidder: none,
                end-block: (+ stacks-block-height duration),
                settled: false
            }
        )
        (var-set auction-counter auction-id)
        (ok auction-id)
    )
)

;; Place bid
(define-public (place-bid (auction-id uint) (bid-amount uint))
    (let
        (
            (auction (unwrap! (map-get? auctions { auction-id: auction-id }) err-auction-not-found))
        )
        (asserts! (< stacks-block-height (get end-block auction)) err-auction-ended)
        (asserts! (> bid-amount (get highest-bid auction)) err-bid-too-low)
        (asserts! (>= bid-amount (get reserve-price auction)) err-bid-too-low)
        
        ;; Refund previous bidder
        (match (get highest-bidder auction)
            prev-bidder (try! (as-contract (stx-transfer? (get highest-bid auction) tx-sender prev-bidder)))
            true
        )
        
        ;; Accept new bid
        (try! (stx-transfer? bid-amount tx-sender (as-contract tx-sender)))
        (map-set auctions
            { auction-id: auction-id }
            (merge auction {
                highest-bid: bid-amount,
                highest-bidder: (some tx-sender)
            })
        )
        (ok true)
    )
)

;; Settle auction
(define-public (settle-auction (auction-id uint))
    (let
        (
            (auction (unwrap! (map-get? auctions { auction-id: auction-id }) err-auction-not-found))
        )
        (asserts! (>= stacks-block-height (get end-block auction)) err-auction-active)
        (asserts! (not (get settled auction)) err-auction-ended)
        
        (match (get highest-bidder auction)
            winner (try! (as-contract (stx-transfer? (get highest-bid auction) tx-sender (get seller auction))))
            true
        )
        
        (map-set auctions
            { auction-id: auction-id }
            (merge auction { settled: true })
        )
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-auction (auction-id uint))
    (map-get? auctions { auction-id: auction-id })
)
