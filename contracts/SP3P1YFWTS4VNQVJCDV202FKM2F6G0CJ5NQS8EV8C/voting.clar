;; Simple voting contract
(define-data-var proposal-active bool true)
(define-data-var votes-yes uint u0)
(define-data-var votes-no uint u0)
(define-map voters principal bool)

(define-read-only (get-vote-counts)
  {yes: (var-get votes-yes), no: (var-get votes-no)}
)

(define-public (vote-yes)
  (begin
    (asserts! (var-get proposal-active) (err u1))
    (asserts! (not (default-to false (map-get? voters tx-sender))) (err u2))
    (map-set voters tx-sender true)
    (ok (var-set votes-yes (+ (var-get votes-yes) u1)))
  )
)

(define-public (vote-no)
  (begin
    (asserts! (var-get proposal-active) (err u1))
    (asserts! (not (default-to false (map-get? voters tx-sender))) (err u2))
    (map-set voters tx-sender true)
    (ok (var-set votes-no (+ (var-get votes-no) u1)))
  )
)

(define-public (close-voting)
  (ok (var-set proposal-active false))
)
