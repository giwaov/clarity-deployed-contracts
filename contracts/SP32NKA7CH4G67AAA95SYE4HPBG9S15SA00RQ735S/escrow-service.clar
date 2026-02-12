;; title: escrow-service
;; version:
;; summary:
;; description:

;; Commodities Trading Contract
;; Implements secure trading of commodities with price feeds, escrow, and trading functionality

;; Error codes
(define-constant ERROR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERROR-INVALID-COMMODITY-PRICE (err u101))
(define-constant ERROR-INSUFFICIENT-ESCROW-BALANCE (err u102))
(define-constant ERROR-TRADING-DISABLED (err u103))
(define-constant ERROR-INVALID-TRADE-QUANTITY (err u104))
(define-constant ERROR-ESCROW-TRANSACTION-FAILED (err u105))
(define-constant ERROR-INVALID-INPUT (err u106))

;; Data Variables
(define-data-var contract-administrator principal tx-sender)
(define-data-var commodity-price-oracle principal tx-sender)
(define-data-var market-trading-status bool true)
(define-data-var minimum-trade-quantity uint u100)

;; Data Maps
(define-map available-commodities-inventory
  { commodity-identifier: uint }
  {
    available-quantity: uint,
    current-market-price: uint,
    commodity-owner: principal,
  }
)

(define-map active-trading-positions
  {
    trader-address: principal,
    trade-position-id: uint,
  }
  {
    commodity-identifier: uint,
    traded-quantity: uint,
    position-entry-price: uint,
    position-creation-timestamp: uint,
  }
)

(define-map trader-escrow-accounts
  { trader-address: principal }
  { escrow-balance: uint }
)

;; Read-only functions
(define-read-only (get-commodity-market-data (commodity-identifier uint))
  (match (map-get? available-commodities-inventory { commodity-identifier: commodity-identifier })
    commodity-market-data (ok commodity-market-data)
    (err u404)
  )
)

(define-read-only (get-trader-position-details
    (trader-address principal)
    (trade-position-id uint)
  )
  (match (map-get? active-trading-positions {
    trader-address: trader-address,
    trade-position-id: trade-position-id,
  })
    trader-position-data (ok trader-position-data)
    (err u404)
  )
)

(define-read-only (get-trader-escrow-balance (trader-address principal))
  (match (map-get? trader-escrow-accounts { trader-address: trader-address })
    escrow-account-data (ok (get escrow-balance escrow-account-data))
    (err u404)
  )
)

;; Private functions
(define-private (verify-administrator-access (caller-address principal))
  (if (is-eq caller-address (var-get contract-administrator))
    (ok true)
    ERROR-UNAUTHORIZED-ACCESS
  )
)

(define-private (validate-trade-parameters
    (trade-quantity uint)
    (trade-price uint)
  )
  (if (and
      (>= trade-quantity (var-get minimum-trade-quantity))
      (> trade-price u0)
    )
    (ok true)
    ERROR-INVALID-TRADE-QUANTITY
  )
)

(define-private (validate-uint (value uint))
  (> value u0)
)

;; Public functions
(define-public (update-price-oracle-address (new-oracle-address principal))
  (begin
    (try! (verify-administrator-access tx-sender))
    (asserts! (is-some (some new-oracle-address)) ERROR-INVALID-INPUT)
    (ok (var-set commodity-price-oracle new-oracle-address))
  )
)

(define-public (toggle-market-trading-status)
  (begin
    (try! (verify-administrator-access tx-sender))
    (ok (var-set market-trading-status (not (var-get market-trading-status))))
  )
)

(define-public (register-new-commodity
    (commodity-identifier uint)
    (initial-available-quantity uint)
    (initial-market-price uint)
  )
  (begin
    (try! (verify-administrator-access tx-sender))
    (asserts! (validate-uint commodity-identifier) ERROR-INVALID-INPUT)
    (asserts! (validate-uint initial-available-quantity) ERROR-INVALID-INPUT)
    (asserts! (validate-uint initial-market-price) ERROR-INVALID-INPUT)
    (try! (validate-trade-parameters initial-available-quantity initial-market-price))
    (map-set available-commodities-inventory { commodity-identifier: commodity-identifier } {
      available-quantity: initial-available-quantity,
      current-market-price: initial-market-price,
      commodity-owner: tx-sender,
    })
    (ok true)
  )
)

(define-public (execute-trade
    (commodity-identifier uint)
    (trade-quantity uint)
    (trade-position-id uint)
  )
  (let (
      (commodity-data (unwrap! (get-commodity-market-data commodity-identifier)
        ERROR-INVALID-COMMODITY-PRICE
      ))
      (current-market-price (get current-market-price commodity-data))
      (total-trade-cost (* trade-quantity current-market-price))
    )
    (begin
      (asserts! (var-get market-trading-status) ERROR-TRADING-DISABLED)
      (asserts! (validate-uint commodity-identifier) ERROR-INVALID-INPUT)
      (asserts! (validate-uint trade-quantity) ERROR-INVALID-INPUT)
      (asserts! (validate-uint trade-position-id) ERROR-INVALID-INPUT)
      (try! (validate-trade-parameters trade-quantity current-market-price))

      ;; Check escrow balance
      (match (map-get? trader-escrow-accounts { trader-address: tx-sender })
        escrow-account-data (if (>= (get escrow-balance escrow-account-data) total-trade-cost)
          (begin
            ;; Update escrow balance
            (map-set trader-escrow-accounts { trader-address: tx-sender } { escrow-balance: (- (get escrow-balance escrow-account-data) total-trade-cost) })

            ;; Record trading position
            (map-set active-trading-positions {
              trader-address: tx-sender,
              trade-position-id: trade-position-id,
            } {
              commodity-identifier: commodity-identifier,
              traded-quantity: trade-quantity,
              position-entry-price: current-market-price,
              position-creation-timestamp: stacks-block-height,
            })
            (ok true)
          )
          ERROR-INSUFFICIENT-ESCROW-BALANCE
        )
        ERROR-INSUFFICIENT-ESCROW-BALANCE
      )
    )
  )
)

(define-public (close-trading-position (trade-position-id uint))
  (let (
      (position-data (unwrap! (get-trader-position-details tx-sender trade-position-id)
        ERROR-INVALID-TRADE-QUANTITY
      ))
      (commodity-data (unwrap!
        (get-commodity-market-data (get commodity-identifier position-data))
        ERROR-INVALID-COMMODITY-PRICE
      ))
      (current-market-price (get current-market-price commodity-data))
      (position-settlement-amount (* (get traded-quantity position-data) current-market-price))
    )
    (begin
      (asserts! (validate-uint trade-position-id) ERROR-INVALID-INPUT)
      ;; Return funds to escrow account
      (match (map-get? trader-escrow-accounts { trader-address: tx-sender })
        escrow-account-data (map-set trader-escrow-accounts { trader-address: tx-sender } { escrow-balance: (+ (get escrow-balance escrow-account-data) position-settlement-amount) })
        (map-set trader-escrow-accounts { trader-address: tx-sender } { escrow-balance: position-settlement-amount })
      )

      ;; Delete the position
      (map-delete active-trading-positions {
        trader-address: tx-sender,
        trade-position-id: trade-position-id,
      })
      (ok true)
    )
  )
)

;; Contract initialization
(define-public (initialize-contract (administrator-address principal))
  (begin
    (asserts! (is-some (some administrator-address)) ERROR-INVALID-INPUT)
    (var-set contract-administrator administrator-address)
    (var-set commodity-price-oracle administrator-address)
    (ok true)
  )
)
