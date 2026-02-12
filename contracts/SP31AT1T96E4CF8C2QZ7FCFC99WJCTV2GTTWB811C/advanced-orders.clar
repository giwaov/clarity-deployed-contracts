;; Advanced Order Types Contract
;; Supports stop-loss, take-profit, and TWAP orders
;; Uses Clarity 4 features: block timestamps for time-based logic

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-authorized (err u201))
(define-constant err-order-not-found (err u202))
(define-constant err-invalid-params (err u203))
(define-constant err-too-early (err u204))
(define-constant err-condition-not-met (err u205))
(define-constant err-already-triggered (err u206))

;; Advanced order types
(define-constant type-stop-loss u1)
(define-constant type-take-profit u2)
(define-constant type-twap u3)

;; Advanced order status
(define-constant adv-status-pending u1)
(define-constant adv-status-triggered u2)
(define-constant adv-status-executing u3)
(define-constant adv-status-completed u4)
(define-constant adv-status-cancelled u5)

;; Data Variables
(define-data-var next-advanced-order-id uint u1)
(define-data-var current-market-price uint u1000000)  ;; Price oracle (simplified)

;; Stop-loss / Take-profit orders
(define-map conditional-orders
  { order-id: uint }
  {
    trader: principal,
    order-type: uint,  ;; 1 = stop-loss, 2 = take-profit
    trigger-price: uint,
    amount: uint,
    status: uint,
    created-at: uint,
    triggered-at: (optional uint)
  }
)

;; TWAP orders - Time-Weighted Average Price
(define-map twap-orders
  { order-id: uint }
  {
    trader: principal,
    total-amount: uint,
    executed-amount: uint,
    num-chunks: uint,
    executed-chunks: uint,
    interval-seconds: uint,  ;; Time between chunks
    start-time: uint,
    last-execution: uint,
    status: uint
  }
)

;; User's advanced orders
(define-map user-advanced-orders
  { user: principal }
  { order-ids: (list 100 uint) }
)

;; Private helper functions

;; Check if stop-loss condition is met
(define-private (is-stop-loss-triggered (trigger-price uint))
  (let (
    (market-price (var-get current-market-price))
  )
    (<= market-price trigger-price)
  )
)

;; Check if take-profit condition is met
(define-private (is-take-profit-triggered (trigger-price uint))
  (let (
    (market-price (var-get current-market-price))
  )
    (>= market-price trigger-price)
  )
)

;; Calculate TWAP chunk size
(define-private (calculate-twap-chunk (total-amount uint) (num-chunks uint))
  (/ total-amount num-chunks)
)

;; Check if enough time has passed for next TWAP execution
(define-private (can-execute-next-twap-chunk 
                 (last-execution uint) 
                 (interval-seconds uint))
  (let (
    (current-time stacks-block-height)  ;; Clarity 4 feature
    (time-since-last (- current-time last-execution))
  )
    (>= time-since-last interval-seconds)
  )
)

;; Add order to user's advanced order list
(define-private (add-advanced-order-to-user (user principal) (order-id uint))
  (let (
    (current-orders (default-to (list) 
                      (get order-ids (map-get? user-advanced-orders { user: user }))))
    (new-orders (unwrap-panic (as-max-len? (append current-orders order-id) u100)))
  )
    (map-set user-advanced-orders { user: user } { order-ids: new-orders })
  )
)

;; Public functions

;; Create a stop-loss order
(define-public (create-stop-loss-order 
                 (trigger-price uint) 
                 (amount uint))
  (let (
    (order-id (var-get next-advanced-order-id))
    (timestamp stacks-block-height)
  )
    ;; Validations
    (asserts! (> trigger-price u0) err-invalid-params)
    (asserts! (> amount u0) err-invalid-params)
    
    ;; Create order
    (map-set conditional-orders
      { order-id: order-id }
      {
        trader: tx-sender,
        order-type: type-stop-loss,
        trigger-price: trigger-price,
        amount: amount,
        status: adv-status-pending,
        created-at: timestamp,
        triggered-at: none
      }
    )
    
    ;; Add to user orders
    (add-advanced-order-to-user tx-sender order-id)
    
    ;; Increment order ID
    (var-set next-advanced-order-id (+ order-id u1))
    
    ;; Print event
    (print {
      event: "stop-loss-created",
      order-id: order-id,
      trader: tx-sender,
      trigger-price: trigger-price,
      amount: amount,
      timestamp: timestamp
    })
    
    (ok order-id)
  )
)

;; Create a take-profit order
(define-public (create-take-profit-order 
                 (trigger-price uint) 
                 (amount uint))
  (let (
    (order-id (var-get next-advanced-order-id))
    (timestamp stacks-block-height)
  )
    ;; Validations
    (asserts! (> trigger-price u0) err-invalid-params)
    (asserts! (> amount u0) err-invalid-params)
    
    ;; Create order
    (map-set conditional-orders
      { order-id: order-id }
      {
        trader: tx-sender,
        order-type: type-take-profit,
        trigger-price: trigger-price,
        amount: amount,
        status: adv-status-pending,
        created-at: timestamp,
        triggered-at: none
      }
    )
    
    ;; Add to user orders
    (add-advanced-order-to-user tx-sender order-id)
    
    ;; Increment order ID
    (var-set next-advanced-order-id (+ order-id u1))
    
    ;; Print event
    (print {
      event: "take-profit-created",
      order-id: order-id,
      trader: tx-sender,
      trigger-price: trigger-price,
      amount: amount,
      timestamp: timestamp
    })
    
    (ok order-id)
  )
)

;; Create a TWAP order
(define-public (create-twap-order 
                 (total-amount uint) 
                 (num-chunks uint) 
                 (interval-seconds uint))
  (let (
    (order-id (var-get next-advanced-order-id))
    (timestamp stacks-block-height)
  )
    ;; Validations
    (asserts! (> total-amount u0) err-invalid-params)
    (asserts! (> num-chunks u0) err-invalid-params)
    (asserts! (> interval-seconds u0) err-invalid-params)
    (asserts! (<= num-chunks u100) err-invalid-params)  ;; Max 100 chunks
    
    ;; Create TWAP order
    (map-set twap-orders
      { order-id: order-id }
      {
        trader: tx-sender,
        total-amount: total-amount,
        executed-amount: u0,
        num-chunks: num-chunks,
        executed-chunks: u0,
        interval-seconds: interval-seconds,
        start-time: timestamp,
        last-execution: timestamp,
        status: adv-status-pending
      }
    )
    
    ;; Add to user orders
    (add-advanced-order-to-user tx-sender order-id)
    
    ;; Increment order ID
    (var-set next-advanced-order-id (+ order-id u1))
    
    ;; Print event
    (print {
      event: "twap-order-created",
      order-id: order-id,
      trader: tx-sender,
      total-amount: total-amount,
      num-chunks: num-chunks,
      interval-seconds: interval-seconds,
      timestamp: timestamp
    })
    
    (ok order-id)
  )
)

;; Try to trigger a conditional order (stop-loss or take-profit)
(define-public (try-trigger-conditional-order (order-id uint))
  (let (
    (order (unwrap! (map-get? conditional-orders { order-id: order-id }) 
                    err-order-not-found))
    (is-stop-loss (is-eq (get order-type order) type-stop-loss))
    (is-triggered (if is-stop-loss
                     (is-stop-loss-triggered (get trigger-price order))
                     (is-take-profit-triggered (get trigger-price order))))
  )
    ;; Check if order is pending
    (asserts! (is-eq (get status order) adv-status-pending) err-already-triggered)
    
    ;; Check if condition is met
    (asserts! is-triggered err-condition-not-met)
    
    ;; Update order status
    (map-set conditional-orders
      { order-id: order-id }
      (merge order { 
        status: adv-status-triggered,
        triggered-at: (some stacks-block-height)
      })
    )
    
    ;; In a full implementation, this would call the order book to place a market order
    ;; For now, we just mark it as triggered
    
    ;; Print event
    (print {
      event: "conditional-order-triggered",
      order-id: order-id,
      order-type: (get order-type order),
      trigger-price: (get trigger-price order),
      market-price: (var-get current-market-price),
      timestamp: stacks-block-height
    })
    
    (ok true)
  )
)

;; Execute next chunk of a TWAP order
(define-public (execute-twap-chunk (order-id uint))
  (let (
    (order (unwrap! (map-get? twap-orders { order-id: order-id }) 
                    err-order-not-found))
    (chunk-size (calculate-twap-chunk (get total-amount order) (get num-chunks order)))
  )
    ;; Check authorization
    (asserts! (is-eq (get trader order) tx-sender) err-not-authorized)
    
    ;; Check if all chunks executed
    (asserts! (< (get executed-chunks order) (get num-chunks order)) 
              err-condition-not-met)
    
    ;; Check if enough time has passed
    (asserts! (can-execute-next-twap-chunk 
                (get last-execution order) 
                (get interval-seconds order))
              err-too-early)
    
    ;; Update order
    (map-set twap-orders
      { order-id: order-id }
      (merge order {
        executed-amount: (+ (get executed-amount order) chunk-size),
        executed-chunks: (+ (get executed-chunks order) u1),
        last-execution: stacks-block-height,
        status: (if (is-eq (+ (get executed-chunks order) u1) (get num-chunks order))
                   adv-status-completed
                   adv-status-executing)
      })
    )
    
    ;; In a full implementation, this would call the order book to place a market order
    ;; for the chunk-size amount
    
    ;; Print event
    (print {
      event: "twap-chunk-executed",
      order-id: order-id,
      chunk-size: chunk-size,
      executed-chunks: (+ (get executed-chunks order) u1),
      total-chunks: (get num-chunks order),
      timestamp: stacks-block-height
    })
    
    (ok chunk-size)
  )
)

;; Cancel an advanced order
(define-public (cancel-advanced-order (order-id uint) (is-twap bool))
  (if is-twap
    (let (
      (order (unwrap! (map-get? twap-orders { order-id: order-id }) 
                      err-order-not-found))
    )
      (asserts! (is-eq (get trader order) tx-sender) err-not-authorized)
      (map-set twap-orders
        { order-id: order-id }
        (merge order { status: adv-status-cancelled })
      )
      (ok true)
    )
    (let (
      (order (unwrap! (map-get? conditional-orders { order-id: order-id }) 
                      err-order-not-found))
    )
      (asserts! (is-eq (get trader order) tx-sender) err-not-authorized)
      (map-set conditional-orders
        { order-id: order-id }
        (merge order { status: adv-status-cancelled })
      )
      (ok true)
    )
  )
)

;; Update market price (simplified oracle - in production would use Redstone/Pyth)
(define-public (update-market-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set current-market-price new-price)
    (print { event: "price-updated", price: new-price, timestamp: stacks-block-height })
    (ok true)
  )
)

;; Read-only functions

;; Get conditional order
(define-read-only (get-conditional-order (order-id uint))
  (ok (map-get? conditional-orders { order-id: order-id }))
)

;; Get TWAP order
(define-read-only (get-twap-order (order-id uint))
  (ok (map-get? twap-orders { order-id: order-id }))
)

;; Get user's advanced orders
(define-read-only (get-user-advanced-orders (user principal))
  (ok (map-get? user-advanced-orders { user: user }))
)

;; Get current market price
(define-read-only (get-market-price)
  (ok (var-get current-market-price))
)

;; Get next advanced order ID
(define-read-only (get-next-advanced-order-id)
  (ok (var-get next-advanced-order-id))
)
