;; Royalty Splitter Contract
;; Split payments among multiple recipients

(define-constant err-not-recipient (err u100))
(define-constant err-no-balance (err u101))
(define-constant err-invalid-shares (err u102))

(define-data-var total-shares uint u0)
(define-data-var total-released uint u0)

(define-map shares principal uint)
(define-map released principal uint)

(define-public (initialize-recipients (recipients (list 20 {recipient: principal, shares: uint})))
    (begin
        (asserts! (is-eq (var-get total-shares) u0) err-invalid-shares)
        (fold process-recipient recipients {total: u0})
        (ok true)
    )
)

(define-private (process-recipient 
    (recipient-data {recipient: principal, shares: uint})
    (state {total: uint}))
    (begin
        (map-set shares (get recipient recipient-data) (get shares recipient-data))
        {total: (+ (get total state) (get shares recipient-data))}
    )
)

(define-public (release-payment (recipient principal))
    (let
        (
            (recipient-shares (unwrap! (map-get? shares recipient) err-not-recipient))
            (total-received (stx-get-balance (as-contract tx-sender)))
            (already-released (default-to u0 (map-get? released recipient)))
            (payment (- (/ (* total-received recipient-shares) (var-get total-shares)) already-released))
        )
        (asserts! (> payment u0) err-no-balance)
        
        (try! (as-contract (stx-transfer? payment tx-sender recipient)))
        (map-set released recipient (+ already-released payment))
        (var-set total-released (+ (var-get total-released) payment))
        (ok payment)
    )
)

(define-public (receive-payment)
    (ok true)
)

(define-read-only (get-shares (recipient principal))
    (map-get? shares recipient)
)

(define-read-only (get-released (recipient principal))
    (default-to u0 (map-get? released recipient))
)

(define-read-only (get-pending-payment (recipient principal))
    (match (map-get? shares recipient)
        recipient-shares
        (let
            (
                (total-received (stx-get-balance (as-contract tx-sender)))
                (already-released (default-to u0 (map-get? released recipient)))
            )
            (- (/ (* total-received recipient-shares) (var-get total-shares)) already-released)
        )
        u0
    )
)
