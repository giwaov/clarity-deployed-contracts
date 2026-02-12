
;; escrow-service.clar
;; Neutral third-party hold for two-party transactions.
;; CLARITY VERSION: 2

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-RELEASED (err u101))

(define-map escrows
    uint
    {
        buyer: principal,
        seller: principal,
        arbiter: principal,
        amount: uint,
        state: (string-ascii 10) ;; "OPEN", "RELEASED", "REFUNDED"
    }
)

(define-data-var escrow-nonce uint u0)

(define-public (create-escrow (seller principal) (arbiter principal) (amount uint))
    (let (
        (id (var-get escrow-nonce))
        (sender tx-sender)
    )
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    
    (map-set escrows id {
        buyer: sender,
        seller: seller,
        arbiter: arbiter,
        amount: amount,
        state: "OPEN"
    })
    (var-set escrow-nonce (+ id u1))
    (ok id))
)

(define-public (release (id uint))
    (let (
        (escrow (unwrap! (map-get? escrows id) (err u102)))
        (sender tx-sender)
    )
    (asserts! (or (is-eq sender (get buyer escrow)) (is-eq sender (get arbiter escrow))) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get state escrow) "OPEN") ERR-ALREADY-RELEASED)

    (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get seller escrow))))
    
    (map-set escrows id (merge escrow { state: "RELEASED" }))
    (ok true))
)

(define-public (refund (id uint))
    (let (
        (escrow (unwrap! (map-get? escrows id) (err u102)))
        (sender tx-sender)
    )
    (asserts! (or (is-eq sender (get seller escrow)) (is-eq sender (get arbiter escrow))) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get state escrow) "OPEN") ERR-ALREADY-RELEASED)

    (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get buyer escrow))))
    
    (map-set escrows id (merge escrow { state: "REFUNDED" }))
    (ok true))
)
