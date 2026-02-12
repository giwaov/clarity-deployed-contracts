;; simple-escrow-stx.clar
;; Payer deposits STX to contract; payee can claim after payer approves.

(define-constant ERR-NOT-PAYER u201)
(define-constant ERR-NOT-PAYEE u202)
(define-constant ERR-NOT-APPROVED u203)

(define-data-var payer principal tx-sender)
(define-data-var payee principal tx-sender)
(define-data-var amount uint u0)
(define-data-var approved bool false)

(define-public (init (p principal) (q principal) (a uint))
  (begin
    (var-set payer p)
    (var-set payee q)
    (var-set amount a)
    (var-set approved false)
    (ok true)))

(define-public (deposit)
  (let ((a (var-get amount)))
    (begin
      (try! (stx-transfer? a tx-sender (as-contract tx-sender)))
      (ok a))))

(define-public (approve)
  (if (is-eq tx-sender (var-get payer))
    (begin (var-set approved true) (ok true))
    (err ERR-NOT-PAYER)))

(define-public (claim)
  (if (is-eq tx-sender (var-get payee))
    (if (var-get approved)
      (begin
        (try! (as-contract (stx-transfer? (var-get amount) tx-sender (var-get payee))))
        (ok true))
      (err ERR-NOT-APPROVED))
    (err ERR-NOT-PAYEE)))
