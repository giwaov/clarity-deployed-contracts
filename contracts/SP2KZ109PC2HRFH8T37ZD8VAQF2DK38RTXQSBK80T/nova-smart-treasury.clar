
;; Nova Smart Treasury
;; Automated treasury management with allocation strategies

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-FUNDS (err u101))

(define-data-var treasury-balance uint u0)
(define-data-var admin principal tx-sender)

(define-map allocation-strategies
    { strategy-id: uint }
    {
        name: (string-ascii 64),
        allocation-percent: uint,
        recipient: principal
    }
)

(define-public (deposit (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set treasury-balance (+ (var-get treasury-balance) amount))
        (ok true)
    )
)

(define-public (add-strategy (id uint) (name (string-ascii 64)) (percent uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
        (ok (map-set allocation-strategies
            { strategy-id: id }
            {
                name: name,
                allocation-percent: percent,
                recipient: recipient
            }
        ))
    )
)

(define-public (execute-strategy (id uint))
    (let
        (
            (strategy (unwrap! (map-get? allocation-strategies { strategy-id: id }) (err u404)))
            (amount (/ (* (var-get treasury-balance) (get allocation-percent strategy)) u100))
        )
        (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
        (try! (as-contract (stx-transfer? amount tx-sender (get recipient strategy))))
        (var-set treasury-balance (- (var-get treasury-balance) amount))
        (ok amount)
    )
)
