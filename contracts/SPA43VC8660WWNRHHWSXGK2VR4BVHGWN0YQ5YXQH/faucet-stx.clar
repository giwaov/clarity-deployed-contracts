;; simple-faucet-stx.clar
;; Fund this contract with STX, then anyone can withdraw a fixed amount if available.

(define-constant ERR-NOT-ENOUGH u100)

(define-constant WITHDRAW-AMOUNT u1000) ;; microstacks

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender)))

(define-public (withdraw)
  (let ((bal (stx-get-balance (as-contract tx-sender))))
    (if (>= bal WITHDRAW-AMOUNT)
      (begin
        (try! (as-contract (stx-transfer? WITHDRAW-AMOUNT tx-sender tx-sender)))
        (ok WITHDRAW-AMOUNT))
      (err ERR-NOT-ENOUGH))))
