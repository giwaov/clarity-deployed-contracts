;; simple-owner.clar

(define-constant ERR-NOT-OWNER u401)
(define-data-var owner principal tx-sender)

(define-read-only (get-owner) (var-get owner))

(define-public (transfer-ownership (new-owner principal))
  (if (is-eq tx-sender (var-get owner))
    (begin (var-set owner new-owner) (ok true))
    (err ERR-NOT-OWNER)))
