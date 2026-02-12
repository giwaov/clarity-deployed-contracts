;; sip010-token.clar
(define-fungible-token demo-token)

(define-read-only (get-name) (ok "Demo Token"))
(define-read-only (get-symbol) (ok "DT"))
(define-read-only (get-decimals) (ok u6))
(define-read-only (get-total-supply)
  (ok (ft-get-supply demo-token)))

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (ft-mint? demo-token amount recipient)))

(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (ft-transfer? demo-token amount sender recipient))

(define-constant contract-owner tx-sender)
