;; BitPay Marketplace Contract
;; Enables buying and selling of obligation NFTs for invoice factoring

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u401))
(define-constant err-listing-not-found (err u404))
(define-constant err-already-listed (err u409))
(define-constant err-invalid-price (err u400))
(define-constant err-invalid-stream (err u400))
(define-constant err-not-nft-owner (err u403))
(define-constant err-payment-failed (err u402))
(define-constant err-transfer-failed (err u403))
(define-constant err-listing-inactive (err u410))
(define-constant err-no-pending-purchase (err u411))
(define-constant err-purchase-expired (err u412))
(define-constant err-buyer-mismatch (err u413))
(define-constant err-payment-id-mismatch (err u414))
(define-constant err-not-expired (err u415))
(define-constant err-already-pending (err u416))

;; Data Variables
(define-data-var total-listings uint u0)
(define-data-var total-sales uint u0)
(define-data-var total-volume uint u0)
(define-data-var marketplace-fee-bps uint u100) ;; Platform fee: 1% = 100 basis points

;; Data Maps
(define-map listings
  uint ;; stream-id
  {
    seller: principal,
    price: uint,
    listed-at: uint,
    active: bool,
  }
)

(define-map user-listings
  principal
  (list 50 uint) ;; List of stream-ids listed by user
)

(define-map sales-history
  uint ;; sale-id
  {
    stream-id: uint,
    seller: principal,
    buyer: principal,
    price: uint,
    sold-at: uint,
    payment-id: (optional (string-ascii 64)),
  }
)

;; Pending purchases for gateway-assisted buying
(define-map pending-purchases
  uint ;; stream-id
  {
    buyer: principal,
    payment-id: (string-ascii 64),
    initiated-at: uint,
    expires-at: uint,
  }
)

;; Authorized backend principals who can complete gateway purchases
(define-map authorized-backends
  principal
  bool
)

;; Read-only functions

;; Get listing details for a stream
;; @param stream-id: ID of the stream
;; @returns: Optional listing data
(define-read-only (get-listing (stream-id uint))
  (map-get? listings stream-id)
)

;; Check if a stream is currently listed
;; @param stream-id: ID of the stream
;; @returns: true if active listing exists, false otherwise
(define-read-only (is-listed (stream-id uint))
  (match (get-listing stream-id)
    listing (get active listing)
    false
  )
)

;; Get all listings created by a user
;; @param user: Principal address
;; @returns: List of stream IDs listed by user
(define-read-only (get-user-listings (user principal))
  (default-to (list) (map-get? user-listings user))
)

;; Get sale history by sale ID
;; @param sale-id: ID of the sale
;; @returns: Optional sale data
(define-read-only (get-sale-history (sale-id uint))
  (map-get? sales-history sale-id)
)

;; Get marketplace statistics
;; @returns: (ok stats) with total listings, sales, and volume
(define-read-only (get-marketplace-stats)
  (ok {
    total-listings: (var-get total-listings),
    total-sales: (var-get total-sales),
    total-volume: (var-get total-volume),
  })
)

;; Calculate marketplace fee for a given price
;; @param price: Sale price in sats
;; @returns: Fee amount in sats
(define-read-only (calculate-marketplace-fee (price uint))
  (/ (* price (var-get marketplace-fee-bps)) u10000)
)

;; Get current marketplace fee in basis points
;; @returns: (ok fee-bps)
(define-read-only (get-marketplace-fee-bps)
  (ok (var-get marketplace-fee-bps))
)

;; Calculate seller proceeds after marketplace fee
;; @param price: Sale price in sats
;; @returns: Net proceeds to seller in sats
(define-read-only (calculate-seller-proceeds (price uint))
  (- price (calculate-marketplace-fee price))
)

;; Get pending purchase details for a stream
;; @param stream-id: ID of the stream
;; @returns: Optional pending purchase data
(define-read-only (get-pending-purchase (stream-id uint))
  (map-get? pending-purchases stream-id)
)

;; Check if a stream has a pending purchase
;; @param stream-id: ID of the stream
;; @returns: true if pending purchase exists, false otherwise
(define-read-only (is-pending-purchase (stream-id uint))
  (is-some (get-pending-purchase stream-id))
)

;; Check if a principal is an authorized backend
;; @param backend: Principal to check
;; @returns: true if authorized, false otherwise
(define-read-only (is-authorized-backend (backend principal))
  (default-to false (map-get? authorized-backends backend))
)

;; Get count of active listings
;; @returns: (ok total-listings)
(define-read-only (get-active-listings-count)
  (ok (var-get total-listings))
)

;; Get detailed listing information including fees
;; @param stream-id: ID of the stream
;; @returns: (ok listing-details) or error
(define-read-only (get-listing-details (stream-id uint))
  (match (get-listing stream-id)
    listing (ok {
      stream-id: stream-id,
      seller: (get seller listing),
      price: (get price listing),
      listed-at: (get listed-at listing),
      active: (get active listing),
      marketplace-fee: (calculate-marketplace-fee (get price listing)),
      seller-proceeds: (calculate-seller-proceeds (get price listing)),
    })
    err-listing-not-found
  )
)

;; Public functions

;; List an obligation NFT for sale
;; @param stream-id: ID of the stream to list
;; @param price: Asking price in sats
;; @returns: (ok true) on success
(define-public (list-nft
    (stream-id uint)
    (price uint)
  )
  (let (
      (listing-check (get-listing stream-id))
      (nft-owner-response (unwrap! (contract-call? .bitpay-obligation-nft-v4 get-owner stream-id)
        err-invalid-stream
      ))
      (nft-owner (unwrap! nft-owner-response err-not-nft-owner))
    )
    ;; Validations
    (asserts! (> price u0) err-invalid-price)
    (asserts! (is-eq nft-owner tx-sender) err-not-nft-owner)
    (asserts! (is-none listing-check) err-already-listed)
    (asserts! (not (is-pending-purchase stream-id)) err-already-pending)

    ;; Create listing
    (map-set listings stream-id {
      seller: tx-sender,
      price: price,
      listed-at: stacks-block-height,
      active: true,
    })

    ;; Update user listings
    (match (map-get? user-listings tx-sender)
      existing-listings (map-set user-listings tx-sender
        (unwrap! (as-max-len? (append existing-listings stream-id) u50)
          err-not-authorized
        ))
      (map-set user-listings tx-sender (list stream-id))
    )

    ;; Update stats
    (var-set total-listings (+ (var-get total-listings) u1))

    ;; Emit event
    (print {
      event: "market-nft-listed",
      stream-id: stream-id,
      seller: tx-sender,
      price: price,
      listed-at: stacks-block-height,
    })

    (ok true)
  )
)

;; Update listing price
;; @param stream-id: ID of the stream listing to update
;; @param new-price: New asking price in sats
;; @returns: (ok true) on success
(define-public (update-listing-price
    (stream-id uint)
    (new-price uint)
  )
  (let ((listing (unwrap! (get-listing stream-id) err-listing-not-found)))
    ;; Validations
    (asserts! (> new-price u0) err-invalid-price)
    (asserts! (is-eq (get seller listing) tx-sender) err-not-authorized)
    (asserts! (get active listing) err-listing-not-found)

    ;; Update listing
    (map-set listings stream-id (merge listing { price: new-price }))

    ;; Emit event
    (print {
      event: "market-listing-price-updated",
      stream-id: stream-id,
      seller: tx-sender,
      old-price: (get price listing),
      new-price: new-price,
    })

    (ok true)
  )
)

;; Cancel listing
;; @param stream-id: ID of the stream listing to cancel
;; @returns: (ok true) on success
(define-public (cancel-listing (stream-id uint))
  (let ((listing (unwrap! (get-listing stream-id) err-listing-not-found)))
    ;; Validations
    (asserts! (is-eq (get seller listing) tx-sender) err-not-authorized)
    (asserts! (get active listing) err-listing-not-found)
    (asserts! (not (is-pending-purchase stream-id)) err-already-pending)

    ;; Deactivate listing
    (map-set listings stream-id (merge listing { active: false }))

    ;; Emit event
    (print {
      event: "market-listing-cancelled",
      stream-id: stream-id,
      seller: tx-sender,
    })

    (ok true)
  )
)

;; ========================================
;; OPTION 1: Direct On-Chain Purchase
;; ========================================

;; Buy an obligation NFT directly with crypto wallet (atomic transaction)
;; @param stream-id: ID of the stream to purchase
;; @returns: (ok sale-id) on success
(define-public (buy-nft (stream-id uint))
  (let (
      (listing (unwrap! (get-listing stream-id) err-listing-not-found))
      (seller (get seller listing))
      (price (get price listing))
      (marketplace-fee (calculate-marketplace-fee price))
      (seller-proceeds (calculate-seller-proceeds price))
      (sale-id (var-get total-sales))
      (treasury-address (unwrap! (contract-call? .bitpay-treasury-v4 get-contract-address)
        err-payment-failed
      ))
    )
    ;; Validations
    (asserts! (get active listing) err-listing-inactive)
    (asserts! (not (is-eq tx-sender seller)) err-not-authorized)
    (asserts! (not (is-pending-purchase stream-id)) err-already-pending)

    ;; Payment: buyer to seller (minus marketplace fee)
    (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      transfer seller-proceeds tx-sender seller none
    ))

    ;; Payment: buyer to treasury (marketplace fee)
    (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      transfer marketplace-fee tx-sender treasury-address none
    ))

    ;; Notify treasury to update its accounting
    (try! (as-contract (contract-call? .bitpay-treasury-v4 collect-marketplace-fee marketplace-fee)))

    ;; Transfer obligation NFT: seller to buyer
    (try! (contract-call? .bitpay-obligation-nft-v4 transfer stream-id seller tx-sender))

    ;; Update stream sender: seller to buyer
    (try! (as-contract (contract-call? .bitpay-core-v4 update-stream-sender stream-id tx-sender)))

    ;; Deactivate listing
    (map-set listings stream-id (merge listing { active: false }))

    ;; Record sale
    (map-set sales-history sale-id {
      stream-id: stream-id,
      seller: seller,
      buyer: tx-sender,
      price: price,
      sold-at: stacks-block-height,
      payment-id: none,
    })

    ;; Update stats
    (var-set total-sales (+ sale-id u1))
    (var-set total-volume (+ (var-get total-volume) price))

    ;; Emit event
    (print {
      event: "market-direct-purchase-completed",
      stream-id: stream-id,
      buyer: tx-sender,
      seller: seller,
      price: price,
      sale-id: sale-id,
    })

    (ok sale-id)
  )
)

;; ========================================
;; OPTION 2: Gateway-Assisted Purchase
;; ========================================

;; Step 1: Initiate purchase through payment gateway
;; Called by buyer when they start checkout on external gateway
;; @param stream-id: ID of the stream to purchase
;; @param payment-id: Unique payment identifier from gateway
;; @returns: (ok true) on success
;; #[allow(unchecked_data)]
(define-public (initiate-purchase
    (stream-id uint)
    (payment-id (string-ascii 64))
  )
  (let (
      (listing (unwrap! (get-listing stream-id) err-listing-not-found))
      (expiry (+ stacks-block-height u1008)) ;; ~1 week expiry (144 blocks/day * 7)
    )
    ;; Validations
    (asserts! (get active listing) err-listing-inactive)
    (asserts! (not (is-eq tx-sender (get seller listing))) err-not-authorized)
    (asserts! (not (is-pending-purchase stream-id)) err-already-pending)

    ;; Create pending purchase record
    (map-set pending-purchases stream-id {
      buyer: tx-sender,
      payment-id: payment-id,
      initiated-at: stacks-block-height,
      expires-at: expiry,
    })

    ;; Emit event for monitoring
    (print {
      event: "market-purchase-initiated",
      stream-id: stream-id,
      buyer: tx-sender,
      payment-id: payment-id,
      expires-at: expiry,
    })

    (ok true)
  )
)

;; Step 2: Complete purchase after payment confirmed by gateway
;; Called by authorized backend after webhook confirms payment
;; @param stream-id: ID of the stream to complete purchase
;; @param buyer: Principal of the buyer
;; @param payment-id: Payment identifier to verify
;; @returns: (ok sale-id) on success
(define-public (complete-purchase
    (stream-id uint)
    (buyer principal)
    (payment-id (string-ascii 64))
  )
  (let (
      (listing (unwrap! (get-listing stream-id) err-listing-not-found))
      (pending (unwrap! (get-pending-purchase stream-id) err-no-pending-purchase))
      (seller (get seller listing))
      (price (get price listing))
      (sale-id (var-get total-sales))
    )
    ;; Authorization checks
    (asserts! (is-authorized-backend tx-sender) err-not-authorized)
    (asserts! (get active listing) err-listing-inactive)
    (asserts! (is-eq (get buyer pending) buyer) err-buyer-mismatch)
    (asserts! (is-eq (get payment-id pending) payment-id) err-payment-id-mismatch)
    (asserts! (< stacks-block-height (get expires-at pending))
      err-purchase-expired
    )

    ;; Transfer obligation NFT: seller to buyer
    (unwrap!
      (contract-call? .bitpay-obligation-nft-v4 transfer stream-id seller buyer)
      err-transfer-failed
    )

    ;; Update stream sender: seller to buyer
    (unwrap!
      (as-contract (contract-call? .bitpay-core-v4 update-stream-sender stream-id buyer))
      err-transfer-failed
    )

    ;; Deactivate listing and clear pending purchase
    (map-set listings stream-id (merge listing { active: false }))
    (map-delete pending-purchases stream-id)

    ;; Record sale
    (map-set sales-history sale-id {
      stream-id: stream-id,
      seller: seller,
      buyer: buyer,
      price: price,
      sold-at: stacks-block-height,
      payment-id: (some payment-id),
    })

    ;; Update stats
    (var-set total-sales (+ sale-id u1))
    (var-set total-volume (+ (var-get total-volume) price))

    ;; Emit event for chainhook monitoring
    (print {
      event: "market-gateway-purchase-completed",
      stream-id: stream-id,
      buyer: buyer,
      seller: seller,
      price: price,
      payment-id: payment-id,
      sale-id: sale-id,
    })

    (ok sale-id)
  )
)

;; Cancel expired pending purchase
;; Allows cleaning up expired purchase attempts
;; @param stream-id: ID of the stream with expired purchase
;; @returns: (ok true) on success
(define-public (cancel-expired-purchase (stream-id uint))
  (let ((pending (unwrap! (get-pending-purchase stream-id) err-no-pending-purchase)))
    (asserts! (>= stacks-block-height (get expires-at pending)) err-not-expired)
    (map-delete pending-purchases stream-id)

    (print {
      event: "market-purchase-expired",
      stream-id: stream-id,
      buyer: (get buyer pending),
    })

    (ok true)
  )
)

;; ========================================
;; Admin Functions
;; ========================================

;; Add authorized backend principal
;; @param backend: Principal to authorize
;; @returns: (ok true) on success
;; #[allow(unchecked_data)]
(define-public (add-authorized-backend (backend principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
    (map-set authorized-backends backend true)
    (print {
      event: "market-backend-authorized",
      backend: backend,
    })
    (ok true)
  )
)

;; Remove authorized backend principal
;; @param backend: Principal to deauthorize
;; @returns: (ok true) on success
;; #[allow(unchecked_data)]
(define-public (remove-authorized-backend (backend principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
    (map-delete authorized-backends backend)
    (print {
      event: "market-backend-deauthorized",
      backend: backend,
    })
    (ok true)
  )
)

;; Admin function to update marketplace fee
;; @param new-fee-bps: New fee in basis points (max 1000 = 10%)
;; @returns: (ok true) on success
(define-public (set-marketplace-fee (new-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
    (asserts! (<= new-fee-bps u1000) err-invalid-price) ;; Max 10% fee
    (var-set marketplace-fee-bps new-fee-bps)
    (print {
      event: "market-marketplace-fee-updated",
      old-fee: (var-get marketplace-fee-bps),
      new-fee: new-fee-bps,
    })
    (ok true)
  )
)
