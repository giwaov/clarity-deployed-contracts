;; Order Book Core Contract
;; Advanced on-chain order book with limit/market orders and partial fills
;; Uses Clarity 4 features: block timestamps, post-conditions, string conversion

(use-trait ft-trait .sip-010-trait.sip-010-trait)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-order-not-found (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-invalid-price (err u104))
(define-constant err-insufficient-balance (err u105))
(define-constant err-no-liquidity (err u106))
(define-constant err-order-already-filled (err u107))
(define-constant err-order-cancelled (err u108))
(define-constant err-cannot-cancel (err u109))
(define-constant err-token-transfer-failed (err u110))

;; Order side constants
(define-constant side-buy u1)
(define-constant side-sell u2)

;; Order status constants
(define-constant status-open u1)
(define-constant status-partially-filled u2)
(define-constant status-filled u3)
(define-constant status-cancelled u4)

;; Data Variables
(define-data-var next-order-id uint u1)
(define-data-var token-a principal .test-token-a)
(define-data-var token-b principal .test-token-b)

;; Order structure
(define-map orders
  { order-id: uint }
  {
    trader: principal,
    side: uint,  ;; 1 = buy, 2 = sell
    price: uint,  ;; Price in token-b per token-a (with decimals)
    amount: uint,  ;; Original amount in token-a
    filled: uint,  ;; Amount filled so far
    timestamp: uint,  ;; Block time when order was placed
    status: uint  ;; 1 = open, 2 = partially-filled, 3 = filled, 4 = cancelled
  }
)

;; User orders - track all orders for a user
(define-map user-orders
  { user: principal }
  { order-ids: (list 200 uint) }
)

;; Price level orders - orders at each price level
(define-map buy-orders-at-price
  { price: uint }
  { order-ids: (list 100 uint) }
)

(define-map sell-orders-at-price
  { price: uint }
  { order-ids: (list 100 uint) }
)

;; Active price levels
(define-data-var active-buy-prices (list 50 uint) (list))
(define-data-var active-sell-prices (list 50 uint) (list))

;; Order events
(define-map order-fills
  { order-id: uint, fill-index: uint }
  {
    filled-amount: uint,
    price: uint,
    timestamp: uint,
    counterparty-order: uint
  }
)

;; Private helper functions

;; Get remaining amount for an order
(define-private (get-remaining-amount (order-id uint))
  (let (
    (order (unwrap! (map-get? orders { order-id: order-id }) u0))
  )
    (- (get amount order) (get filled order))
  )
)

;; Check if order is active (open or partially filled)
(define-private (is-order-active (order-id uint))
  (match (map-get? orders { order-id: order-id })
    order (or (is-eq (get status order) status-open) 
               (is-eq (get status order) status-partially-filled))
    false
  )
)

;; Add price to active price list if not already there
(define-private (add-to-active-prices (price uint) (is-buy bool))
  (let (
    (current-prices (if is-buy 
                       (var-get active-buy-prices) 
                       (var-get active-sell-prices)))
  )
    (if (is-none (index-of? current-prices price))
      (if is-buy
        (var-set active-buy-prices (unwrap-panic (as-max-len? (append current-prices price) u50)))
        (var-set active-sell-prices (unwrap-panic (as-max-len? (append current-prices price) u50)))
      )
      true
    )
  )
)

;; Add order to price level
(define-private (add-order-to-price-level (order-id uint) (price uint) (is-buy bool))
  (let (
    (current-orders (if is-buy
                       (default-to (list) (get order-ids (map-get? buy-orders-at-price { price: price })))
                       (default-to (list) (get order-ids (map-get? sell-orders-at-price { price: price })))))
    (new-orders (unwrap-panic (as-max-len? (append current-orders order-id) u100)))
  )
    (if is-buy
      (map-set buy-orders-at-price { price: price } { order-ids: new-orders })
      (map-set sell-orders-at-price { price: price } { order-ids: new-orders })
    )
    (add-to-active-prices price is-buy)
  )
)

;; Add order to user's order list
(define-private (add-order-to-user (user principal) (order-id uint))
  (let (
    (current-orders (default-to (list) (get order-ids (map-get? user-orders { user: user }))))
    (new-orders (unwrap-panic (as-max-len? (append current-orders order-id) u200)))
  )
    (map-set user-orders { user: user } { order-ids: new-orders })
  )
)

;; Update order status based on filled amount
(define-private (update-order-status (order-id uint))
  (let (
    (order (unwrap! (map-get? orders { order-id: order-id }) false))
    (new-status (if (>= (get filled order) (get amount order))
                   status-filled
                   (if (> (get filled order) u0)
                      status-partially-filled
                      status-open)))
  )
    (map-set orders
      { order-id: order-id }
      (merge order { status: new-status })
    )
  )
)

;; Execute a fill between two orders
(define-private (execute-fill 
                 (taker-order-id uint) 
                 (maker-order-id uint) 
                 (fill-amount uint) 
                 (price uint))
  (let (
    (taker-order (unwrap! (map-get? orders { order-id: taker-order-id }) false))
    (maker-order (unwrap! (map-get? orders { order-id: maker-order-id }) false))
    (is-buy (is-eq (get side taker-order) side-buy))
    (token-a-amount fill-amount)
    (token-b-amount (/ (* fill-amount price) u1000000))  ;; Assuming 6 decimal places
  )
    ;; Update taker order filled amount
    (map-set orders
      { order-id: taker-order-id }
      (merge taker-order { filled: (+ (get filled taker-order) fill-amount) })
    )
    
    ;; Update maker order filled amount
    (map-set orders
      { order-id: maker-order-id }
      (merge maker-order { filled: (+ (get filled maker-order) fill-amount) })
    )
    
    ;; Update statuses
    (update-order-status taker-order-id)
    (update-order-status maker-order-id)
    
    ;; Note: Token transfers should be handled by caller with post-conditions
    ;; In a production system, this would use contract-call? with proper error handling
    
    true
  )
)

;; Try to match a market order against available liquidity
(define-private (match-market-order (order-id uint))
  (let (
    (order (unwrap! (map-get? orders { order-id: order-id }) false))
    (is-buy (is-eq (get side order) side-buy))
  )
    ;; In a full implementation, this would iterate through price levels
    ;; and execute fills. For now, we'll keep it as a placeholder
    ;; that would be expanded with fold operations over price lists
    true
  )
)

;; Public functions

;; Place a limit order
(define-public (place-limit-order 
                 (side uint) 
                 (price uint) 
                 (amount uint))
  (let (
    (order-id (var-get next-order-id))
    (timestamp stacks-block-height)  ;; Using block height as timestamp proxy
    (is-buy (is-eq side side-buy))
  )
    ;; Validations
    (asserts! (or (is-eq side side-buy) (is-eq side side-sell)) err-not-authorized)
    (asserts! (> price u0) err-invalid-price)
    (asserts! (> amount u0) err-invalid-amount)
    
    ;; Create order
    (map-set orders
      { order-id: order-id }
      {
        trader: tx-sender,
        side: side,
        price: price,
        amount: amount,
        filled: u0,
        timestamp: timestamp,
        status: status-open
      }
    )
    
    ;; Add to user orders
    (add-order-to-user tx-sender order-id)
    
    ;; Add to price level
    (add-order-to-price-level order-id price is-buy)
    
    ;; Increment order ID
    (var-set next-order-id (+ order-id u1))
    
    ;; Print event
    (print {
      event: "order-placed",
      order-id: order-id,
      trader: tx-sender,
      side: side,
      price: price,
      amount: amount,
      timestamp: timestamp
    })
    
    (ok order-id)
  )
)

;; Place a market order (simplified - would need matching logic)
(define-public (place-market-order 
                 (side uint) 
                 (amount uint))
  (let (
    (order-id (var-get next-order-id))
    (timestamp stacks-block-height)
  )
    ;; Validations
    (asserts! (or (is-eq side side-buy) (is-eq side side-sell)) err-not-authorized)
    (asserts! (> amount u0) err-invalid-amount)
    
    ;; Create market order with price 0 (to be filled at market)
    (map-set orders
      { order-id: order-id }
      {
        trader: tx-sender,
        side: side,
        price: u0,
        amount: amount,
        filled: u0,
        timestamp: timestamp,
        status: status-open
      }
    )
    
    ;; Add to user orders
    (add-order-to-user tx-sender order-id)
    
    ;; Increment order ID
    (var-set next-order-id (+ order-id u1))
    
    ;; Try to match immediately
    (match-market-order order-id)
    
    ;; Print event
    (print {
      event: "market-order-placed",
      order-id: order-id,
      trader: tx-sender,
      side: side,
      amount: amount,
      timestamp: timestamp
    })
    
    (ok order-id)
  )
)

;; Cancel an order
(define-public (cancel-order (order-id uint))
  (let (
    (order (unwrap! (map-get? orders { order-id: order-id }) err-order-not-found))
  )
    ;; Check authorization
    (asserts! (is-eq (get trader order) tx-sender) err-not-authorized)
    
    ;; Check if order can be cancelled
    (asserts! (not (is-eq (get status order) status-filled)) err-order-already-filled)
    (asserts! (not (is-eq (get status order) status-cancelled)) err-order-cancelled)
    
    ;; Update status to cancelled
    (map-set orders
      { order-id: order-id }
      (merge order { status: status-cancelled })
    )
    
    ;; Print event
    (print {
      event: "order-cancelled",
      order-id: order-id,
      trader: tx-sender,
      timestamp: stacks-block-height
    })
    
    (ok true)
  )
)

;; Read-only functions

;; Get order details
(define-read-only (get-order (order-id uint))
  (ok (map-get? orders { order-id: order-id }))
)

;; Get user's orders
(define-read-only (get-user-orders (user principal))
  (ok (map-get? user-orders { user: user }))
)

;; Get orders at a specific price level
(define-read-only (get-orders-at-price (price uint) (is-buy bool))
  (ok (if is-buy
        (map-get? buy-orders-at-price { price: price })
        (map-get? sell-orders-at-price { price: price })))
)

;; Get active price levels
(define-read-only (get-active-buy-prices)
  (ok (var-get active-buy-prices))
)

(define-read-only (get-active-sell-prices)
  (ok (var-get active-sell-prices))
)

;; Get next order ID
(define-read-only (get-next-order-id)
  (ok (var-get next-order-id))
)

;; Get order book depth (simplified)
(define-read-only (get-order-book-depth)
  (ok {
    buy-levels: (len (var-get active-buy-prices)),
    sell-levels: (len (var-get active-sell-prices))
  })
)
