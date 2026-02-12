;; title: yield-farm
;; version:
;; summary:
;; description:

;; Constants for contract ownership and error handling
(define-constant contract-owner tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-INVALID-BOUNDS (err u101))
(define-constant ERR-INVALID-PARAMS (err u102))
(define-constant ERR-SEQUENCE-OVERFLOW (err u103))
(define-constant ERR-COOLDOWN-ACTIVE (err u104))
(define-constant ERR-BLACKLISTED (err u105))
(define-constant ERR-LOW-ENTROPY (err u106))
(define-constant ERR-MAINTENANCE (err u107))
(define-constant ERR-COMMIT-TIMEOUT (err u108))
(define-constant ERR-INVALID-REVEAL (err u109))
(define-constant ERR-INVALID-COMMITMENT (err u110))
(define-constant ERR-INVALID-ADDRESS (err u111))

;; Optimized configuration constants
(define-constant MAX-SEQUENCE-LENGTH u50) ;; Reduced for gas optimization
(define-constant COMMIT-REVEAL-TIMEOUT u144) ;; ~24 hours in blocks
(define-constant GENERATION-COOLDOWN u3) ;; Reduced cooldown for better UX
(define-constant MAX-RANGE u1000000)
(define-constant ZERO-BUFFER 0x0000000000000000000000000000000000000000000000000000000000000000)

;; Data variables
(define-data-var maintenance-mode bool false)
(define-data-var last-random uint u0)
(define-data-var current-seed (buff 32) 0x)
(define-data-var last-block uint u0)

;; Maps for commit-reveal scheme
(define-map commitments
  principal
  {
    commit-hash: (buff 32),
    commit-height: uint,
    revealed: bool,
  }
)

(define-map restricted-addresses
  principal
  bool
)
(define-map generation-stats
  principal
  uint
)

;; Read-only functions

(define-read-only (get-last-random)
  (ok (var-get last-random))
)

(define-read-only (get-commitment (user principal))
  (map-get? commitments user)
)

(define-read-only (is-restricted (address principal))
  (default-to false (map-get? restricted-addresses address))
)

;; Private helper functions

(define-private (validate-caller)
  (if (is-eq tx-sender contract-owner)
    (ok true)
    ERR-OWNER-ONLY
  )
)

(define-private (check-conditions)
  (begin
    (asserts! (not (var-get maintenance-mode)) ERR-MAINTENANCE)
    (asserts! (not (is-restricted tx-sender)) ERR-BLACKLISTED)
    (asserts!
      (> stacks-block-height (+ (var-get last-block) GENERATION-COOLDOWN))
      ERR-COOLDOWN-ACTIVE
    )
    (ok true)
  )
)

;; Validate commitment buffer with proper error handling
(define-private (validate-commitment-data (commitment (buff 32)))
  (if (not (is-eq commitment ZERO-BUFFER))
    (ok commitment)
    ERR-INVALID-COMMITMENT
  )
)

;; Optimized hash mixing function
(define-private (mix-seed
    (input-seed (buff 32))
    (block-hash (buff 32))
  )
  (sha512/256 (concat input-seed block-hash))
)

;; Modified buffer conversion function
(define-private (to-16-bytes (input (buff 32)))
  (unwrap-panic (as-max-len? (unwrap-panic (slice? input u0 u16)) u16))
)

;; Validate address with proper error handling
(define-private (validate-address-data (address principal))
  (if (not (is-eq address contract-owner))
    (ok address)
    ERR-INVALID-ADDRESS
  )
)

;; Commit-reveal scheme functions

(define-public (commit-random (commitment (buff 32)))
  (begin
    (try! (check-conditions))
    (match (validate-commitment-data commitment)
      success (ok (map-set commitments tx-sender {
        commit-hash: success,
        commit-height: stacks-block-height,
        revealed: false,
      }))
      error ERR-INVALID-COMMITMENT
    )
  )
)

;; Administrative functions

(define-public (set-maintenance-mode (mode bool))
  (begin
    (try! (validate-caller))
    (ok (var-set maintenance-mode mode))
  )
)

(define-public (add-restricted-address (address principal))
  (begin
    (try! (validate-caller))
    (match (validate-address-data address)
      validated-address (ok (map-set restricted-addresses validated-address true))
      error ERR-INVALID-ADDRESS
    )
  )
)

(define-public (remove-restricted-address (address principal))
  (begin
    (try! (validate-caller))
    (match (validate-address-data address)
      validated-address (ok (map-delete restricted-addresses validated-address))
      error ERR-INVALID-ADDRESS
    )
  )
)

;; Initialize contract
(begin
  (var-set maintenance-mode false)
  (var-set last-random u0)
  (var-set current-seed ZERO-BUFFER)
  (var-set last-block u0)
)
