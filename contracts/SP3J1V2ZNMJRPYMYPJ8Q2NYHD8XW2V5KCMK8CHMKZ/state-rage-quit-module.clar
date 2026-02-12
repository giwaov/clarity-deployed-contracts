;; state-rage-quit-module.clar
;; Part of State Protocol
;; CLARITY VERSION: 2

(define-constant err-not-authorized (err u100))
(define-data-var contract-status (string-ascii 20) "active")

(define-read-only (get-status) (ok (var-get contract-status)))

(define-public (set-status (new-status (string-ascii 20)))
  (begin (var-set contract-status new-status) (ok true)))
