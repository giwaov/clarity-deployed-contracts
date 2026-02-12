;; tip-jar.clar
;; Community tip jar with global stats

;; Constants
(define-constant CONTRACT-ADDRESS .tip-jar)
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-OWNER (err u100))
(define-constant ERR-ZERO-AMOUNT (err u101))

;; Data Variables
(define-data-var total-tips-received uint u0)
(define-data-var tip-count uint u0)

;; Maps
(define-map tipper-totals principal uint)
(define-map tip-history uint { tipper: principal, amount: uint, message: (string-ascii 64), timestamp: uint })

;; Public Functions
(define-public (tip (message (string-ascii 64)) (amount uint))
  (let (
    (tip-id (+ (var-get tip-count) u1))
    (current-total (default-to u0 (map-get? tipper-totals tx-sender)))
  )
    (begin
      (asserts! (> amount u0) ERR-ZERO-AMOUNT)
      (asserts! (> (len message) u0) (err u102))
      (unwrap-panic (stx-transfer? amount tx-sender CONTRACT-ADDRESS))
      
      (map-set tipper-totals tx-sender (+ current-total amount))
      (map-set tip-history tip-id {
        tipper: tx-sender,
        amount: amount,
        message: message,
        timestamp: stacks-block-time
      })
      
      (var-set total-tips-received (+ (var-get total-tips-received) amount))
      (var-set tip-count tip-id)
      (print { event: "tip-received", tipper: tx-sender, amount: amount })
      (ok tip-id)
    )
  )
)

(define-public (withdraw)
  (let ((balance (stx-get-balance CONTRACT-ADDRESS)))
    (begin
      (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-OWNER)
      (try! (stx-transfer? balance CONTRACT-ADDRESS CONTRACT-OWNER))
      (ok balance)
    )
  )
)

;; Read-only
(define-read-only (get-stats)
  {
    total-received: (var-get total-tips-received),
    count: (var-get tip-count),
    owner: CONTRACT-OWNER
  }
)

(define-read-only (get-tip-history (id uint))
  (map-get? tip-history id)
)
