;; Simple Test Contract
;; Basic contract to test deployment

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))

(define-data-var counter uint u0)

(define-public (increment)
    (begin
        (var-set counter (+ (var-get counter) u1))
        (ok (var-get counter))
    )
)

(define-read-only (get-counter)
    (var-get counter)
)

(define-public (set-counter (value uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set counter value)
        (ok value)
    )
)