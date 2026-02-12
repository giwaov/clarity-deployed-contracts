;; title: parameter-store
;; version:
;; summary:
;; description:

;; traits
;;
;; CONSTANTS AND ERROR CODES

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-PRICE (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant ERR-TWIN-NOT-FOR-SALE (err u105))
(define-constant ERR-CANNOT-BUY-OWN-TWIN (err u106))
(define-constant ERR-INVALID-ROYALTY (err u107))
(define-constant ERR-EXPIRED-LISTING (err u108))
(define-constant ERR-INVALID-ACCESS-LEVEL (err u109))
(define-constant ERR-ACCESS-DENIED (err u110))
(define-constant ERR-INVALID-METADATA (err u111))
(define-constant ERR-TWIN-LOCKED (err u112))
(define-constant ERR-INVALID-FEE (err u113))
(define-constant ERR-INVALID-FIELD (err u114))
(define-constant ERR-INVALID-TWIN-ID (err u115))
(define-constant ERR-INVALID-DURATION (err u116))
(define-constant ERR-INVALID-PRINCIPAL (err u117))
(define-constant ERR-INVALID-INTERACTION-TYPE (err u118))
(define-constant ERR-INVALID-DATA-HASH (err u119))

;; Maximum values for validation
(define-constant MAX-ROYALTY u1000) ;; 10% (basis points)
(define-constant MAX-FEE u1000) ;; 10% (basis points)
(define-constant MAX-PRICE u1000000000000) ;; 1 million STX
(define-constant MAX-STRING-LENGTH u256)
(define-constant MAX-METADATA-SIZE u1024)
(define-constant MAX-DURATION u525600) ;; ~1 year in blocks
(define-constant MAX-TWIN-ID u4294967295) ;; 32-bit max

;; DATA STRUCTURES

;; Digital Twin structure
(define-map digital-twins
  { twin-id: uint }
  {
    owner: principal,
    creator: principal,
    name: (string-ascii 64),
    description: (string-ascii 256),
    metadata-uri: (string-ascii 256),
    category: (string-ascii 32),
    created-at: uint,
    updated-at: uint,
    is-active: bool,
    is-locked: bool,
    access-level: uint, ;; 0=public, 1=restricted, 2=private
    royalty-percentage: uint, ;; basis points (100 = 1%)
    total-interactions: uint,
    reputation-score: uint,
  }
)

;; Marketplace listings
(define-map marketplace-listings
  { twin-id: uint }
  {
    seller: principal,
    price: uint,
    listed-at: uint,
    expires-at: uint,
    is-active: bool,
    payment-token: (optional principal), ;; for future token support
  }
)

;; Access permissions for restricted twins
(define-map access-permissions
  {
    twin-id: uint,
    user: principal,
  }
  {
    access-level: uint, ;; 0=view, 1=interact, 2=modify
    granted-by: principal,
    granted-at: uint,
    expires-at: (optional uint),
  }
)

;; Twin interaction history
(define-map twin-interactions
  {
    twin-id: uint,
    interaction-id: uint,
  }
  {
    user: principal,
    interaction-type: (string-ascii 32),
    timestamp: uint,
    data-hash: (optional (buff 32)),
  }
)

;; User profiles
(define-map user-profiles
  { user: principal }
  {
    username: (string-ascii 32),
    reputation-score: uint,
    twins-created: uint,
    twins-owned: uint,
    total-sales: uint,
    total-purchases: uint,
    joined-at: uint,
    is-verified: bool,
  }
)

;; Twin categories for organization
(define-map twin-categories
  { category: (string-ascii 32) }
  {
    description: (string-ascii 128),
    twin-count: uint,
    is-active: bool,
  }
)

;; DATA VARIABLES

(define-data-var next-twin-id uint u1)
(define-data-var next-interaction-id uint u1)
(define-data-var marketplace-fee uint u250) ;; 2.5% fee (basis points)
(define-data-var contract-balance uint u0)
(define-data-var total-twins-created uint u0)
(define-data-var total-sales-volume uint u0)
(define-data-var is-marketplace-active bool true)

;; PRIVATE FUNCTIONS

(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (validate-string-length
    (str (string-ascii 256))
    (max-len uint)
  )
  (<= (len str) max-len)
)

(define-private (validate-price (price uint))
  (and (> price u0) (<= price MAX-PRICE))
)

(define-private (validate-royalty (royalty uint))
  (<= royalty MAX-ROYALTY)
)

(define-private (validate-fee (fee uint))
  (<= fee MAX-FEE)
)

(define-private (validate-twin-id (twin-id uint))
  (and (> twin-id u0) (<= twin-id MAX-TWIN-ID))
)

(define-private (validate-duration (duration uint))
  (and (> duration u0) (<= duration MAX-DURATION))
)

(define-private (validate-principal (user principal))
  (not (is-eq user 'SP000000000000000000002Q6VF78))
)

(define-private (validate-interaction-type (interaction-type (string-ascii 32)))
  (and (> (len interaction-type) u0) (<= (len interaction-type) u32))
)

(define-private (validate-data-hash (data-hash (buff 32)))
  (is-eq (len data-hash) u32)
)

(define-private (validate-optional-duration (duration (optional uint)))
  (match duration
    some-duration (validate-duration some-duration)
    true
  )
)

(define-private (validate-optional-data-hash (data-hash (optional (buff 32))))
  (match data-hash
    some-hash (validate-data-hash some-hash)
    true
  )
)

(define-private (calculate-marketplace-fee (price uint))
  (/ (* price (var-get marketplace-fee)) u10000)
)

(define-private (calculate-royalty
    (price uint)
    (royalty-percentage uint)
  )
  (/ (* price royalty-percentage) u10000)
)

(define-private (update-user-stats
    (user principal)
    (field (string-ascii 16))
    (increment uint)
  )
  (let ((profile (default-to {
      username: "",
      reputation-score: u0,
      twins-created: u0,
      twins-owned: u0,
      total-sales: u0,
      total-purchases: u0,
      joined-at: stacks-block-height,
      is-verified: false,
    }
      (map-get? user-profiles { user: user })
    )))
    (let ((updated-profile (if (is-eq field "twins-created")
        (merge profile { twins-created: (+ (get twins-created profile) increment) })
        (if (is-eq field "twins-owned")
          (merge profile { twins-owned: (+ (get twins-owned profile) increment) })
          (if (is-eq field "total-sales")
            (merge profile { total-sales: (+ (get total-sales profile) increment) })
            (if (is-eq field "total-purchases")
              (merge profile { total-purchases: (+ (get total-purchases profile) increment) })
              profile
            )
          )
        )
      )))
      (if (or
          (is-eq field "twins-created")
          (is-eq field "twins-owned")
          (is-eq field "total-sales")
          (is-eq field "total-purchases")
        )
        (begin
          (map-set user-profiles { user: user } updated-profile)
          (ok true)
        )
        ERR-INVALID-FIELD
      )
    )
  )
)

;; PUBLIC FUNCTIONS - TWIN MANAGEMENT

(define-public (create-digital-twin
    (name (string-ascii 64))
    (description (string-ascii 256))
    (metadata-uri (string-ascii 256))
    (category (string-ascii 32))
    (access-level uint)
    (royalty-percentage uint)
  )
  (let ((twin-id (var-get next-twin-id)))
    (asserts! (validate-string-length name u64) ERR-INVALID-METADATA)
    (asserts! (validate-string-length description u256) ERR-INVALID-METADATA)
    (asserts! (validate-string-length metadata-uri u256) ERR-INVALID-METADATA)
    (asserts! (validate-string-length category u32) ERR-INVALID-METADATA)
    (asserts! (<= access-level u2) ERR-INVALID-ACCESS-LEVEL)
    (asserts! (validate-royalty royalty-percentage) ERR-INVALID-ROYALTY)

    ;; Create the digital twin
    (map-set digital-twins { twin-id: twin-id } {
      owner: tx-sender,
      creator: tx-sender,
      name: name,
      description: description,
      metadata-uri: metadata-uri,
      category: category,
      created-at: stacks-block-height,
      updated-at: stacks-block-height,
      is-active: true,
      is-locked: false,
      access-level: access-level,
      royalty-percentage: royalty-percentage,
      total-interactions: u0,
      reputation-score: u0,
    })

    ;; Update category count
    (map-set twin-categories { category: category }
      (merge
        (default-to {
          description: "",
          twin-count: u0,
          is-active: true,
        }
          (map-get? twin-categories { category: category })
        ) { twin-count: (+
        (default-to u0
          (get twin-count (map-get? twin-categories { category: category }))
        )
        u1
      ) }
      ))

    ;; Update counters and user stats
    (var-set next-twin-id (+ twin-id u1))
    (var-set total-twins-created (+ (var-get total-twins-created) u1))
    (try! (update-user-stats tx-sender "twins-created" u1))
    (try! (update-user-stats tx-sender "twins-owned" u1))

    (ok twin-id)
  )
)
