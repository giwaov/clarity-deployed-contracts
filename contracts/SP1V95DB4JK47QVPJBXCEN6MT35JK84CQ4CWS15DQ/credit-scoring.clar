(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))

(define-map credit-scores
  principal
  {
    score: uint,
    payment-history: uint,
    credit-utilization: uint,
    account-age: uint,
    total-loans: uint,
    defaults: uint,
    last-updated: uint
  })

(define-map authorized-reporters principal bool)

(define-read-only (get-credit-score (user principal))
  (ok (map-get? credit-scores user)))

(define-read-only (is-authorized (reporter principal))
  (ok (default-to false (map-get? authorized-reporters reporter))))

(define-public (authorize-reporter (reporter principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set authorized-reporters reporter true))))

(define-public (revoke-reporter (reporter principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-delete authorized-reporters reporter))))

(define-public (update-score (user principal) (payment-hist uint) (util uint) (age uint) (loans uint) (defaults uint))
  (let ((score (calculate-score payment-hist util age loans defaults)))
    (asserts! (default-to false (map-get? authorized-reporters tx-sender)) err-unauthorized)
    (ok (map-set credit-scores user
      {score: score, payment-history: payment-hist, credit-utilization: util,
       account-age: age, total-loans: loans, defaults: defaults, last-updated: stacks-block-height}))))

(define-private (calculate-score (payment uint) (util uint) (age uint) (loans uint) (defaults uint))
  (let ((base-score (+ (* payment u35) (* (- u100 util) u30))))
    (+ base-score (+ (* age u20) (- (* loans u10) (* defaults u50))))))

(define-public (report-payment (user principal) (on-time bool))
  (let ((current (default-to {score: u0, payment-history: u0, credit-utilization: u50,
                               account-age: u0, total-loans: u0, defaults: u0, last-updated: u0}
                             (map-get? credit-scores user))))
    (asserts! (default-to false (map-get? authorized-reporters tx-sender)) err-unauthorized)
    (ok (map-set credit-scores user
      (merge current {payment-history: (if on-time
        (+ (get payment-history current) u1)
        (get payment-history current))})))))
