
;; title: TrustB Escrow
;; version: 1.0.0
;; summary: Secure escrow contract requiring mutual approval for release or cancellation.
;; description: Allows a buyer to lock STX for a seller. Funds are released only when both parties approve. Funds are refunded if both parties cancel.

;; traits
;;

;; token definitions
;;

;; constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-EXISTS (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-COMPLETED (err u103))

(define-constant STATUS-OPEN u1)
(define-constant STATUS-RELEASED u2)
(define-constant STATUS-REFUNDED u3)

;; data vars
(define-data-var escrow-id-nonce uint u0)

;; data maps
(define-map escrows 
    uint 
    {
        buyer: principal,
        seller: principal,
        amount: uint,
        buyer-approved: bool,
        seller-approved: bool,
        buyer-cancelled: bool,
        seller-cancelled: bool,
        status: uint
    }
)

;; public functions

;; @desc Create a new escrow by locking STX
;; @param seller The principal who will receive the funds if released
;; @param amount The amount of uSTX to lock
(define-public (create-escrow (seller principal) (amount uint))
    (let
        (
            (escrow-id (+ (var-get escrow-id-nonce) u1))
            (buyer tx-sender)
        )
        (try! (stx-transfer? amount buyer (as-contract tx-sender)))
        (map-set escrows escrow-id {
            buyer: buyer,
            seller: seller,
            amount: amount,
            buyer-approved: false,
            seller-approved: false,
            buyer-cancelled: false,
            seller-cancelled: false,
            status: STATUS-OPEN
        })
        (var-set escrow-id-nonce escrow-id)
        (ok escrow-id)
    )
)

;; @desc Confirm release of funds (Buyer or Seller)
;; @param escrow-id The ID of the escrow
(define-public (confirm-release (escrow-id uint))
    (let
        (
            (escrow (unwrap! (map-get? escrows escrow-id) ERR-NOT-FOUND))
            (caller tx-sender)
            (is-buyer (is-eq caller (get buyer escrow)))
            (is-seller (is-eq caller (get seller escrow)))
        )
        (asserts! (or is-buyer is-seller) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status escrow) STATUS-OPEN) ERR-ALREADY-COMPLETED)

        ;; Update approvals
        (let
            (
                (new-buyer-approved (if is-buyer true (get buyer-approved escrow)))
                (new-seller-approved (if is-seller true (get seller-approved escrow)))
                (updated-escrow (merge escrow {
                    buyer-approved: new-buyer-approved,
                    seller-approved: new-seller-approved
                }))
            )
            (map-set escrows escrow-id updated-escrow)
            
            ;; Check if both approved
            (if (and new-buyer-approved new-seller-approved)
                (begin
                    (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get seller escrow))))
                    (map-set escrows escrow-id (merge updated-escrow { status: STATUS-RELEASED }))
                    (ok true)
                )
                (ok false)
            )
        )
    )
)

;; @desc Confirm cancellation of escrow (Buyer or Seller)
;; @param escrow-id The ID of the escrow
(define-public (confirm-cancel (escrow-id uint))
    (let
        (
            (escrow (unwrap! (map-get? escrows escrow-id) ERR-NOT-FOUND))
            (caller tx-sender)
            (is-buyer (is-eq caller (get buyer escrow)))
            (is-seller (is-eq caller (get seller escrow)))
        )
        (asserts! (or is-buyer is-seller) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status escrow) STATUS-OPEN) ERR-ALREADY-COMPLETED)

        ;; Update cancellations
        (let
            (
                (new-buyer-cancelled (if is-buyer true (get buyer-cancelled escrow)))
                (new-seller-cancelled (if is-seller true (get seller-cancelled escrow)))
                (updated-escrow (merge escrow {
                    buyer-cancelled: new-buyer-cancelled,
                    seller-cancelled: new-seller-cancelled
                }))
            )
            (map-set escrows escrow-id updated-escrow)
            
            ;; Check if both cancelled
            (if (and new-buyer-cancelled new-seller-cancelled)
                (begin
                    (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get buyer escrow))))
                    (map-set escrows escrow-id (merge updated-escrow { status: STATUS-REFUNDED }))
                    (ok true)
                )
                (ok false)
            )
        )
    )
)

;; read only functions

(define-read-only (get-escrow (escrow-id uint))
    (map-get? escrows escrow-id)
)

;; private functions
;;
