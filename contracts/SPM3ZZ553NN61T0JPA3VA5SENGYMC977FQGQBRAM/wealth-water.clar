;; title: wealth-water
;; version:
;; summary:
;; description:

;; HydroChain: Blockchain-Based Water Quality Monitoring & Compliance System Contract
;; A decentralized platform for transparent water quality tracking through IoT sensors,
;; verified laboratories, and distributed governance ensuring environmental safety standards

;; Contract governance principals
(define-data-var owner principal tx-sender)
(define-data-var admin-list (list 10 principal) (list))

;; Core water quality data storage with composite key indexing
(define-map quality-readings
  {
    site-id: uint,
    recorded-at: uint,
  }
  {
    ph-value: uint,
    oxygen-level: uint,
    turbidity: uint,
    temp-celsius: uint,
    conductivity: uint,
    tds-level: uint,
    is-verified: bool,
    verified-by: (optional principal),
  }
)

;; Authorized sensor operator registry
(define-map sensor-operators
  principal
  bool
)

;; Certified laboratory facilities database
(define-map lab-facilities
  uint
  {
    name: (string-ascii 50),
    address: (string-ascii 100),
    is-active: bool,
  }
)

;; Monitoring site locations with geographic data
(define-map monitoring-sites
  uint
  {
    site-name: (string-ascii 50),
    latitude: int,
    longitude: int,
    water-type: (string-ascii 20),
    is-active: bool,
  }
)

;; Sequential ID generators
(define-data-var next-site-id uint u1)
(define-data-var next-lab-id uint u1)

;; Error codes for access control and validation
(define-constant ERR-UNAUTHORIZED-ACCESS u1)
(define-constant ERR-INVALID-DATA-FORMAT u2)
(define-constant ERR-RECORD-NOT-FOUND u3)
(define-constant ERR-ALREADY-VERIFIED u4)
(define-constant ERR-VALUE-OUT-OF-RANGE u5)
(define-constant ERR-INVALID-PARAMETERS u6)
(define-constant ERR-DUPLICATE-RECORD u7)
(define-constant ERR-CAPACITY-EXCEEDED u8)

;; Water quality safety thresholds based on WHO and EPA standards
(define-constant MIN-SAFE-PH u650)
(define-constant MAX-SAFE-PH u850)
(define-constant MIN-OXYGEN-LEVEL u400)
(define-constant MAX-TURBIDITY u100)
(define-constant MAX-TEMPERATURE u3500)

;; Geographic coordinate validation bounds
(define-constant MAX-LATITUDE 90000000)
(define-constant MIN-LATITUDE -90000000)
(define-constant MAX-LONGITUDE 180000000)
(define-constant MIN-LONGITUDE -180000000)

;; System capacity and measurement constraints
(define-constant MAX-TIMESTAMP u281474976710655)
(define-constant MAX-ADMIN-COUNT u10)
(define-constant MAX-PH-VALUE u1400)
(define-constant MAX-TEMP-VALUE u10000)

;; Validates non-empty text input
(define-private (is-valid-text (text (string-ascii 100)))
  (> (len text) u0)
)

;; Validates water body classification against approved types
(define-private (is-valid-water-type (water-type (string-ascii 20)))
  (or
    (is-eq water-type "river")
    (is-eq water-type "lake")
    (is-eq water-type "ocean")
    (is-eq water-type "reservoir")
    (is-eq water-type "groundwater")
    (is-eq water-type "stream")
    (is-eq water-type "wetland")
    (is-eq water-type "estuary")
    (is-eq water-type "spring")
    (is-eq water-type "pond")
  )
)

;; Validates geographic coordinates within Earth's boundaries
(define-private (are-coordinates-valid
    (lat int)
    (lon int)
  )
  (and
    (>= lat MIN-LATITUDE)
    (<= lat MAX-LATITUDE)
    (>= lon MIN-LONGITUDE)
    (<= lon MAX-LONGITUDE)
  )
)

;; Checks if monitoring site exists in registry
(define-private (does-site-exist (site-id uint))
  (and
    (> site-id u0)
    (< site-id (var-get next-site-id))
    (is-some (map-get? monitoring-sites site-id))
  )
)

;; Validates timestamp is within acceptable range
(define-private (is-valid-timestamp (timestamp uint))
  (and
    (> timestamp u0)
    (<= timestamp MAX-TIMESTAMP)
  )
)

;; Validates all water quality parameters are within measurement ranges
(define-private (are-parameters-valid
    (ph uint)
    (oxygen uint)
    (turbidity uint)
    (temp uint)
    (conductivity uint)
    (tds uint)
  )
  (and
    (and (>= ph u0) (<= ph MAX-PH-VALUE))
    (>= oxygen u0)
    (>= turbidity u0)
    (and (>= temp u0) (<= temp MAX-TEMP-VALUE))
    (>= conductivity u0)
    (>= tds u0)
  )
)

;; Checks if user is in administrator list
(define-read-only (is-admin (user principal))
  (is-some (index-of (var-get admin-list) user))
)

;; Checks if user is contract owner
(define-read-only (is-owner (user principal))
  (is-eq user (var-get owner))
)

;; Checks if user has administrative privileges
(define-read-only (has-admin-rights (user principal))
  (or (is-owner user) (is-admin user))
)

;; Checks if user is authorized sensor operator
(define-read-only (is-sensor-operator (operator principal))
  (default-to false (map-get? sensor-operators operator))
)

;; Initializes platform (reserved for future upgrades)
(define-public (initialize-platform)
  (begin
    (asserts! (is-owner tx-sender) (err ERR-UNAUTHORIZED-ACCESS))
    (ok true)
  )
)

;; Grants administrative privileges to new user
(define-public (grant-admin-role (new-admin principal))
  (begin
    (asserts! (has-admin-rights tx-sender) (err ERR-UNAUTHORIZED-ACCESS))
    (asserts! (is-none (index-of (var-get admin-list) new-admin))
      (err ERR-DUPLICATE-RECORD)
    )

    (let ((current-admins (var-get admin-list)))
      (asserts! (< (len current-admins) MAX-ADMIN-COUNT)
        (err ERR-CAPACITY-EXCEEDED)
      )

      (let ((updated-admins (unwrap! (as-max-len? (concat current-admins (list new-admin)) u10)
          (err ERR-CAPACITY-EXCEEDED)
        )))
        (var-set admin-list updated-admins)
        (ok true)
      )
    )
  )
)

;; Revokes administrative privileges from user
(define-public (revoke-admin-role (admin-to-remove principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR-UNAUTHORIZED-ACCESS))
    (asserts! (is-some (index-of (var-get admin-list) admin-to-remove))
      (err ERR-RECORD-NOT-FOUND)
    )

    (let (
        (current-admins (var-get admin-list))
        (admin-position (unwrap! (index-of current-admins admin-to-remove)
          (err ERR-RECORD-NOT-FOUND)
        ))
      )
      (if (is-eq admin-position u0)
        (if (is-eq (len current-admins) u1)
          (var-set admin-list (list))
          (var-set admin-list
            (unwrap! (slice? current-admins u1 (len current-admins))
              (err ERR-RECORD-NOT-FOUND)
            ))
        )
        (let (
            (before-target (unwrap! (slice? current-admins u0 admin-position)
              (err ERR-RECORD-NOT-FOUND)
            ))
            (after-target (if (< (+ admin-position u1) (len current-admins))
              (unwrap!
                (slice? current-admins (+ admin-position u1) (len current-admins))
                (err ERR-RECORD-NOT-FOUND)
              )
              (list)
            ))
          )
          (var-set admin-list
            (unwrap! (as-max-len? (concat before-target after-target) u10)
              (err ERR-CAPACITY-EXCEEDED)
            ))
        )
      )
      (ok true)
    )
  )
)
