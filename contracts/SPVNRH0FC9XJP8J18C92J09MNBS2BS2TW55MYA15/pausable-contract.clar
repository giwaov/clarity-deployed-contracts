;; title: TickStx Counter Contract
;; version: 1.0.0
;; summary: A simple counter contract demonstrating Clarity fundamentals
;; description: This contract implements a global counter that can be incremented,
;; decremented, and reset. It demonstrates public vs read-only functions, mutable
;; state management, access control, and error handling in Clarity.

;; ========================================
;; Constants
;; ========================================

;; Contract owner - set to deployer's address
(define-constant CONTRACT_OWNER tx-sender)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_UNDERFLOW (err u101))
(define-constant ERR_INVALID_AMOUNT (err u104))

;; ========================================
;; Data Variables
;; ========================================

;; The global counter - starts at zero
(define-data-var counter uint u0)

;; ========================================
;; Public Functions
;; ========================================

;; Increments the counter by 1
;; @returns (response uint uint) - The new counter value on success
(define-public (increment)
  (let
    (
      (current-value (var-get counter))
      (new-value (+ current-value u1))
    )
    (var-set counter new-value)
    (ok new-value)
  )
)

;; Increments the counter by a specified amount
;; @param amount - The amount to add to the counter (must be > 0)
;; @returns (response uint uint) - The new counter value on success
(define-public (increment-by (amount uint))
  (begin
    ;; Validate amount is greater than zero
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    (let
      (
        (current-value (var-get counter))
        (new-value (+ current-value amount))
      )
      (var-set counter new-value)
      (ok new-value)
    )
  )
)

;; Decrements the counter by 1
;; @returns (response uint uint) - The new counter value on success
;; @error ERR_UNDERFLOW if counter is already at zero
(define-public (decrement)
  (let
    (
      (current-value (var-get counter))
    )
    ;; Check for underflow - counter must be greater than 0
    (asserts! (> current-value u0) ERR_UNDERFLOW)

    (let
      (
        (new-value (- current-value u1))
      )
      (var-set counter new-value)
      (ok new-value)
    )
  )
)

;; Decrements the counter by a specified amount
;; @param amount - The amount to subtract from the counter (must be > 0)
;; @returns (response uint uint) - The new counter value on success
;; @error ERR_UNDERFLOW if counter < amount
;; @error ERR_INVALID_AMOUNT if amount is zero
(define-public (decrement-by (amount uint))
  (begin
    ;; Validate amount is greater than zero
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    (let
      (
        (current-value (var-get counter))
      )
      ;; Check for underflow - counter must be >= amount
      (asserts! (>= current-value amount) ERR_UNDERFLOW)

      (let
        (
          (new-value (- current-value amount))
        )
        (var-set counter new-value)
        (ok new-value)
      )
    )
  )
)

;; Resets the counter to zero
;; Only the contract owner can call this function
;; @returns (response bool uint) - true on success
;; @error ERR_UNAUTHORIZED if caller is not the owner
(define-public (reset)
  (begin
    ;; Check if caller is the contract owner
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    ;; Reset counter to zero
    (var-set counter u0)
    (ok true)
  )
)

;; ========================================
;; Read-Only Functions
;; ========================================

;; Gets the current counter value
;; @returns uint - The current counter value
(define-read-only (get-counter)
  (var-get counter)
)

;; Gets the contract owner's principal
;; @returns principal - The contract owner's address
(define-read-only (get-owner)
  CONTRACT_OWNER
)
