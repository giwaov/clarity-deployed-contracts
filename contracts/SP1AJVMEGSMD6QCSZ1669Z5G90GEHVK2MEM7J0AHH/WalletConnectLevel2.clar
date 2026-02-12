;; ----------------------------------------
;; WalletConnect Tips Contract (SAFE)
;; ----------------------------------------

(define-data-var total-tipped uint u0)
(define-map tips-by-recipient principal uint)

;; Error codes
(define-constant ERR_INVALID_AMOUNT u100)
(define-constant ERR_TRANSFER_FAILED u101)

;; Public: send STX tip
(define-public (send-tip (recipient principal) (amount uint))
  (begin
    ;; amount must be > 0
    (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))

    ;; try transfer
    (asserts!
      (is-ok (stx-transfer? amount tx-sender recipient))
      (err ERR_TRANSFER_FAILED)
    )

    ;; update totals
    (var-set total-tipped (+ (var-get total-tipped) amount))

    (map-set
      tips-by-recipient
      recipient
      (+ amount (default-to u0 (map-get? tips-by-recipient recipient)))
    )

    (ok amount)
  )
)

;; Read-only: global total
(define-read-only (get-total-tipped)
  (var-get total-tipped)
)

;; Read-only: tips received by address
(define-read-only (get-tips-for (recipient principal))
  (default-to u0 (map-get? tips-by-recipient recipient))
)
