;; auction-house.clar
;; Simple auction house with bidding and refunds

;; Constants
(define-constant CONTRACT-ADDRESS .auction-house)
(define-constant ERR-AUCTION-NOT-FOUND (err u100))
(define-constant ERR-NOT-SELLER (err u101))
(define-constant ERR-AUCTION-NOT-ACTIVE (err u102))
(define-constant ERR-AUCTION-STILL-ACTIVE (err u103))
(define-constant ERR-BID-TOO-LOW (err u104))
(define-constant ERR-INVALID-DURATION (err u105))
(define-constant ERR-EMPTY-TITLE (err u106))
(define-constant ERR-NO-FUNDS-TO-WITHDRAW (err u109))

;; Status
(define-constant STATUS-ACTIVE u0)
(define-constant STATUS-ENDED u1)

;; Data Variables
(define-data-var auction-counter uint u0)

;; Maps
(define-map auctions uint 
  {
    seller: principal,
    title: (string-ascii 64),
    description: (string-ascii 256),
    starting-price: uint,
    current-bid: uint,
    current-bidder: (optional principal),
    start-time: uint,
    end-time: uint,
    status: uint,
    bid-count: uint,
    claimed: bool
  }
)

;; Public Functions
(define-public (create-auction (title (string-ascii 64)) (description (string-ascii 256)) (starting-price uint) (duration-hours uint))
  (let (
    (auction-id (+ (var-get auction-counter) u1))
    (end-time (+ stacks-block-time (* duration-hours u3600)))
  )
    (begin
      (asserts! (> (len title) u0) ERR-EMPTY-TITLE)
      (asserts! (> (len description) u0) (err u110))
      (asserts! (> starting-price u0) (err u111))
      (asserts! (> duration-hours u0) ERR-INVALID-DURATION)
      
      (map-set auctions auction-id {
        seller: tx-sender,
        title: title,
        description: description,
        starting-price: starting-price,
        current-bid: u0,
        current-bidder: none,
        start-time: stacks-block-time,
        end-time: end-time,
        status: STATUS-ACTIVE,
        bid-count: u0,
        claimed: false
      })
      
      (var-set auction-counter auction-id)
      (print { event: "auction-created", id: auction-id, seller: tx-sender, end-time: end-time })
      (ok auction-id)
    )
  )
)

(define-public (place-bid (auction-id uint) (bid-amount uint))
  (let (
    (auction (unwrap! (map-get? auctions auction-id) ERR-AUCTION-NOT-FOUND))
    (min-bid (if (> (get current-bid auction) u0) 
                 (+ (get current-bid auction) u1) 
                 (get starting-price auction)))
  )
    (begin
      (asserts! (is-eq (get status auction) STATUS-ACTIVE) ERR-AUCTION-NOT-ACTIVE)
      (asserts! (< stacks-block-time (get end-time auction)) ERR-AUCTION-STILL-ACTIVE)
      (asserts! (>= bid-amount min-bid) ERR-BID-TOO-LOW)
      
      ;; In Clarity, we handle STX transfers explicitly
      (unwrap-panic (stx-transfer? bid-amount tx-sender CONTRACT-ADDRESS))
      
      ;; Refund previous bidder
      (match (get current-bidder auction)
        prev-bidder (try! (stx-transfer? (get current-bid auction) CONTRACT-ADDRESS prev-bidder))
        true
      )
      
      (map-set auctions auction-id (merge auction {
        current-bid: bid-amount,
        current-bidder: (some tx-sender),
        bid-count: (+ (get bid-count auction) u1)
      }))
      
      (print { event: "bid-placed", id: auction-id, bidder: tx-sender, amount: bid-amount })
      (ok true)
    )
  )
)

(define-public (end-auction (auction-id uint))
  (let ((auction (unwrap! (map-get? auctions auction-id) ERR-AUCTION-NOT-FOUND)))
    (begin
      (asserts! (is-eq (get status auction) STATUS-ACTIVE) ERR-AUCTION-NOT-ACTIVE)
      (asserts! (>= stacks-block-time (get end-time auction)) ERR-AUCTION-STILL-ACTIVE)
      
      (map-set auctions auction-id (merge auction { status: STATUS-ENDED }))
      (print { event: "auction-ended", id: auction-id, winner: (get current-bidder auction), price: (get current-bid auction) })
      (ok true)
    )
  )
)

(define-public (withdraw-funds (auction-id uint))
  (let ((auction (unwrap! (map-get? auctions auction-id) ERR-AUCTION-NOT-FOUND)))
    (begin
      (asserts! (is-eq (get status auction) STATUS-ENDED) ERR-AUCTION-NOT-ACTIVE)
      (asserts! (> (get current-bid auction) u0) ERR-NO-FUNDS-TO-WITHDRAW)
      
      (let ((amount (get current-bid auction)))
        (begin
          (map-set auctions auction-id (merge auction { current-bid: u0 }))
          (try! (stx-transfer? amount CONTRACT-ADDRESS (get seller auction)))
          (print { event: "funds-withdrawn", id: auction-id, seller: (get seller auction), amount: amount })
          (ok true)
        )
      )
    )
  )
)

;; Read-only
(define-read-only (get-auction (auction-id uint))
  (map-get? auctions auction-id)
)

;; CLARITY 4 FEATURE: to-ascii? for auction status
(define-read-only (get-auction-status-ascii (auction-id uint))
  (match (map-get? auctions auction-id)
    auction (let (
      (price-ascii (match (to-ascii? (get current-bid auction)) ok-val ok-val err "0"))
      (bid-count-ascii (match (to-ascii? (get bid-count auction)) ok-val ok-val err "0"))
      (status-val (get status auction))
      (status-str (if (is-eq status-val STATUS-ACTIVE) "ACTIVE"
        (if (is-eq status-val STATUS-ENDED) "ENDED"
        "CANCELLED")))
    )
      (ok {
        title: (get title auction),
        current-bid: price-ascii,
        bid-count: bid-count-ascii,
        status: status-str
      })
    )
    (ok {
        title: "Auction not found",
        current-bid: "0",
        bid-count: "0",
        status: "NOT_FOUND"
    })
  )
)
