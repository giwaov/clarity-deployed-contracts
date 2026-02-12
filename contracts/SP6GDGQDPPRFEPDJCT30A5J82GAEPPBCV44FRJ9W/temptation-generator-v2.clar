;; ============================================
;; TEMPTATION GENERATOR - Random Events
;; Clarity 2 Smart Contract
;; ============================================

(define-constant ERR_NO_EVENT (err u404))

(define-read-only (get-current-temptation)
  (if (is-eq (mod burn-block-height u100) u0)
    (ok { name: "Flash Bonus", bonus: u10000000 }) ;; 10 STX
    (err ERR_NO_EVENT)
  )
)

(define-public (claim-temptation)
  (let
    (
      (event (unwrap! (get-current-temptation) ERR_NO_EVENT))
    )
    (contract-call? .procrastination-vault apply-temptation-bonus tx-sender (get bonus event))
  )
)
