;; --------------------------------------------------
;; Level 5 - Ultra-Compatible Version
;; --------------------------------------------------

;; 1. Constants
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-PAUSED (err u402))
(define-constant VIP-LIMIT u10000000) ;; 10 STX

;; 2. Data Vars
(define-data-var owner-address principal tx-sender)
(define-data-var contract-paused bool false)
(define-data-var global-total-stx uint u0)

;; 3. Maps
(define-map user-data principal { count: uint, amount: uint })
(define-map vips principal bool)

;; 4. Public Functions

(define-public (send-tip (recipient principal) (amount uint))
    (let
        (
            (sender tx-sender)
            (previous-data (default-to { count: u0, amount: u0 } (map-get? user-data sender)))
            (new-amount (+ (get amount previous-data) amount))
            (new-count (+ (get count previous-data) u1))
        )
        ;; Checks
        (asserts! (not (var-get contract-paused)) ERR-PAUSED)
        (asserts! (> amount u0) (err u100))

        ;; Transfer
        (try! (stx-transfer? amount sender recipient))

        ;; Updates
        (map-set user-data sender { count: new-count, amount: new-amount })
        (var-set global-total-stx (+ (var-get global-total-stx) amount))

        ;; VIP Logic (Simple if-else)
        (if (>= new-amount VIP-LIMIT)
            (map-set vips sender true)
            false
        )

        (ok new-amount)
    )
)

(define-public (toggle-pause (status bool))
    (begin
        (asserts! (is-eq tx-sender (var-get owner-address)) ERR-UNAUTHORIZED)
        (var-set contract-paused status)
        (ok status)
    )
)

;; 5. Read-only Functions
(define-read-only (get-user-info (user principal))
    (let
        (
            (is-vip (default-to false (map-get? vips user)))
            (stats (default-to { count: u0, amount: u0 } (map-get? user-data user)))
        )
        { vip: is-vip, stats: stats }
    )
)

(define-read-only (get-global-stats)
    {
        total: (var-get global-total-stx),
        paused: (var-get contract-paused),
        owner: (var-get owner-address)
    }
)
