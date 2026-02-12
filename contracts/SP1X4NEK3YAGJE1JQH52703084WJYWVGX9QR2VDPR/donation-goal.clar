;; Milestone Donation Goal Contract
(define-constant CONTRACT-OWNER tx-sender)
(define-constant TARGET-GOAL u100000000) ;; 100 STX

(define-data-var total-donated uint u0)
(define-map donor-contributions principal uint)

;; --- Read-only functions ---
(define-read-only (get-donation-amount (donor principal))
  (default-to u0 (map-get? donor-contributions donor))
)

(define-read-only (get-percentage-reached)
  (ok (/ (* (var-get total-donated) u100) TARGET-GOAL))
)

;; --- Public functions ---
(define-public (donate (amount uint))
  (begin
    (asserts! (> amount u0) (err u100))

    ;; Track donation
    (var-set total-donated (+ (var-get total-donated) amount))
    (map-set donor-contributions tx-sender
      (+ (default-to u0 (map-get? donor-contributions tx-sender)) amount))
    (ok true)
  )
)

(define-public (withdraw-funds)
  (begin
    ;; Only owner can withdraw
    (asserts! (is-eq tx-sender CONTRACT-OWNER) (err u101))

    ;; Ensure goal reached
    (asserts! (>= (var-get total-donated) TARGET-GOAL) (err u102))

    ;; Withdraw contract balance to owner
    (stx-transfer? (stx-get-balance tx-sender) tx-sender CONTRACT-OWNER)
  )
)
