;; escrow-manager.clar
;; Manages escrow for service guarantees

(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u500))
(define-constant err-not-found (err u501))
(define-constant err-already-released (err u502))

(define-map escrows
    uint  ;; escrow-id
    {
        payer: principal,
        payee: principal,
        amount: uint,
        released: bool,
        created-at: uint,
        release-block: uint
    }
)

(define-data-var next-escrow-id uint u1)

(define-public (create-escrow
    (payee principal)
    (amount uint)
    (lock-duration uint)
)
    (let (
        (escrow-id (var-get next-escrow-id))
    )
        (try! (stx-transfer? amount tx-sender contract-owner))
        
        (map-set escrows
            escrow-id
            {
                payer: tx-sender,
                payee: payee,
                amount: amount,
                released: false,
                created-at: stacks-block-height,
                release-block: (+ stacks-block-height lock-duration)
            }
        )
        
        (var-set next-escrow-id (+ escrow-id u1))
        (ok escrow-id)
    )
)

(define-public (release-escrow (escrow-id uint))
    (let (
        (escrow (unwrap! (map-get? escrows escrow-id) err-not-found))
    )
        (asserts! (not (get released escrow)) err-already-released)
        (asserts! (>= stacks-block-height (get release-block escrow)) err-unauthorized)
        (asserts! (is-eq contract-owner tx-sender) err-unauthorized)
        
        (try! (stx-transfer? (get amount escrow) tx-sender (get payee escrow)))
        
        (map-set escrows escrow-id (merge escrow { released: true }))
        (ok true)
    )
)

(define-read-only (get-escrow (escrow-id uint))
    (ok (map-get? escrows escrow-id))
)

