;; number-guess.clar
;; Simple number guessing game with betting

(define-data-var secret-number uint u42)
(define-constant COST u10)

(define-public (guess (number uint))
    (begin
        (try! (stx-transfer? COST tx-sender (as-contract tx-sender)))
        (if (is-eq number (var-get secret-number))
            (begin
                ;; Winner gets 2x
                (try! (as-contract (stx-transfer? (* COST u2) tx-sender tx-sender)))
                (ok true)
            )
            (ok false)
        )
    )
)

(define-public (set-secret (number uint))
    (begin
        ;; In reality owner check needed
        (var-set secret-number number)
        (ok true)
    )
)
