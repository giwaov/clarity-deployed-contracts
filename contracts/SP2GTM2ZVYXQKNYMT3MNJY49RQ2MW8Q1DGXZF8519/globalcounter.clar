;; title: global-counter
;; summary: A simple persistent counter that anyone can increment or decrement.

;; Data Vars
;; This variable lives on the blockchain and persists forever
(define-data-var count int 0)

;; Public Functions

;; 1. Increment: Adds 1 to the current count
(define-public (increment)
  (begin
    (var-set count (+ (var-get count) 1))
    (ok (var-get count))
  )
)

;; 2. Decrement: Subtracts 1 from the current count
(define-public (decrement)
  (begin
    (var-set count (- (var-get count) 1))
    (ok (var-get count))
  )
)

;; 3. Reset: Sets the count back to zero (Only for you)
(define-public (reset)
  (begin
    ;; replace 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM with your address
    (asserts! (is-eq tx-sender 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) (err u401))
    (var-set count 0)
    (ok true)
  )
)

;; Read-Only Functions

;; Get the current count value without paying gas
(define-read-only (get-count)
  (ok (var-get count))
)
