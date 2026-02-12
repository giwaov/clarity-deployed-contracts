

(define-constant ERR-ALREADY-EXISTS (err u100))
(define-constant ERR-INVALID-TIME (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-TOO-EARLY (err u103))

(define-map Capsules
    principal
    {
        amount: uint,
        unlock-height: uint, 
        message: (string-utf8 256)
    }
)


(define-public (create-capsule (unlock-height uint) (amount uint) (message (string-utf8 256)))
    (let
        (
            
            (current-height burn-block-height)
        )
        (asserts! (is-none (map-get? Capsules tx-sender)) ERR-ALREADY-EXISTS)
        
        
        (asserts! (> unlock-height current-height) ERR-INVALID-TIME)

        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (map-set Capsules tx-sender {
            amount: amount,
            unlock-height: unlock-height,
            message: message
        })
        (ok "Capsule Created Successfully")
    )
)


(define-public (claim-capsule)
    (let
        (
            (caller tx-sender)
            (capsule (unwrap! (map-get? Capsules caller) ERR-NOT-FOUND))
            (unlock-height (get unlock-height capsule))
            (amount (get amount capsule))
            (current-height burn-block-height)
        )
        (asserts! (>= current-height unlock-height) ERR-TOO-EARLY)

        (try! (as-contract (stx-transfer? amount tx-sender caller)))
        (map-delete Capsules caller)
        (ok "Capsule Claimed!")
    )
)


(define-read-only (get-capsule (user principal))
    (map-get? Capsules user)
)