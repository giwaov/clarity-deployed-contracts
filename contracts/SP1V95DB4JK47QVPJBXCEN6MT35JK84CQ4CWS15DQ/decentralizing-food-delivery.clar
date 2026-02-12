(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))
(define-constant err-courier-busy (err u128))

(define-data-var order-nonce uint u0)

(define-map delivery-orders
  uint
  {
    customer: principal,
    restaurant: principal,
    courier: principal,
    pickup-location: (buff 32),
    delivery-location: (buff 32),
    order-value: uint,
    delivery-fee: uint,
    status: (string-ascii 20),
    placed-block: uint,
    delivered-block: uint
  }
)

(define-map couriers
  principal
  {
    active: bool,
    total-deliveries: uint,
    earnings: uint,
    rating: uint,
    location-hash: (buff 32),
    available: bool
  }
)

(define-map restaurants
  principal
  {
    name: (string-ascii 50),
    location-hash: (buff 32),
    total-orders: uint,
    revenue: uint,
    rating: uint,
    active: bool
  }
)

(define-map customer-orders principal (list 100 uint))
(define-map courier-deliveries principal (list 200 uint))

(define-public (register-courier (location (buff 32)))
  (begin
    (map-set couriers tx-sender {
      active: true,
      total-deliveries: u0,
      earnings: u0,
      rating: u100,
      location-hash: location,
      available: true
    })
    (ok true)
  )
)

(define-public (register-restaurant (name (string-ascii 50)) (location (buff 32)))
  (begin
    (map-set restaurants tx-sender {
      name: name,
      location-hash: location,
      total-orders: u0,
      revenue: u0,
      rating: u100,
      active: true
    })
    (ok true)
  )
)

(define-public (place-order (restaurant principal) (pickup-loc (buff 32)) (delivery-loc (buff 32)) 
                             (value uint) (fee uint))
  (let
    (
      (order-id (+ (var-get order-nonce) u1))
      (restaurant-data (unwrap! (map-get? restaurants restaurant) err-not-found))
    )
    (asserts! (get active restaurant-data) err-not-found)
    (map-set delivery-orders order-id {
      customer: tx-sender,
      restaurant: restaurant,
      courier: tx-sender,
      pickup-location: pickup-loc,
      delivery-location: delivery-loc,
      order-value: value,
      delivery-fee: fee,
      status: "pending",
      placed-block: stacks-block-height,
      delivered-block: u0
    })
    (map-set customer-orders tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? customer-orders tx-sender)) order-id) u100)))
    (var-set order-nonce order-id)
    (ok order-id)
  )
)

(define-public (accept-delivery (order-id uint))
  (let
    (
      (order (unwrap! (map-get? delivery-orders order-id) err-not-found))
      (courier-data (unwrap! (map-get? couriers tx-sender) err-not-found))
    )
    (asserts! (get available courier-data) err-courier-busy)
    (map-set delivery-orders order-id (merge order {courier: tx-sender, status: "accepted"}))
    (map-set couriers tx-sender (merge courier-data {available: false}))
    (map-set courier-deliveries tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? courier-deliveries tx-sender)) order-id) u200)))
    (ok true)
  )
)

(define-public (complete-delivery (order-id uint))
  (let
    (
      (order (unwrap! (map-get? delivery-orders order-id) err-not-found))
      (courier-data (unwrap! (map-get? couriers tx-sender) err-not-found))
      (restaurant-data (unwrap! (map-get? restaurants (get restaurant order)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get courier order)) err-unauthorized)
    (try! (stx-transfer? (get delivery-fee order) (get customer order) tx-sender))
    (map-set delivery-orders order-id (merge order {
      status: "delivered",
      delivered-block: stacks-block-height
    }))
    (map-set couriers tx-sender (merge courier-data {
      total-deliveries: (+ (get total-deliveries courier-data) u1),
      earnings: (+ (get earnings courier-data) (get delivery-fee order)),
      available: true
    }))
    (map-set restaurants (get restaurant order) (merge restaurant-data {
      total-orders: (+ (get total-orders restaurant-data) u1),
      revenue: (+ (get revenue restaurant-data) (get order-value order))
    }))
    (ok true)
  )
)

(define-read-only (get-order (order-id uint))
  (ok (map-get? delivery-orders order-id))
)

(define-read-only (get-courier (courier principal))
  (ok (map-get? couriers courier))
)

(define-read-only (get-restaurant (restaurant principal))
  (ok (map-get? restaurants restaurant))
)

(define-read-only (get-customer-orders (customer principal))
  (ok (map-get? customer-orders customer))
)

(define-read-only (get-courier-deliveries (courier principal))
  (ok (map-get? courier-deliveries courier))
)
