;; Central Data Store for Real Estate Investment
;; This contract stores ALL shared data that multiple contracts need to access.
;; All other contracts can READ from this, and authorized contracts can WRITE to it.

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1001))
(define-constant ERR_INVALID_INPUT (err u1002))
(define-constant ERR_ARITHMETIC_OVERFLOW (err u1003))

;; CONSTANTS FOR VALIDATION
(define-constant MAX_SBTC_AMOUNT u1000000000000)
(define-constant MAX_PROPERTY_COUNT u1000)
(define-constant MAX_INVESTOR_COUNT u1000)
(define-constant MAX_BLOCK_HEIGHT u340282366920938463463374607431768211455)

;; Authorization now uses contract-caller properly
;; This private function is used for documentation purposes only
;; The actual check is done inline in public functions using contract-caller
(define-read-only (is-authorized-caller)
  (or (is-eq contract-caller .property-registry-v3)
      (is-eq contract-caller .investment-manager-v3)
      (is-eq contract-caller .rental-distributor-v3)))

;; VALIDATION HELPERS
(define-private (is-valid-sbtc-amount (amount uint))
  (and (>= amount u0) (<= amount MAX_SBTC_AMOUNT)))

(define-private (is-valid-block-height (height uint))
  (and (>= height u0) (<= height MAX_BLOCK_HEIGHT)))

(define-private (is-valid-count (count uint))
  (and (>= count u0) (<= count MAX_INVESTOR_COUNT)))

(define-private (is-valid-property-count (count uint))
  (and (>= count u0) (<= count MAX_PROPERTY_COUNT)))

;; Safe arithmetic operations
(define-private (safe-add (a uint) (b uint))
  (let ((result (+ a b)))
    (if (and (>= result a) (>= result b))
      (ok result)
      ERR_ARITHMETIC_OVERFLOW)))

(define-private (safe-sub (a uint) (b uint))
  (if (>= a b)
    (ok (- a b))
    ERR_ARITHMETIC_OVERFLOW))

(define-private (safe-mul (a uint) (b uint))
  (if (is-eq b u0)
    (ok u0)
    (let ((result (* a b)))
      (if (is-eq (/ result b) a)
        (ok result)
        ERR_ARITHMETIC_OVERFLOW))))

;; INVESTMENT DATA STORAGE
(define-map user-property-investments
  { property-id: uint, investor: principal }
  { 
    sbtc-invested: uint,
    investment-date: uint,
    last-updated: uint
  })

(define-map property-investment-totals
  { property-id: uint }
  { 
    total-sbtc-invested: uint,
    investor-count: uint,
    last-updated: uint
  })

(define-map user-portfolio-totals
  { investor: principal }
  { 
    total-sbtc-invested: uint,
    property-count: uint,
    total-earnings: uint,
    last-updated: uint
  })

;; READ FUNCTIONS (anyone can read)
(define-read-only (get-user-investment (property-id uint) (investor principal))
  (default-to 
    { sbtc-invested: u0, investment-date: u0, last-updated: u0 }
    (map-get? user-property-investments { property-id: property-id, investor: investor })))

(define-read-only (get-property-investment-totals (property-id uint))
  (default-to 
    { total-sbtc-invested: u0, investor-count: u0, last-updated: u0 }
    (map-get? property-investment-totals { property-id: property-id })))

(define-read-only (get-user-portfolio (investor principal))
  (default-to 
    { total-sbtc-invested: u0, property-count: u0, total-earnings: u0, last-updated: u0 }
    (map-get? user-portfolio-totals { investor: investor })))

;; WRITE FUNCTIONS (only authorized contracts)
;; All authorization checks now use contract-caller directly
(define-public (update-user-investment 
    (property-id uint) 
    (investor principal) 
    (sbtc-invested uint)
    (investment-date uint))
  (begin
    ;; Authorization check uses contract-caller inline
    (asserts! (or (is-eq contract-caller .property-registry-v3)
                  (is-eq contract-caller .investment-manager-v3)
                  (is-eq contract-caller .rental-distributor-v3))
              ERR_NOT_AUTHORIZED)
    
    ;; Input validation
    (asserts! (> property-id u0) ERR_INVALID_INPUT)
    (asserts! (is-standard investor) ERR_INVALID_INPUT)
    (asserts! (is-valid-sbtc-amount sbtc-invested) ERR_INVALID_INPUT)
    (asserts! (is-valid-block-height investment-date) ERR_INVALID_INPUT)
    (asserts! (<= investment-date stacks-block-height) ERR_INVALID_INPUT)
    
    (map-set user-property-investments
      { property-id: property-id, investor: investor }
      { 
        sbtc-invested: sbtc-invested,
        investment-date: investment-date,
        last-updated: stacks-block-height
      })
    (ok true)))

(define-public (update-property-totals
    (property-id uint)
    (total-sbtc-invested uint)
    (investor-count uint))
  (begin
    ;; Authorization check uses contract-caller inline
    (asserts! (or (is-eq contract-caller .property-registry-v3)
                  (is-eq contract-caller .investment-manager-v3)
                  (is-eq contract-caller .rental-distributor-v3))
              ERR_NOT_AUTHORIZED)
    
    ;; Input validation
    (asserts! (> property-id u0) ERR_INVALID_INPUT)
    (asserts! (is-valid-sbtc-amount total-sbtc-invested) ERR_INVALID_INPUT)
    (asserts! (is-valid-count investor-count) ERR_INVALID_INPUT)
    
    (map-set property-investment-totals
      { property-id: property-id }
      {
        total-sbtc-invested: total-sbtc-invested,
        investor-count: investor-count,
        last-updated: stacks-block-height
      })
    (ok true)))

(define-public (update-user-portfolio
    (investor principal)
    (total-sbtc-invested uint)
    (property-count uint)
    (total-earnings uint))
  (begin
    ;; Authorization check uses contract-caller inline
    (asserts! (or (is-eq contract-caller .property-registry-v3)
                  (is-eq contract-caller .investment-manager-v3)
                  (is-eq contract-caller .rental-distributor-v3))
              ERR_NOT_AUTHORIZED)
    
    ;; Input validation
    (asserts! (is-standard investor) ERR_INVALID_INPUT)
    (asserts! (is-valid-sbtc-amount total-sbtc-invested) ERR_INVALID_INPUT)
    (asserts! (is-valid-property-count property-count) ERR_INVALID_INPUT)
    (asserts! (is-valid-sbtc-amount total-earnings) ERR_INVALID_INPUT)
    
    (map-set user-portfolio-totals
      { investor: investor }
      {
        total-sbtc-invested: total-sbtc-invested,
        property-count: property-count,
        total-earnings: total-earnings,
        last-updated: stacks-block-height
      })
    (ok true)))

;; EMERGENCY READ-ONLY FUNCTIONS (for debugging/monitoring)
(define-read-only (get-total-properties-tracked)
  u0)

(define-read-only (verify-caller (expected-caller principal))
  ;; Utility function for testing authorization
  (ok (is-eq contract-caller expected-caller)))