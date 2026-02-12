;; title: source
;; version:
;; summary:
;; description:
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-ROLE (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-INVALID-INPUT (err u103))
(define-constant ERR-ALREADY-EXISTS (err u104))

;; traits
;;
(define-data-var contract-owner principal tx-sender)

;; token definitions
;;
(define-constant MANUFACTURER u"manufacturer")
(define-constant TRANSPORTER u"transporter")
(define-constant RETAILER u"retailer")
(define-constant MIN-STRING-LENGTH u1)
(define-constant MAX-STRING-LENGTH-100 u100)
(define-constant MAX-STRING-LENGTH-50 u50)

;; constants
;;
(define-map roles
  principal
  {
    role: (string-utf8 20),
    is-active: bool,
  }
)

;; data vars
;;
(define-map products
  uint
  {
    id: uint,
    name: (string-utf8 100),
    manufacturer: principal,
    origin: (string-utf8 50),
    timestamp: uint,
    current-location: (string-utf8 100),
    status: (string-utf8 20),
  }
)

;; data maps
;;
;; New map for product history
(define-map product-history
  {
    product-id: uint,
    change-id: uint,
  }
  {
    timestamp: uint,
    location: (string-utf8 100),
    status: (string-utf8 20),
  }
)

;; public functions
;;
(define-data-var product-counter uint u0)
(define-data-var change-counter uint u0) ;; To track the number of changes for history

;; read only functions
;;
(define-private (is-valid-role (role (string-utf8 20)))
  (or
    (is-eq role MANUFACTURER)
    (is-eq role TRANSPORTER)
    (is-eq role RETAILER)
  )
)

;; private functions
;;
(define-private (is-valid-string-length
    (str (string-utf8 100))
    (max-len uint)
  )
  (and
    (>= (len str) MIN-STRING-LENGTH)
    (<= (len str) max-len)
  )
)

(define-private (validate-strings
    (name (string-utf8 100))
    (origin (string-utf8 50))
    (location (string-utf8 100))
  )
  (and
    (is-valid-string-length name MAX-STRING-LENGTH-100)
    (is-valid-string-length origin MAX-STRING-LENGTH-50)
    (is-valid-string-length location MAX-STRING-LENGTH-100)
  )
)

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (check-role
    (address principal)
    (required-role (string-utf8 20))
  )
  (match (map-get? roles address)
    role (and
      (is-eq (get role role) required-role)
      (get is-active role)
    )
    false
  )
)

(define-private (safe-get-role (address principal))
  (default-to {
    role: u"",
    is-active: false,
  } (map-get? roles address)
  )
)

(define-public (assign-role
    (address principal)
    (new-role (string-utf8 20))
  )
  (let ((current-role (safe-get-role address)))
    (begin
      (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
      (asserts! (is-valid-role new-role) ERR-INVALID-INPUT)
      (asserts! (not (get is-active current-role)) ERR-ALREADY-EXISTS)
      (ok (map-set roles address {
        role: new-role,
        is-active: true,
      }))
    )
  )
)

(define-public (revoke-role (address principal))
  (let ((current-role (safe-get-role address)))
    (begin
      (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
      (asserts! (get is-active current-role) ERR-NOT-FOUND)
      (ok (map-set roles address {
        role: u"",
        is-active: false,
      }))
    )
  )
)

(define-private (safe-get-product (product-id uint))
  (map-get? products product-id)
)

(define-public (add-product
    (name (string-utf8 100))
    (origin (string-utf8 50))
    (location (string-utf8 100))
  )
  (let (
      (safe-id (var-get product-counter))
      (existing-product (safe-get-product safe-id))
      (validated-strings (validate-strings name origin location))
    )
    (begin
      (asserts! (check-role tx-sender MANUFACTURER) ERR-NOT-AUTHORIZED)
      (asserts! validated-strings ERR-INVALID-INPUT)
      (asserts! (is-none existing-product) ERR-ALREADY-EXISTS)
      (map-set products safe-id {
        id: safe-id,
        name: name,
        manufacturer: tx-sender,
        origin: origin,
        timestamp: stacks-block-height,
        current-location: location,
        status: u"created",
      })
      (var-set product-counter (+ safe-id u1))
      (ok safe-id)
    )
  )
)

;; Update location and add history entry
(define-public (update-location
    (product-id uint)
    (new-location (string-utf8 100))
  )
  (let (
      (product (safe-get-product product-id))
      (valid-location (is-valid-string-length new-location MAX-STRING-LENGTH-100))
      (change-id (var-get change-counter))
    )
    (begin
      (asserts!
        (or
          (check-role tx-sender TRANSPORTER)
          (check-role tx-sender MANUFACTURER)
        )
        ERR-NOT-AUTHORIZED
      )
      (asserts! valid-location ERR-INVALID-INPUT)
      (asserts! (is-some product) ERR-NOT-FOUND)
      ;; Update the product with the new location
      (map-set products product-id
        (merge (unwrap! product ERR-NOT-FOUND) { current-location: new-location })
      )
      ;; Add a new entry to the product history
      (map-set product-history {
        product-id: product-id,
        change-id: change-id,
      } {
        timestamp: stacks-block-height,
        location: new-location,
        status: (get status (unwrap! product ERR-NOT-FOUND)),
      })
      ;; Increment the change counter
      (var-set change-counter (+ change-id u1))
      (ok change-id)
    )
  )
)

;; New function to get the product's history
(define-read-only (get-product-history (product-id uint))
  (map-get? product-history {
    product-id: product-id,
    change-id: u0,
  })
)

(define-read-only (get-product (product-id uint))
  (safe-get-product product-id)
)

(define-read-only (get-role (address principal))
  (safe-get-role address)
)
