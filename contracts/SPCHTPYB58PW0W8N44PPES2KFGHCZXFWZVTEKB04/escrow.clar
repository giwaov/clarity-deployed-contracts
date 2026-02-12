;; Simple Escrow Contract
;; Holds STX in escrow until both parties agree to release

(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-already-exists (err u101))
(define-constant err-not-found (err u102))
(define-constant err-already-released (err u103))

(define-map escrows
    uint
    {
        buyer: principal,
        seller: principal,
        amount: uint,
        buyer-approved: bool,
        seller-approved: bool,
        released: bool
    }
)

(define-data-var escrow-nonce uint u0)

;; Create new escrow
(define-public (create-escrow (seller principal) (amount uint))
    (let
        (
            (escrow-id (var-get escrow-nonce))
        )
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set escrows escrow-id {
            buyer: tx-sender,
            seller: seller,
            amount: amount,
            buyer-approved: false,
            seller-approved: false,
            released: false
        })
        (var-set escrow-nonce (+ escrow-id u1))
        (ok escrow-id)
    )
)

;; Buyer approves release
(define-public (buyer-approve (escrow-id uint))
    (let
        (
            (escrow (unwrap! (map-get? escrows escrow-id) err-not-found))
        )
        (asserts! (is-eq tx-sender (get buyer escrow)) err-not-authorized)
        (asserts! (not (get released escrow)) err-already-released)
        (map-set escrows escrow-id (merge escrow {buyer-approved: true}))
        (try! (release-if-ready escrow-id))
        (ok true)
    )
)

;; Seller approves release
(define-public (seller-approve (escrow-id uint))
    (let
        (
            (escrow (unwrap! (map-get? escrows escrow-id) err-not-found))
        )
        (asserts! (is-eq tx-sender (get seller escrow)) err-not-authorized)
        (asserts! (not (get released escrow)) err-already-released)
        (map-set escrows escrow-id (merge escrow {seller-approved: true}))
        (try! (release-if-ready escrow-id))
        (ok true)
    )
)

;; Release funds if both parties approved
(define-private (release-if-ready (escrow-id uint))
    (let
        (
            (escrow (unwrap! (map-get? escrows escrow-id) err-not-found))
        )
        (if (and (get buyer-approved escrow) (get seller-approved escrow))
            (begin
                (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get seller escrow))))
                (map-set escrows escrow-id (merge escrow {released: true}))
                (ok true)
            )
            (ok false)
        )
    )
)

;; Read-only functions
(define-read-only (get-escrow (escrow-id uint))
    (map-get? escrows escrow-id)
)
