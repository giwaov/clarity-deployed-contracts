;; simple-faucet-stx.clar
;; Fund this contract with STX, then anyone can withdraw a fixed amount if available.

(define-constant ERR-NOT-ENOUGH u100)

(define-constant WITHDRAW-AMOUNT u1000) ;; microstacks

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender)))


(define-constant ERR-INVALID-AMOUNT u101)

(define-public (withdraw (amount uint))
  (let ((bal (stx-get-balance (as-contract tx-sender))))
    ;; Assert amount is between 1 and 3 uSTX (inclusive)
    (asserts! (and (>= amount u1) (<= amount u3)) (err ERR-INVALID-AMOUNT))
    (if (>= bal amount)
      (begin
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (ok amount))
      (err ERR-NOT-ENOUGH))))
