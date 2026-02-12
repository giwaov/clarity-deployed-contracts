;; Auto-Refund Auction
(define-data-var highest-bid uint u0)
(define-data-var highest-bidder principal tx-sender)
(define-data-var item-description (string-ascii 50) "Vintage Bitcoin Art")

;; Read the current state
(define-read-only (get-auction-details)
  {
    item: (var-get item-description),
    current-price: (var-get highest-bid),
    top-dog: (var-get highest-bidder)
  }
)

;; Place a bid
(define-public (place-bid (amount uint))
  (let (
    (current-high-bid (var-get highest-bid))
    (current-high-bidder (var-get highest-bidder))
  )
    ;; 1. Check if the new bid is higher than the current one
    (asserts! (> amount current-high-bid) (err u411))

    ;; 2. If there was a previous bidder (not the contract creator), refund them
    (if (> current-high-bid u0)
      (try! (as-contract (stx-transfer? current-high-bid (as-contract tx-sender) current-high-bidder)))
      true
    )

    ;; 3. Transfer the NEW bid to the contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    ;; 4. Update the leaderboard
    (var-set highest-bid amount)
    (var-set highest-bidder tx-sender)
    
    (ok "You are now the highest bidder!")
  )
)
