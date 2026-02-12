;; title: identity-registry
;; version:
;; summary:
;; description:

;; Digital Asset Twin Registry - Blockchain-Based Physical Asset Representation Platform Contract
;; This smart contract enables creation, management, and trading of digital twins representing
;; physical assets with granular access controls, automated royalty payments, comprehensive
;; interaction logging, and decentralized marketplace functionality

(define-constant contract-administrator tx-sender)

;; Error constants for operation failures
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-ASSET-NOT-FOUND (err u101))
(define-constant ERR-ASSET-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-PRICE-VALUE (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant ERR-ASSET-NOT-FOR-SALE (err u105))
(define-constant ERR-CANNOT-PURCHASE-OWN-ASSET (err u106))
(define-constant ERR-INVALID-ROYALTY-PERCENTAGE (err u107))
(define-constant ERR-MARKETPLACE-LISTING-EXPIRED (err u108))
(define-constant ERR-INVALID-ACCESS-PERMISSION-LEVEL (err u109))
(define-constant ERR-ACCESS-PERMISSION-DENIED (err u110))
(define-constant ERR-INVALID-METADATA-FORMAT (err u111))
(define-constant ERR-ASSET-CURRENTLY-LOCKED (err u112))
(define-constant ERR-INVALID-FEE-PERCENTAGE (err u113))
(define-constant ERR-INVALID-FIELD-IDENTIFIER (err u114))
(define-constant ERR-INVALID-ASSET-IDENTIFIER (err u115))
(define-constant ERR-INVALID-TIME-DURATION (err u116))
(define-constant ERR-INVALID-PRINCIPAL-ADDRESS (err u117))
(define-constant ERR-INVALID-INTERACTION-TYPE (err u118))
(define-constant ERR-INVALID-DATA-HASH-FORMAT (err u119))

;; Business rule constants for validation
(define-constant maximum-royalty-basis-points u1000)
(define-constant maximum-platform-fee-basis-points u1000)
(define-constant maximum-asset-price-microstx u1000000000000)
(define-constant maximum-string-length u256)
(define-constant maximum-metadata-buffer-size u1024)
(define-constant maximum-listing-duration-in-blocks u525600)
(define-constant maximum-asset-identifier u4294967295)

;; Primary storage for digital twin asset records
(define-map asset-registry
  { asset-id: uint }
  {
    current-owner: principal,
    original-creator: principal,
    title: (string-ascii 64),
    description: (string-ascii 256),
    metadata-uri: (string-ascii 256),
    category: (string-ascii 32),
    creation-block-height: uint,
    last-update-block-height: uint,
    is-active: bool,
    is-transfer-locked: bool,
    access-permission-level: uint,
    creator-royalty-percentage: uint,
    total-interactions: uint,
    reputation-points: uint,
  }
)

;; Marketplace listing storage for asset sales
(define-map market-listings
  { asset-id: uint }
  {
    seller: principal,
    asking-price-ustx: uint,
    listing-created-at-block: uint,
    listing-expires-at-block: uint,
    is-listing-active: bool,
    optional-payment-token: (optional principal),
  }
)

;; Access control list for restricted asset permissions
(define-map asset-access-permissions
  {
    asset-id: uint,
    authorized-user: principal,
  }
  {
    permission-tier: uint,
    granted-by: principal,
    grant-block-height: uint,
    expiration-block-height: (optional uint),
  }
)

;; Historical log of all asset interactions
(define-map interaction-history
  {
    asset-id: uint,
    log-sequence: uint,
  }
  {
    interacting-user: principal,
    interaction-type: (string-ascii 32),
    interaction-block-height: uint,
    optional-data-hash: (optional (buff 32)),
  }
)

;; User profile and activity tracking
(define-map user-profiles
  { user-principal: principal }
  {
    display-name: (string-ascii 32),
    reputation-points: uint,
    assets-created-total: uint,
    assets-owned-total: uint,
    sales-volume-total: uint,
    purchases-volume-total: uint,
    registration-block-height: uint,
    is-verified: bool,
  }
)

;; Asset category taxonomy
(define-map category-registry
  { category-identifier: (string-ascii 32) }
  {
    category-description: (string-ascii 128),
    total-assets-in-category: uint,
    is-category-active: bool,
  }
)

;; Global platform state variables
(define-data-var next-available-asset-id uint u1)
(define-data-var next-available-log-sequence uint u1)
(define-data-var platform-fee-in-basis-points uint u250)
(define-data-var total-accumulated-platform-fees uint u0)
(define-data-var platform-total-assets-created uint u0)
(define-data-var platform-total-trading-volume uint u0)
(define-data-var is-marketplace-operational bool true)

;; Verify if caller is contract administrator
(define-private (verify-admin-privileges)
  (is-eq tx-sender contract-administrator)
)

;; Validate string length against maximum allowed
(define-private (is-string-length-valid
    (text-input (string-ascii 256))
    (max-allowed-length uint)
  )
  (<= (len text-input) max-allowed-length)
)

;; Validate price is within acceptable range
(define-private (is-price-valid (price-amount uint))
  (and (> price-amount u0) (<= price-amount maximum-asset-price-microstx))
)

;; Validate royalty percentage within limits
(define-private (is-royalty-valid (royalty-bps uint))
  (<= royalty-bps maximum-royalty-basis-points)
)

;; Validate platform fee percentage
(define-private (is-platform-fee-valid (fee-bps uint))
  (<= fee-bps maximum-platform-fee-basis-points)
)

;; Validate asset identifier is within bounds
(define-private (is-asset-id-valid (asset-id uint))
  (and (> asset-id u0) (<= asset-id maximum-asset-identifier))
)

;; Validate duration is within acceptable range
(define-private (is-duration-valid (duration-in-blocks uint))
  (and (> duration-in-blocks u0) (<= duration-in-blocks maximum-listing-duration-in-blocks))
)

;; Validate principal address format
(define-private (is-principal-valid (user-principal principal))
  (not (is-eq user-principal 'SP000000000000000000002Q6VF78))
)

;; Validate interaction type string format
(define-private (is-interaction-type-valid (type-string (string-ascii 32)))
  (and (> (len type-string) u0) (<= (len type-string) u32))
)

;; Validate 32-byte hash format
(define-private (is-hash-valid (hash-buffer (buff 32)))
  (is-eq (len hash-buffer) u32)
)

;; Validate optional duration parameter
(define-private (is-optional-duration-valid (maybe-duration (optional uint)))
  (match maybe-duration
    duration-value (is-duration-valid duration-value)
    true
  )
)

;; Validate optional hash parameter
(define-private (is-optional-hash-valid (maybe-hash (optional (buff 32))))
  (match maybe-hash
    hash-value (is-hash-valid hash-value)
    true
  )
)

;; Calculate platform fee from sale price
(define-private (compute-platform-fee (sale-price uint))
  (/ (* sale-price (var-get platform-fee-in-basis-points)) u10000)
)

;; Calculate creator royalty from sale price
(define-private (compute-creator-royalty
    (sale-price uint)
    (royalty-bps uint)
  )
  (/ (* sale-price royalty-bps) u10000)
)

;; Update user statistics based on activity type
(define-private (update-user-activity-stats
    (user-principal principal)
    (activity-type (string-ascii 16))
    (value-to-add uint)
  )
  (let ((existing-profile (default-to {
      display-name: "",
      reputation-points: u0,
      assets-created-total: u0,
      assets-owned-total: u0,
      sales-volume-total: u0,
      purchases-volume-total: u0,
      registration-block-height: stacks-block-height,
      is-verified: false,
    }
      (map-get? user-profiles { user-principal: user-principal })
    )))
    (let ((modified-profile (if (is-eq activity-type "assets-created")
        (merge existing-profile { assets-created-total: (+ (get assets-created-total existing-profile) value-to-add) })
        (if (is-eq activity-type "assets-owned")
          (merge existing-profile { assets-owned-total: (+ (get assets-owned-total existing-profile) value-to-add) })
          (if (is-eq activity-type "sales-value")
            (merge existing-profile { sales-volume-total: (+ (get sales-volume-total existing-profile) value-to-add) })
            (if (is-eq activity-type "purchases-value")
              (merge existing-profile { purchases-volume-total: (+ (get purchases-volume-total existing-profile) value-to-add) })
              existing-profile
            )
          )
        )
      )))
      (if (or
          (is-eq activity-type "assets-created")
          (is-eq activity-type "assets-owned")
          (is-eq activity-type "sales-value")
          (is-eq activity-type "purchases-value")
        )
        (begin
          (map-set user-profiles { user-principal: user-principal }
            modified-profile
          )
          (ok true)
        )
        ERR-INVALID-FIELD-IDENTIFIER
      )
    )
  )
)
