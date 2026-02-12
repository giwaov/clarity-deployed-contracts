;; Auction Bids
(define-map bids {auction-id: uint, bidder: principal} {amount: uint, timestamp: uint})
(define-public (place-bid (auction-id uint) (amount uint) (timestamp uint))
  (begin (map-set bids {auction-id: auction-id, bidder: tx-sender} {amount: amount, timestamp: timestamp}) (ok true)))
(define-read-only (get-bid (auction-id uint) (bidder principal))
  (map-get? bids {auction-id: auction-id, bidder: bidder}))
