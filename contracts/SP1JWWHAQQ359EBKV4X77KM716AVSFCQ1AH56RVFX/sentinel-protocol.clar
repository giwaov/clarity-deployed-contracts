;; Sentinel Protocol
;; Version: 1.0.0
;; A secure, auditable counter contract with ownership controls and event logging
;; Built for production-grade state management on Stacks blockchain

;; =================================
;; Constants
;; =================================

;; Error Codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-COUNTER-UNDERFLOW (err u101))
(define-constant ERR-COUNTER-OVERFLOW (err u102))
(define-constant ERR-INVALID-VALUE (err u103))
(define-constant ERR-TRANSFER-FAILED (err u104))
(define-constant ERR-SAME-OWNER (err u105))

;; Contract Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-COUNTER-VALUE u340282366920938463463374607431768211455) ;; uint max
(define-constant MIN-COUNTER-VALUE u0)

;; =================================
;; Data Variables
;; =================================

(define-data-var counter uint u0)
(define-data-var owner principal CONTRACT-OWNER)
(define-data-var paused bool false)
(define-data-var total-increments uint u0)
(define-data-var total-decrements uint u0)

;; =================================
;; Data Maps
;; =================================

;; Track operations per address for analytics
(define-map user-operations 
  principal 
  {
    increments: uint,
    decrements: uint,
    last-action-block: uint
  }
)

;; =================================
;; Private Functions
;; =================================

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get owner))
)

(define-private (is-paused)
  (var-get paused)
)

(define-private (update-user-stats (operation (string-ascii 10)))
  (let
    (
      (current-stats (default-to 
        { increments: u0, decrements: u0, last-action-block: u0 }
        (map-get? user-operations tx-sender)
      ))
    )
    (if (is-eq operation "increment")
      (map-set user-operations tx-sender {
        increments: (+ (get increments current-stats) u1),
        decrements: (get decrements current-stats),
        last-action-block: stacks-block-height
      })
      (map-set user-operations tx-sender {
        increments: (get increments current-stats),
        decrements: (+ (get decrements current-stats) u1),
        last-action-block: stacks-block-height
      })
    )
  )
)

;; =================================
;; Read-Only Functions
;; =================================

(define-read-only (get-counter)
  (ok (var-get counter))
)

(define-read-only (get-owner)
  (ok (var-get owner))
)

(define-read-only (get-contract-owner)
  (ok CONTRACT-OWNER)
)

(define-read-only (is-paused-status)
  (ok (var-get paused))
)

(define-read-only (get-total-increments)
  (ok (var-get total-increments))
)

(define-read-only (get-total-decrements)
  (ok (var-get total-decrements))
)

(define-read-only (get-user-operations (user principal))
  (ok (default-to 
    { increments: u0, decrements: u0, last-action-block: u0 }
    (map-get? user-operations user)
  ))
)

(define-read-only (get-contract-info)
  (ok {
    counter: (var-get counter),
    owner: (var-get owner),
    paused: (var-get paused),
    total-increments: (var-get total-increments),
    total-decrements: (var-get total-decrements),
    contract-owner: CONTRACT-OWNER
  })
)

;; =================================
;; Public Functions
;; =================================

(define-public (increment)
  (begin
    ;; Validations
    (asserts! (not (is-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (< (var-get counter) MAX-COUNTER-VALUE) ERR-COUNTER-OVERFLOW)
    
    ;; Update counter
    (var-set counter (+ (var-get counter) u1))
    (var-set total-increments (+ (var-get total-increments) u1))
    
    ;; Update user stats
    (update-user-stats "increment")
    
    ;; Emit event
    (print {
      event: "counter-incremented",
      counter: (var-get counter),
      user: tx-sender,
      block: stacks-block-height
    })
    
    (ok (var-get counter))
  )
)

(define-public (decrement)
  (begin
    ;; Validations
    (asserts! (not (is-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (> (var-get counter) MIN-COUNTER-VALUE) ERR-COUNTER-UNDERFLOW)
    
    ;; Update counter
    (var-set counter (- (var-get counter) u1))
    (var-set total-decrements (+ (var-get total-decrements) u1))
    
    ;; Update user stats
    (update-user-stats "decrement")
    
    ;; Emit event
    (print {
      event: "counter-decremented",
      counter: (var-get counter),
      user: tx-sender,
      block: stacks-block-height
    })
    
    (ok (var-get counter))
  )
)

(define-public (increment-by (amount uint))
  (begin
    ;; Validations
    (asserts! (not (is-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-VALUE)
    (asserts! (<= (+ (var-get counter) amount) MAX-COUNTER-VALUE) ERR-COUNTER-OVERFLOW)
    
    ;; Update counter
    (var-set counter (+ (var-get counter) amount))
    (var-set total-increments (+ (var-get total-increments) amount))
    
    ;; Emit event
    (print {
      event: "counter-incremented-by",
      amount: amount,
      counter: (var-get counter),
      user: tx-sender,
      block: stacks-block-height
    })
    
    (ok (var-get counter))
  )
)

(define-public (decrement-by (amount uint))
  (begin
    ;; Validations
    (asserts! (not (is-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-VALUE)
    (asserts! (>= (var-get counter) amount) ERR-COUNTER-UNDERFLOW)
    
    ;; Update counter
    (var-set counter (- (var-get counter) amount))
    (var-set total-decrements (+ (var-get total-decrements) amount))
    
    ;; Emit event
    (print {
      event: "counter-decremented-by",
      amount: amount,
      counter: (var-get counter),
      user: tx-sender,
      block: stacks-block-height
    })
    
    (ok (var-get counter))
  )
)

;; =================================
;; Owner-Only Functions
;; =================================

(define-public (reset)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    
    (var-set counter u0)
    
    (print {
      event: "counter-reset",
      user: tx-sender,
      block: stacks-block-height
    })
    
    (ok (var-get counter))
  )
)

(define-public (set-value (new-value uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-value MAX-COUNTER-VALUE) ERR-INVALID-VALUE)
    
    (let ((old-value (var-get counter)))
      (var-set counter new-value)
      
      (print {
        event: "counter-set",
        old-value: old-value,
        new-value: new-value,
        user: tx-sender,
        block: stacks-block-height
      })
      
      (ok (var-get counter))
    )
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq new-owner (var-get owner))) ERR-SAME-OWNER)
    
    (let ((old-owner (var-get owner)))
      (var-set owner new-owner)
      
      (print {
        event: "ownership-transferred",
        old-owner: old-owner,
        new-owner: new-owner,
        block: stacks-block-height
      })
      
      (ok new-owner)
    )
  )
)

(define-public (pause)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-paused)) ERR-NOT-AUTHORIZED)
    
    (var-set paused true)
    
    (print {
      event: "contract-paused",
      user: tx-sender,
      block: stacks-block-height
    })
    
    (ok true)
  )
)

(define-public (unpause)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-paused) ERR-NOT-AUTHORIZED)
    
    (var-set paused false)
    
    (print {
      event: "contract-unpaused",
      user: tx-sender,
      block: stacks-block-height
    })
    
    (ok true)
  )
)