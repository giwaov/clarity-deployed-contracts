;; DEX Order Book Contract
;; Limit orders for token trading

(define-constant err-insufficient-balance (err u100))
(define-constant err-order-not-found (err u101))
(define-constant err-not-owner (err u102))
(define-constant err-order-filled (err u103))

(define-data-var order-nonce uint u0)

(define-map orders
    uint
    {
        maker: principal,
        sell-amount: uint,
        buy-amount: uint,
        filled-amount: uint,
        price: uint,
        is-buy: bool,
        active: bool,
        timestamp: uint
    }
)

(define-public (create-limit-order
    (sell-amount uint)
    (buy-amount uint)
    (is-buy bool))
    (let
        (
            (order-id (var-get order-nonce))
            (price (/ (* buy-amount u1000000) sell-amount))
        )
        (try! (stx-transfer? sell-amount tx-sender (as-contract tx-sender)))
        
        (map-set orders order-id {
            maker: tx-sender,
            sell-amount: sell-amount,
            buy-amount: buy-amount,
            filled-amount: u0,
            price: price,
            is-buy: is-buy,
            active: true,
            timestamp: block-height
        })
        (var-set order-nonce (+ order-id u1))
        (ok order-id)
    )
)

(define-public (fill-order (order-id uint) (fill-amount uint))
    (let
        (
            (order (unwrap! (map-get? orders order-id) err-order-not-found))
            (remaining-amount (- (get sell-amount order) (get filled-amount order)))
            (amount-to-fill (if (> fill-amount remaining-amount) remaining-amount fill-amount))
            (buy-amount-required (/ (* amount-to-fill (get buy-amount order)) (get sell-amount order)))
        )
        (asserts! (get active order) err-order-filled)
        (asserts! (> remaining-amount u0) err-order-filled)
        
        (try! (stx-transfer? buy-amount-required tx-sender (get maker order)))
        (try! (as-contract (stx-transfer? amount-to-fill tx-sender tx-sender)))
        
        (let ((new-filled-amount (+ (get filled-amount order) amount-to-fill)))
            (map-set orders order-id (merge order {
                filled-amount: new-filled-amount,
                active: (< new-filled-amount (get sell-amount order))
            }))
        )
        (ok amount-to-fill)
    )
)

(define-public (cancel-order (order-id uint))
    (let
        (
            (order (unwrap! (map-get? orders order-id) err-order-not-found))
            (remaining-amount (- (get sell-amount order) (get filled-amount order)))
        )
        (asserts! (is-eq tx-sender (get maker order)) err-not-owner)
        (asserts! (get active order) err-order-filled)
        
        (if (> remaining-amount u0)
            (try! (as-contract (stx-transfer? remaining-amount tx-sender (get maker order))))
            true
        )
        
        (map-set orders order-id (merge order {active: false}))
        (ok remaining-amount)
    )
)

(define-read-only (get-order (order-id uint))
    (map-get? orders order-id)
)

(define-read-only (get-remaining-amount (order-id uint))
    (match (map-get? orders order-id)
        order (- (get sell-amount order) (get filled-amount order))
        u0
    )
)

(define-read-only (is-order-active (order-id uint))
    (match (map-get? orders order-id)
        order (get active order)
        false
    )
)
