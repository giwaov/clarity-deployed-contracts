;; Simple auction contract
(define-data-var highest-bidder principal tx-sender)
(define-data-var highest-bid uint u0)
(define-data-var auction-active bool true)
(define-data-var auction-end-time uint u0)
(define-map bids principal uint)

(define-read-only (get-highest-bid)
  (var-get highest-bid)
)

(define-read-only (get-highest-bidder)
  (var-get highest-bidder)
)

(define-public (place-bid (amount uint))
  (begin
    (asserts! (var-get auction-active) (err u1))
    (asserts! (> amount (var-get highest-bid)) (err u2))
    (asserts! (< burn-block-height (var-get auction-end-time)) (err u3))
    (var-set highest-bidder tx-sender)
    (var-set highest-bid amount)
    (map-set bids tx-sender amount)
    (ok true)
  )
)

(define-public (end-auction)
  (begin
    (asserts! (>= burn-block-height (var-get auction-end-time)) (err u1))
    (ok (var-set auction-active false))
  )
)
