;; simple-sip010-token.clar
;; Minimal SIP-010-like fungible token (not fully featured).

(define-constant ERR-NOT-AUTH u401)
(define-constant ERR-INSUFFICIENT u402)

(define-fungible-token simple-token)

(define-data-var owner principal tx-sender)
(define-data-var name (string-ascii 32) "Simple Token")
(define-data-var symbol (string-ascii 10) "SIMP")
(define-data-var decimals uint u6)

(define-public (mint (amount uint) (recipient principal))
  (if (is-eq tx-sender (var-get owner))
    (begin
      (try! (ft-mint? simple-token amount recipient))
      (ok true))
    (err ERR-NOT-AUTH)))

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (if (is-eq tx-sender sender)
    (match (ft-transfer? simple-token amount sender recipient)
      ok-val (ok true)
      err-val (err ERR-INSUFFICIENT))
    (err ERR-NOT-AUTH)))

(define-read-only (get-name) (ok (var-get name)))
(define-read-only (get-symbol) (ok (var-get symbol)))
(define-read-only (get-decimals) (ok (var-get decimals)))
(define-read-only (get-balance (who principal)) (ok (ft-get-balance simple-token who)))
(define-read-only (get-total-supply) (ok (ft-get-supply simple-token)))
