;; title: sBTC-ClearSight
;; version:
;; summary:
;; description:

;; ClearSight - Supply Chain Transparency Contract
;; Enhanced with RBAC, Audit Trail, Advanced Status Management, and Input Validation

;; title: source
;; version:
;; summary:
;; description:
;; Constants for validation
(define-constant MAX-PRODUCT-ID-LENGTH u36)
(define-constant MAX-LOCATION-LENGTH u50)
(define-constant MAX-REASON-LENGTH u50)

;; traits
;;
;; Enhanced status constants
(define-constant STATUS-REGISTERED "registered")
(define-constant STATUS-IN-TRANSIT "in-transit")
(define-constant STATUS-DELIVERED "delivered")
(define-constant STATUS-TRANSFERRED "transferred")
(define-constant STATUS-VERIFIED "verified")
(define-constant STATUS-RETURNED "returned")
(define-constant STATUS-REJECTED "rejected")

;; token definitions
;;
;; Action constants (all 12 chars or less)
(define-constant ACTION-UPDATE "status-upd")
(define-constant ACTION-REGISTER "register")
(define-constant ACTION-TRANSFER "transfer")

;; constants
;;
;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PRODUCT-EXISTS (err u101))
(define-constant ERR-PRODUCT-NOT-FOUND (err u102))
(define-constant ERR-INVALID-STATUS (err u103))
(define-constant ERR-INVALID-PRODUCT-ID (err u104))
(define-constant ERR-INVALID-LOCATION (err u105))
(define-constant ERR-INVALID-OWNER (err u106))
(define-constant ERR-ROLE-EXISTS (err u107))
(define-constant ERR-INVALID-ROLE (err u108))
(define-constant ERR-INVALID-STATUS-TRANSITION (err u109))
(define-constant ERR-INVALID-REASON (err u110))

;; data vars
;;
;; Define roles
(define-constant ROLE-ADMIN u1)
(define-constant ROLE-MANUFACTURER u2)
(define-constant ROLE-DISTRIBUTOR u3)
(define-constant ROLE-RETAILER u4)

;; data maps
;;
;; Define data variables
(define-data-var contract-owner principal tx-sender)

;; public functions
;;
;; Role management
(define-map user-roles
  { user: principal }
  { role: uint }
)

;; read only functions
;;
;; Enhanced products map with status tracking
(define-map products
  { product-id: (string-ascii 36) }
  {
    manufacturer: principal,
    timestamp: uint,
    current-owner: principal,
    current-status: (string-ascii 12),
    verified: bool,
    status-update-count: uint,
  }
)

;; private functions
;;
;; Status history map
(define-map status-history
  {
    product-id: (string-ascii 36),
    update-number: uint,
  }
  {
    status: (string-ascii 12),
    timestamp: uint,
    changed-by: principal,
    reason: (string-ascii 50),
    location: (string-ascii 50),
  }
)

;; Product history
(define-map product-history
  {
    product-id: (string-ascii 36),
    timestamp: uint,
  }
  {
    owner: principal,
    action: (string-ascii 12),
    location: (string-ascii 50),
    previous-owner: (optional principal),
  }
)

;; Audit trail
(define-map audit-log
  {
    transaction-id: uint,
    timestamp: uint,
  }
  {
    actor: principal,
    action: (string-ascii 12),
    product-id: (string-ascii 36),
    details: (string-ascii 50),
  }
)

(define-data-var audit-counter uint u0)

;; Enhanced validation functions
(define-private (is-valid-product-id (product-id (string-ascii 36)))
  (and
    (>= (len product-id) u1)
    (<= (len product-id) MAX-PRODUCT-ID-LENGTH)
    (not (is-eq product-id ""))
    (not (is-eq product-id " "))
    true
  )
)

(define-private (is-valid-location (location (string-ascii 50)))
  (and
    (>= (len location) u1)
    (<= (len location) MAX-LOCATION-LENGTH)
    (not (is-eq location ""))
    (not (is-eq location " "))
    true
  )
)

(define-private (is-valid-reason (reason (string-ascii 50)))
  (and
    (>= (len reason) u1)
    (<= (len reason) MAX-REASON-LENGTH)
    (not (is-eq reason ""))
    (not (is-eq reason " "))
    true
  )
)

;; Status validation functions
(define-private (is-valid-status (status (string-ascii 12)))
  (or
    (is-eq status STATUS-REGISTERED)
    (is-eq status STATUS-IN-TRANSIT)
    (is-eq status STATUS-DELIVERED)
    (is-eq status STATUS-TRANSFERRED)
    (is-eq status STATUS-VERIFIED)
    (is-eq status STATUS-RETURNED)
    (is-eq status STATUS-REJECTED)
  )
)

(define-private (is-valid-status-transition
    (current-status (string-ascii 12))
    (new-status (string-ascii 12))
  )
  (or
    (and
      (is-eq current-status STATUS-REGISTERED)
      (or
        (is-eq new-status STATUS-IN-TRANSIT)
        (is-eq new-status STATUS-TRANSFERRED)
      )
    )
    (and
      (is-eq current-status STATUS-IN-TRANSIT)
      (or
        (is-eq new-status STATUS-DELIVERED)
        (is-eq new-status STATUS-RETURNED)
      )
    )
    (and
      (is-eq current-status STATUS-DELIVERED)
      (or
        (is-eq new-status STATUS-VERIFIED)
        (is-eq new-status STATUS-REJECTED)
      )
    )
    (and
      (is-eq current-status STATUS-TRANSFERRED)
      (is-eq new-status STATUS-VERIFIED)
    )
  )
)

;; Fixed authorization function with consistent return type
(define-private (check-authorization
    (user principal)
    (required-role uint)
  )
  (match (map-get? user-roles { user: user })
    role-data (if (is-eq (get role role-data) required-role)
      (ok true)
      ERR-NOT-AUTHORIZED
    )
    ERR-NOT-AUTHORIZED
  )
)

(define-private (create-audit-log
    (actor principal)
    (action (string-ascii 12))
    (product-id (string-ascii 36))
    (details (string-ascii 50))
  )
  (begin
    (asserts! (is-valid-product-id product-id) ERR-INVALID-PRODUCT-ID)
    (let ((current-counter (var-get audit-counter)))
      (map-set audit-log {
        transaction-id: current-counter,
        timestamp: stacks-block-height,
      } {
        actor: actor,
        action: action,
        product-id: product-id,
        details: details,
      })
      (var-set audit-counter (+ current-counter u1))
      (ok true)
    )
  )
)

;; Updated product management functions
(define-public (update-product-status
    (product-id (string-ascii 36))
    (new-status (string-ascii 12))
    (reason (string-ascii 50))
    (location (string-ascii 50))
  )
  (begin
    ;; Authorization check
    (try! (check-authorization tx-sender ROLE-MANUFACTURER))

    ;; Input validation
    (asserts! (is-valid-product-id product-id) ERR-INVALID-PRODUCT-ID)
    (asserts! (is-valid-status new-status) ERR-INVALID-STATUS)
    (asserts! (is-valid-reason reason) ERR-INVALID-REASON)
    (asserts! (is-valid-location location) ERR-INVALID-LOCATION)

    (let ((product (unwrap! (map-get? products { product-id: product-id })
        ERR-PRODUCT-NOT-FOUND
      )))
      ;; Status transition validation
      (asserts!
        (is-valid-status-transition (get current-status product) new-status)
        ERR-INVALID-STATUS-TRANSITION
      )

      ;; Update product status
      (map-set products { product-id: product-id }
        (merge product {
          current-status: new-status,
          status-update-count: (+ (get status-update-count product) u1),
        })
      )

      ;; Record in status history
      (map-set status-history {
        product-id: product-id,
        update-number: (get status-update-count product),
      } {
        status: new-status,
        timestamp: stacks-block-height,
        changed-by: tx-sender,
        reason: reason,
        location: location,
      })

      ;; Create audit log entry
      (try! (create-audit-log tx-sender ACTION-UPDATE product-id
        (concat "Status: " new-status)
      ))
      (ok true)
    )
  )
)

(define-public (register-product
    (product-id (string-ascii 36))
    (location (string-ascii 50))
  )
  (begin
    ;; Authorization check
    (try! (check-authorization tx-sender ROLE-MANUFACTURER))

    ;; Input validation
    (asserts! (is-valid-product-id product-id) ERR-INVALID-PRODUCT-ID)
    (asserts! (is-valid-location location) ERR-INVALID-LOCATION)

    ;; Check if product already exists
    (asserts! (is-none (map-get? products { product-id: product-id }))
      ERR-PRODUCT-EXISTS
    )

    ;; Register new product
    (map-set products { product-id: product-id } {
      manufacturer: tx-sender,
      timestamp: stacks-block-height,
      current-owner: tx-sender,
      current-status: STATUS-REGISTERED,
      verified: true,
      status-update-count: u1,
    })

    ;; Initial status history entry
    (map-set status-history {
      product-id: product-id,
      update-number: u0,
    } {
      status: STATUS-REGISTERED,
      timestamp: stacks-block-height,
      changed-by: tx-sender,
      reason: "Initial registration",
      location: location,
    })

    ;; Create audit log entry
    (try! (create-audit-log tx-sender ACTION-REGISTER product-id "Product registered"))
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-status-history
    (product-id (string-ascii 36))
    (update-number uint)
  )
  (begin
    (asserts! (is-valid-product-id product-id) ERR-INVALID-PRODUCT-ID)
    (ok (map-get? status-history {
      product-id: product-id,
      update-number: update-number,
    }))
  )
)

(define-read-only (get-product-details (product-id (string-ascii 36)))
  (begin
    (asserts! (is-valid-product-id product-id) ERR-INVALID-PRODUCT-ID)
    (ok (map-get? products { product-id: product-id }))
  )
)

;; Role management function
(define-public (assign-role
    (user principal)
    (role uint)
  )
  (begin
    ;; Authorization check
    (try! (check-authorization tx-sender ROLE-ADMIN))

    ;; Validate role
    (asserts!
      (or
        (is-eq role ROLE-MANUFACTURER)
        (is-eq role ROLE-DISTRIBUTOR)
        (is-eq role ROLE-RETAILER)
      )
      ERR-INVALID-ROLE
    )

    ;; Assign role
    (map-set user-roles { user: user } { role: role })
    (ok true)
  )
)
