;; title: auth-controller
;; version:
;; summary:
;; description:
;; Green Energy Trading Platform Contract
;; Handles trading of green energy credits, verification of production, and participant management

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INVALID-ENERGY-AMOUNT (err u101))
(define-constant ERR-INSUFFICIENT-ENERGY-BALANCE (err u102))
(define-constant ERR-ENERGY-PRODUCER-NOT-FOUND (err u103))
(define-constant ERR-ENERGY-CONSUMER-NOT-FOUND (err u104))
(define-constant ERR-PARTICIPANT-ALREADY-REGISTERED (err u105))
(define-constant ERR-INVALID-TRADE-STATUS (err u106))
(define-constant ERR-INVALID-ENERGY-PRICE (err u107))
(define-constant ERR-INVALID-PRODUCER-ADDRESS (err u108))

;; Data Maps
(define-map energy-producers
  principal
  {
    cumulative-energy-produced: uint,
    producer-verification-status: bool,
    producer-registration-timestamp: uint,
    energy-unit-price: uint,
  }
)

(define-map energy-consumers
  principal
  {
    cumulative-energy-purchased: uint,
    available-energy-credits: uint,
    consumer-registration-timestamp: uint,
  }
)

(define-map energy-trading-records
  uint
  {
    energy-seller: principal,
    energy-buyer: principal,
    energy-amount: uint,
    transaction-price: uint,
    transaction-timestamp: uint,
    trade-status: (string-ascii 20),
  }
)

;; Variables
(define-data-var energy-trade-sequence uint u0)
(define-data-var platform-administrator principal tx-sender)
(define-data-var minimum-tradeable-energy uint u100)
(define-data-var platform-commission-rate uint u2)
(define-data-var maximum-energy-price uint u1000000) ;; Set a reasonable maximum price

;; Read-only functions
(define-read-only (get-energy-producer-details (producer-address principal))
  (map-get? energy-producers producer-address)
)

(define-read-only (get-energy-consumer-details (consumer-address principal))
  (map-get? energy-consumers consumer-address)
)

(define-read-only (get-energy-trade-details (trade-identifier uint))
  (map-get? energy-trading-records trade-identifier)
)

(define-read-only (get-platform-commission-rate)
  (var-get platform-commission-rate)
)

;; Private functions
(define-private (calculate-platform-commission (energy-amount uint))
  (/ (* energy-amount (var-get platform-commission-rate)) u100)
)

(define-private (transfer-energy-credit-balance
    (seller-address principal)
    (buyer-address principal)
    (transfer-amount uint)
  )
  (let (
      (seller-details (unwrap! (map-get? energy-producers seller-address)
        ERR-ENERGY-PRODUCER-NOT-FOUND
      ))
      (buyer-details (unwrap! (map-get? energy-consumers buyer-address)
        ERR-ENERGY-CONSUMER-NOT-FOUND
      ))
    )
    (if (>= (get cumulative-energy-produced seller-details) transfer-amount)
      (begin
        (map-set energy-producers seller-address
          (merge seller-details { cumulative-energy-produced: (- (get cumulative-energy-produced seller-details) transfer-amount) })
        )
        (map-set energy-consumers buyer-address
          (merge buyer-details { available-energy-credits: (+ (get available-energy-credits buyer-details) transfer-amount) })
        )
        (ok true)
      )
      ERR-INSUFFICIENT-ENERGY-BALANCE
    )
  )
)

;; Public functions
(define-public (register-energy-producer (initial-energy-price uint))
  (let ((producer-address tx-sender))
    (asserts! (is-none (map-get? energy-producers producer-address))
      ERR-PARTICIPANT-ALREADY-REGISTERED
    )
    (asserts!
      (and (> initial-energy-price u0) (<= initial-energy-price (var-get maximum-energy-price)))
      ERR-INVALID-ENERGY-PRICE
    )
    (ok (map-set energy-producers producer-address {
      cumulative-energy-produced: u0,
      producer-verification-status: false,
      producer-registration-timestamp: stacks-block-height,
      energy-unit-price: initial-energy-price,
    }))
  )
)

(define-public (register-energy-consumer)
  (let ((consumer-address tx-sender))
    (asserts! (is-none (map-get? energy-consumers consumer-address))
      ERR-PARTICIPANT-ALREADY-REGISTERED
    )
    (ok (map-set energy-consumers consumer-address {
      cumulative-energy-purchased: u0,
      available-energy-credits: u0,
      consumer-registration-timestamp: stacks-block-height,
    }))
  )
)

(define-public (record-green-energy-production (production-amount uint))
  (let (
      (producer-address tx-sender)
      (producer-details (unwrap! (map-get? energy-producers producer-address)
        ERR-ENERGY-PRODUCER-NOT-FOUND
      ))
    )
    (asserts! (get producer-verification-status producer-details)
      ERR-UNAUTHORIZED-ACCESS
    )
    (ok (map-set energy-producers producer-address
      (merge producer-details { cumulative-energy-produced: (+ (get cumulative-energy-produced producer-details) production-amount) })
    ))
  )
)

(define-public (create-energy-trade
    (producer-address principal)
    (energy-amount uint)
  )
  (let (
      (buyer-address tx-sender)
      (producer-details (unwrap! (map-get? energy-producers producer-address)
        ERR-ENERGY-PRODUCER-NOT-FOUND
      ))
      (consumer-details (unwrap! (map-get? energy-consumers buyer-address)
        ERR-ENERGY-CONSUMER-NOT-FOUND
      ))
      (trade-identifier (+ (var-get energy-trade-sequence) u1))
      (total-transaction-price (* energy-amount (get energy-unit-price producer-details)))
    )
    (asserts! (is-some (map-get? energy-producers producer-address))
      ERR-INVALID-PRODUCER-ADDRESS
    )
    (asserts! (>= energy-amount (var-get minimum-tradeable-energy))
      ERR-INVALID-ENERGY-AMOUNT
    )
    (try! (transfer-energy-credit-balance producer-address buyer-address energy-amount))
    (var-set energy-trade-sequence trade-identifier)
    (ok (map-set energy-trading-records trade-identifier {
      energy-seller: producer-address,
      energy-buyer: buyer-address,
      energy-amount: energy-amount,
      transaction-price: total-transaction-price,
      transaction-timestamp: stacks-block-height,
      trade-status: "completed",
    }))
  )
)

;; Admin functions
(define-public (verify-energy-producer (producer-address principal))
  (let ((admin-address tx-sender))
    (asserts! (is-eq admin-address (var-get platform-administrator))
      ERR-UNAUTHORIZED-ACCESS
    )
    (asserts! (is-some (map-get? energy-producers producer-address))
      ERR-ENERGY-PRODUCER-NOT-FOUND
    )
    (match (map-get? energy-producers producer-address)
      producer-details (ok (map-set energy-producers producer-address
        (merge producer-details { producer-verification-status: true })
      ))
      ERR-ENERGY-PRODUCER-NOT-FOUND
    )
  )
)

(define-public (update-platform-commission-rate (new-commission-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator))
      ERR-UNAUTHORIZED-ACCESS
    )
    (asserts! (<= new-commission-rate u100) ERR-INVALID-ENERGY-AMOUNT)
    (ok (var-set platform-commission-rate new-commission-rate))
  )
)

(define-public (update-minimum-tradeable-energy (new-minimum-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator))
      ERR-UNAUTHORIZED-ACCESS
    )
    (asserts! (> new-minimum-amount u0) ERR-INVALID-ENERGY-AMOUNT)
    (ok (var-set minimum-tradeable-energy new-minimum-amount))
  )
)

;; Contract initialization
(begin
  (var-set energy-trade-sequence u0)
  (var-set minimum-tradeable-energy u100)
  (var-set platform-commission-rate u2)
  (var-set maximum-energy-price u1000000)
)
