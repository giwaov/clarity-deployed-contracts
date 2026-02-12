;; title: price-marketplace
;; version:
;; summary:
;; description:

;; Title: Volume Discount Marketplace Smart Contract
;; Description: A decentralized marketplace smart contract that enables merchants to sell products 
;; with automated volume-based discount tiers. The platform provides comprehensive inventory management, 
;; dynamic pricing calculations based on purchase quantities, secure payment processing, and detailed 
;; transaction tracking. Merchants can configure multiple discount tiers to incentivize bulk purchases, 
;; while customers benefit from transparent pricing and automatic discount application.

;; ERROR CONSTANTS

(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-PRODUCT-ALREADY-EXISTS (err u101))
(define-constant ERR-PRODUCT-NOT-FOUND (err u102))
(define-constant ERR-INVALID-DISCOUNT-RATE (err u103))
(define-constant ERR-INVALID-PRICE-AMOUNT (err u104))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u105))
(define-constant ERR-INVALID-QUANTITY-REQUESTED (err u106))
(define-constant ERR-TRANSACTION-PROCESSING-FAILED (err u107))
(define-constant ERR-MARKETPLACE-LOCKED (err u108))
(define-constant ERR-EMPTY-PURCHASE-LIST (err u109))
(define-constant ERR-INVALID-INPUT-PARAMETER (err u110))
(define-constant ERR-INVALID-PRODUCT-NAME (err u111))
(define-constant ERR-INSUFFICIENT-STOCK (err u112))

;; BUSINESS LOGIC CONSTANTS

(define-constant maximum-product-name-length u64)
(define-constant maximum-quantity-per-order u1000000)
(define-constant maximum-price-per-unit u1000000000)
(define-constant maximum-discount-percentage u100)
(define-constant maximum-bulk-order-items u10)
(define-constant minimum-product-name-length u1)
(define-constant minimum-quantity-amount u1)
(define-constant minimum-price-amount u1)

;; DATA STRUCTURES

;; Core product information with inventory tracking
(define-map marketplace-product-catalog
  { product-identifier: uint }
  {
    product-name: (string-ascii 64),
    unit-price: uint,
    stock-quantity: uint,
    is-active: bool,
  }
)

;; Volume discount configuration for bulk purchasing incentives
(define-map volume-discount-configuration
  {
    product-identifier: uint,
    minimum-quantity-threshold: uint,
  }
  {
    discount-percentage: uint,
    is-tier-active: bool,
  }
)

;; Customer transaction history for purchase tracking
(define-map customer-transaction-records
  {
    customer-address: principal,
    transaction-identifier: uint,
  }
  {
    product-identifier: uint,
    quantity-purchased: uint,
    total-amount-paid: uint,
    block-height-created: uint,
    discount-percentage-applied: uint,
  }
)

;; CONTRACT STATE VARIABLES

(define-data-var marketplace-owner-address principal tx-sender)
(define-data-var is-marketplace-operational bool true)
(define-data-var next-available-product-id uint u1)
(define-data-var next-available-transaction-id uint u1)
(define-data-var total-marketplace-revenue uint u0)
(define-data-var total-completed-transactions uint u0)

;; INPUT VALIDATION UTILITIES

(define-private (validate-product-identifier (product-id uint))
  (and
    (>= product-id u1)
    (< product-id (var-get next-available-product-id))
  )
)

(define-private (validate-quantity-amount (quantity uint))
  (and
    (>= quantity minimum-quantity-amount)
    (<= quantity maximum-quantity-per-order)
  )
)

(define-private (validate-price-amount (price uint))
  (and
    (>= price minimum-price-amount)
    (<= price maximum-price-per-unit)
  )
)

(define-private (validate-discount-percentage (discount uint))
  (<= discount maximum-discount-percentage)
)

(define-private (validate-product-name (name (string-ascii 64)))
  (and
    (>= (len name) minimum-product-name-length)
    (<= (len name) maximum-product-name-length)
  )
)

(define-private (validate-marketplace-operational)
  (var-get is-marketplace-operational)
)

(define-private (validate-owner-permissions)
  (is-eq tx-sender (var-get marketplace-owner-address))
)

;; PRODUCT INFORMATION QUERIES

(define-read-only (get-product-details (product-id uint))
  (if (validate-product-identifier product-id)
    (map-get? marketplace-product-catalog { product-identifier: product-id })
    none
  )
)

(define-read-only (get-applicable-volume-discount
    (product-id uint)
    (purchase-quantity uint)
  )
  (if (and (validate-product-identifier product-id) (validate-quantity-amount purchase-quantity))
    (default-to {
      discount-percentage: u0,
      is-tier-active: false,
    }
      (map-get? volume-discount-configuration {
        product-identifier: product-id,
        minimum-quantity-threshold: purchase-quantity,
      })
    )
    {
      discount-percentage: u0,
      is-tier-active: false,
    }
  )
)

(define-read-only (calculate-final-order-price
    (product-id uint)
    (requested-quantity uint)
  )
  (if (and (validate-product-identifier product-id) (validate-quantity-amount requested-quantity))
    (match (get-product-details product-id)
      product-info (let (
          (base-unit-price (get unit-price product-info))
          (volume-discount-info (get-applicable-volume-discount product-id requested-quantity))
          (applicable-discount-rate (get discount-percentage volume-discount-info))
          (discount-multiplier (- u100 applicable-discount-rate))
          (subtotal-amount (* base-unit-price requested-quantity))
          (final-discounted-price (/ (* subtotal-amount discount-multiplier) u100))
        )
        (ok {
          base-unit-price: base-unit-price,
          quantity-ordered: requested-quantity,
          discount-percentage-applied: applicable-discount-rate,
          final-total-price: final-discounted-price,
          original-subtotal: subtotal-amount,
        })
      )
      (err ERR-PRODUCT-NOT-FOUND)
    )
    (err ERR-INVALID-INPUT-PARAMETER)
  )
)

(define-read-only (get-transaction-history (transaction-id uint))
  (map-get? customer-transaction-records {
    customer-address: tx-sender,
    transaction-identifier: transaction-id,
  })
)

(define-read-only (get-marketplace-owner-address)
  (var-get marketplace-owner-address)
)

(define-read-only (get-marketplace-analytics)
  {
    total-revenue-generated: (var-get total-marketplace-revenue),
    total-transactions-completed: (var-get total-completed-transactions),
    marketplace-operational-status: (var-get is-marketplace-operational),
    next-product-id: (var-get next-available-product-id),
    next-transaction-id: (var-get next-available-transaction-id),
  }
)

;; PRODUCT EXISTENCE VERIFICATION

(define-private (verify-product-availability (product-id uint))
  (if (validate-product-identifier product-id)
    (match (get-product-details product-id)
      product-info (if (get is-active product-info)
        (ok true)
        (err ERR-PRODUCT-NOT-FOUND)
      )
      (err ERR-PRODUCT-NOT-FOUND)
    )
    (err ERR-INVALID-INPUT-PARAMETER)
  )
)

(define-private (verify-sufficient-stock
    (product-id uint)
    (required-quantity uint)
  )
  (match (get-product-details product-id)
    product-info (if (>= (get stock-quantity product-info) required-quantity)
      (ok true)
      (err ERR-INSUFFICIENT-STOCK)
    )
    (err ERR-PRODUCT-NOT-FOUND)
  )
)

;; PRODUCT CATALOG MANAGEMENT

(define-public (register-new-product
    (product-name (string-ascii 64))
    (unit-price uint)
    (initial-stock uint)
  )
  (begin
    ;; Permission and operational validations
    (asserts! (validate-owner-permissions) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-marketplace-operational) ERR-MARKETPLACE-LOCKED)

    ;; Input parameter validations
    (asserts! (validate-product-name product-name) ERR-INVALID-PRODUCT-NAME)
    (asserts! (validate-price-amount unit-price) ERR-INVALID-PRICE-AMOUNT)
    (asserts! (validate-quantity-amount initial-stock)
      ERR-INVALID-QUANTITY-REQUESTED
    )

    ;; Create new product entry
    (let ((current-product-id (var-get next-available-product-id)))
      (map-set marketplace-product-catalog { product-identifier: current-product-id } {
        product-name: product-name,
        unit-price: unit-price,
        stock-quantity: initial-stock,
        is-active: true,
      })

      ;; Update product identifier counter
      (var-set next-available-product-id (+ current-product-id u1))

      (ok current-product-id)
    )
  )
)
