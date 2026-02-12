;; Multi-Signature Escrow - Simplified Version
;; Escrow with multiple signature requirements

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u601))
(define-constant err-escrow-not-found (err u602))
(define-constant err-already-signed (err u603))
(define-constant err-not-enough-signatures (err u604))

(define-constant platform-fee-percentage u3)

;; Data Variables
(define-data-var total-escrows uint u0)
(define-data-var total-fees uint u0)

;; Data Maps
(define-map escrows
    uint
    {
        buyer: principal,
        seller: principal,
        amount: uint,
        required-sigs: uint,
        release-sigs: uint,
        refund-sigs: uint,
        expires-at: uint,
        status: (string-ascii 20)
    }
)

(define-map signatures
    { escrow-id: uint, signer: principal }
    {
        signed-release: bool,
        signed-refund: bool
    }
)

;; Read-only
(define-read-only (get-escrow (escrow-id uint))
    (map-get? escrows escrow-id)
)

(define-read-only (get-signature (escrow-id uint) (signer principal))
    (map-get? signatures { escrow-id: escrow-id, signer: signer })
)

(define-read-only (get-total-escrows)
    (ok (var-get total-escrows))
)

;; Create escrow
(define-public (create-escrow (seller principal) (amount uint) (duration uint) (required-sigs uint))
    (let ((escrow-id (+ (var-get total-escrows) u1)))
        (map-set escrows escrow-id
            {
                buyer: tx-sender,
                seller: seller,
                amount: amount,
                required-sigs: required-sigs,
                release-sigs: u0,
                refund-sigs: u0,
                expires-at: (+ stacks-block-height duration),
                status: "pending"
            }
        )
        (var-set total-escrows escrow-id)
        (ok escrow-id)
    )
)

;; Sign for release
(define-public (sign-release (escrow-id uint))
    (let (
        (escrow (unwrap! (map-get? escrows escrow-id) err-escrow-not-found))
        (sig (default-to { signed-release: false, signed-refund: false }
              (map-get? signatures { escrow-id: escrow-id, signer: tx-sender })))
    )
        (asserts! (not (get signed-release sig)) err-already-signed)
        (map-set signatures
            { escrow-id: escrow-id, signer: tx-sender }
            (merge sig { signed-release: true })
        )
        (let (
            (new-count (+ (get release-sigs escrow) u1))
            (updated-escrow (merge escrow { release-sigs: new-count }))
        )
            (map-set escrows escrow-id updated-escrow)
            (if (>= new-count (get required-sigs escrow))
                (release-escrow-internal escrow-id updated-escrow)
                (ok true)
            )
        )
    )
)

;; Sign for refund
(define-public (sign-refund (escrow-id uint))
    (let (
        (escrow (unwrap! (map-get? escrows escrow-id) err-escrow-not-found))
        (sig (default-to { signed-release: false, signed-refund: false }
              (map-get? signatures { escrow-id: escrow-id, signer: tx-sender })))
    )
        (asserts! (not (get signed-refund sig)) err-already-signed)
        (map-set signatures
            { escrow-id: escrow-id, signer: tx-sender }
            (merge sig { signed-refund: true })
        )
        (let (
            (new-count (+ (get refund-sigs escrow) u1))
            (updated-escrow (merge escrow { refund-sigs: new-count }))
        )
            (map-set escrows escrow-id updated-escrow)
            (if (>= new-count (get required-sigs escrow))
                (refund-escrow-internal escrow-id updated-escrow)
                (ok true)
            )
        )
    )
)

(define-private (release-escrow-internal (escrow-id uint) (escrow { buyer: principal, seller: principal, amount: uint, required-sigs: uint, release-sigs: uint, refund-sigs: uint, expires-at: uint, status: (string-ascii 20) }))
    (let (
        (fee (/ (* (get amount escrow) platform-fee-percentage) u100))
        (net-amount (- (get amount escrow) fee))
    )
        (map-set escrows escrow-id (merge escrow { status: "released" }))
        (var-set total-fees (+ (var-get total-fees) fee))
        (ok true)
    )
)

(define-private (refund-escrow-internal (escrow-id uint) (escrow { buyer: principal, seller: principal, amount: uint, required-sigs: uint, release-sigs: uint, refund-sigs: uint, expires-at: uint, status: (string-ascii 20) }))
    (begin
        (map-set escrows escrow-id (merge escrow { status: "refunded" }))
        (ok true)
    )
)
