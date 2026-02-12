;; ---------------------------------------------------------
;; Task Payout
;; Pays contributors in STX
;; ---------------------------------------------------------


(define-public (payout (worker principal) (amount uint))
  (begin
    ;; Transfer STX from this contract to the worker
    (as-contract
      (try! (stx-transfer? amount tx-sender worker))
    )
    (ok amount)
  )
)


(define-public (fund (amount uint))
    (begin
        ;; Transfers STX from user to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (ok amount)
    )
)
