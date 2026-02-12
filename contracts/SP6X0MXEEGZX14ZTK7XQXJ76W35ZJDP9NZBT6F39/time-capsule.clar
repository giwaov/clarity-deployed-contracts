;; Contract Name: time-capsule
;; Description: Standard Clarity 2. Robust and secure.


(define-constant UNLOCK-HEIGHT u950000) ;; Remember to change this if testing soon!
(define-constant ERR-TOO-EARLY (err u201))
(define-constant ERR-NO-BALANCE (err u202))

(define-map deposits principal uint)

(define-public (deposit (amount uint))
    (let
        (
            (current-balance (default-to u0 (map-get? deposits tx-sender)))
            ;; Standard way to get contract address
            (vault (as-contract tx-sender))
        )
        ;; Transfer from User -> Contract (Vault)
        (try! (stx-transfer? amount tx-sender vault))
        
        (map-set deposits tx-sender (+ current-balance amount))
        (ok true)
    )
)

(define-public (withdraw)
    (let
        (
            (caller tx-sender)
            (balance (default-to u0 (map-get? deposits caller)))
        )
        ;; 1. Check Time
        (asserts! (>= burn-block-height UNLOCK-HEIGHT) ERR-TOO-EARLY)
        ;; 2. Check Balance
        (asserts! (> balance u0) ERR-NO-BALANCE)
        
        ;; 3. Update Map (Checks-Effects-Interactions)
        (map-set deposits caller u0)
        
        ;; 4. Send Funds Back (Contract -> User)
        ;; 'as-contract' switches context to the contract
        (as-contract (stx-transfer? balance tx-sender caller))
    )
)

(define-read-only (get-lock-status)
    (ok {
        current-height: burn-block-height,
        unlock-height: UNLOCK-HEIGHT,
        is-unlocked: (>= burn-block-height UNLOCK-HEIGHT)
    })
)