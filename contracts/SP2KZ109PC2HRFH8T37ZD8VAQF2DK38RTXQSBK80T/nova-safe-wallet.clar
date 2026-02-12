
;; nova-safe-wallet.clar
;; M-of-N multisig wallet for treasury management in Nova Protocol.
;; CLARITY VERSION: 2

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-THRESHOLD (err u101))
(define-constant ERR-OWNER-EXISTS (err u102))
(define-constant ERR-TX-NOT-FOUND (err u103))

(define-data-var threshold uint u2)
(define-data-var owners (list 20 principal) (list))
(define-data-var tx-nonce uint u0)

(define-map transactions
    uint
    {
        destination: principal,
        amount: uint,
        confirmed-by: (list 20 principal),
        executed: bool
    }
)

(define-public (init (initial-owners (list 20 principal)) (initial-threshold uint))
    (begin
        (asserts! (is-eq (len (var-get owners)) u0) ERR-NOT-AUTHORIZED) ;; Only once
        (asserts! (<= initial-threshold (len initial-owners)) ERR-INVALID-THRESHOLD)
        (var-set owners initial-owners)
        (var-set threshold initial-threshold)
        (ok true)
    )
)

(define-public (submit-transaction (destination principal) (amount uint))
    (let (
        (sender tx-sender)
    )
    (asserts! (is-some (index-of (var-get owners) sender)) ERR-NOT-AUTHORIZED)
    
    (let ((tx-id (var-get tx-nonce)))
        (map-set transactions tx-id {
            destination: destination,
            amount: amount,
            confirmed-by: (list sender),
            executed: false
        })
        (var-set tx-nonce (+ tx-id u1))
        (ok tx-id)
    )
    )
)

(define-public (confirm-transaction (tx-id uint))
    (let (
        (sender tx-sender)
        (tx (unwrap! (map-get? transactions tx-id) ERR-TX-NOT-FOUND))
    )
    (asserts! (is-some (index-of (var-get owners) sender)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get executed tx)) (err u104))
    (asserts! (is-none (index-of (get confirmed-by tx) sender)) (err u105))

    (let (
        (new-confirmed-by (unwrap-panic (as-max-len? (append (get confirmed-by tx) sender) u20)))
    )
        (map-set transactions tx-id (merge tx { confirmed-by: new-confirmed-by }))
        
        (if (>= (len new-confirmed-by) (var-get threshold))
            (begin
                (try! (as-contract (stx-transfer? (get amount tx) tx-sender (get destination tx))))
                (map-set transactions tx-id (merge tx { confirmed-by: new-confirmed-by, executed: true }))
                (ok true)
            )
            (ok false)
        )
    )
    )
)
