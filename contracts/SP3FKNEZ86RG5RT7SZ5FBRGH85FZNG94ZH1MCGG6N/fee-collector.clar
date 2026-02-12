;; Fee Collector Contract - Simplified Demo
;; Demonstrates Clarity 4 function usage

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))

;; Storage
(define-data-var total-fees-collected uint u0)
(define-data-var fee-count uint u0)

;; Collect fee demo
(define-public (collect-fee-demo (amount uint))
  (begin
    (var-set fee-count (+ (var-get fee-count) u1))
    (var-set total-fees-collected (+ (var-get total-fees-collected) amount))
    (ok (var-get fee-count))))

;; Read-only functions
(define-read-only (get-total-fees)
  (var-get total-fees-collected))

(define-read-only (get-current-time)
  stacks-block-time)

(define-read-only (demo-to-ascii (value uint))
  (to-ascii? value))
