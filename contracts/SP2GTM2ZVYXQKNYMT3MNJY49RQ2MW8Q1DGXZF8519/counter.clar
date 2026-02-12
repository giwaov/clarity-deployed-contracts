;; Counter contract for Clarinet 4 with enhanced features
(define-constant ERR_NOT_OWNER     u1000)
(define-constant ERR_UNDERFLOW    u1001)
(define-constant ERR_PAUSED       u1002)

;; Store the owner (set on deployment)
(define-data-var owner principal tx-sender)

;; Store the counter value
(define-data-var counter uint u0)

;; Store pause state
(define-data-var paused bool false)

;; Helper: Only owner can call
(define-private (require-owner (caller principal))
  (if (is-eq caller (var-get owner))
      (ok true)
      (err ERR_NOT_OWNER)))

;; Public: Toggle pause state (owner only)
(define-public (toggle-pause)
  (begin
    (try! (require-owner tx-sender))
    (var-set paused (not (var-get paused)))
    (ok true)))

;; Public: Increment counter
(define-public (increment)
  (if (var-get paused)
      (err ERR_PAUSED)
      (let ((new-value (+ (var-get counter) u1)))
        (var-set counter new-value)
        (ok new-value))))

;; Public: Decrement counter
(define-public (decrement)
  (if (var-get paused)
      (err ERR_PAUSED)
      (let ((current (var-get counter)))
        (if (< current u1)
            (err ERR_UNDERFLOW)
            (let ((new-value (- current u1)))
              (var-set counter new-value)
              (ok new-value))))))

;; Public: Set counter (owner only)
(define-public (set-counter (new-value uint))
  (begin
    (try! (require-owner tx-sender))
    (var-set counter new-value)
    (ok new-value)))

;; Public: Transfer ownership (owner only)
(define-public (transfer-ownership (new-owner principal))
  (begin
    (try! (require-owner tx-sender))
    (var-set owner new-owner)
    (ok true)))

;; Read-only: Get counter value
(define-read-only (get-counter)
  (var-get counter))

;; Read-only: Get owner
(define-read-only (get-owner)
  (var-get owner))

;; Read-only: Check if paused
(define-read-only (is-paused)
  (var-get paused))
