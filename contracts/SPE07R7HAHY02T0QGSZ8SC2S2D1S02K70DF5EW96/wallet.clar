;; Project 1: Secure Multi-User Time-Locked Wallet
;; Version: 3.0 (Clarity 4)

;; --- 1. DATA STORAGE ---
(define-map UserBalances principal uint)
(define-map UserUnlockHeights principal uint)

;; --- 2. ERROR CODES ---
(define-constant ERR-TOO-EARLY (err u101))
(define-constant ERR-NO-DEPOSIT (err u102))
(define-constant ERR-ALREADY-LOCKED (err u103))

;; --- 3. HELPER FUNCTION ---
;; Get the contract's own principal address
(define-private (get-contract-address)
    tx-sender
)

;; --- 4. PUBLIC FUNCTIONS ---

(define-public (deposit (amount uint) (unlock-at uint))
    (let (
        (current-balance (default-to u0 (map-get? UserBalances tx-sender)))
    )
        (asserts! (> unlock-at burn-block-height) ERR-TOO-EARLY)
        (asserts! (is-eq current-balance u0) ERR-ALREADY-LOCKED)
        (asserts! (> amount u0) ERR-NO-DEPOSIT)

        ;; Transfer FROM user TO contract
        (try! (stx-transfer? amount tx-sender (get-contract-address)))

        (map-set UserBalances tx-sender amount)
        (map-set UserUnlockHeights tx-sender unlock-at)
        (ok true)
    )
)

(define-public (withdraw)
    (let (
        (balance (default-to u0 (map-get? UserBalances tx-sender)))
        (unlock-height (default-to u0 (map-get? UserUnlockHeights tx-sender)))
    )
        (asserts! (> balance u0) ERR-NO-DEPOSIT)
        (asserts! (>= burn-block-height unlock-height) ERR-TOO-EARLY)

        ;; Transfer FROM contract TO user
        (try! (stx-transfer? balance (get-contract-address) tx-sender))

        (map-delete UserBalances tx-sender)
        (map-delete UserUnlockHeights tx-sender)

        (ok balance)
    )
)

;; --- 5. READ-ONLY GETTERS ---

(define-read-only (get-my-stats (user principal))
    {
        balance: (default-to u0 (map-get? UserBalances user)),
        unlock-at: (default-to u0 (map-get? UserUnlockHeights user)),
        current-block: burn-block-height
    }
)

(define-read-only (get-contract-balance)
    (stx-get-balance (get-contract-address))
)