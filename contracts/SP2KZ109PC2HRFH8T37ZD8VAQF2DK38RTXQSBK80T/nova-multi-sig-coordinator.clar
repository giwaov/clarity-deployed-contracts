
;; Nova Multi-Sig Coordinator
;; Coordinates multi-signature transaction approvals

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-CONFIRMED (err u101))
(define-constant ERR-INVALID-TX (err u102))

(define-data-var required-signatures uint u2)
(define-data-var owner-count uint u3)

(define-map transactions 
    { tx-id: uint }
    { 
        destination: principal,
        amount: uint,
        execution-height: uint,
        confirmations: uint,
        executed: bool
    }
)

(define-map confirmations 
    { tx-id: uint, owner: principal }
    { confirmed: bool }
)

(define-data-var tx-nonce uint u0)

(define-public (submit-transaction (destination principal) (amount uint))
    (let
        (
            (tx-id (+ (var-get tx-nonce) u1))
        )
        (var-set tx-nonce tx-id)
        (ok (map-set transactions 
            { tx-id: tx-id }
            {
                destination: destination,
                amount: amount,
                execution-height: block-height,
                confirmations: u0,
                executed: false
            }
        ))
    )
)

(define-public (confirm-transaction (tx-id uint))
    (let
        (
            (tx (unwrap! (map-get? transactions { tx-id: tx-id }) ERR-INVALID-TX))
            (is-confirmed (default-to { confirmed: false } (map-get? confirmations { tx-id: tx-id, owner: tx-sender })))
        )
        (asserts! (not (get confirmed is-confirmed)) ERR-ALREADY-CONFIRMED)
        
        (map-set confirmations { tx-id: tx-id, owner: tx-sender } { confirmed: true })
        (ok (map-set transactions
            { tx-id: tx-id }
            (merge tx { confirmations: (+ (get confirmations tx) u1) })
        ))
    )
)
