;; --------------------------------------------------
;; Level 6 - Governance & VIP Voting (FIXED)
;; --------------------------------------------------

;; Constants
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-NOT-VIP (err u403))
(define-constant VIP-LIMIT u10000000) ;; 10 STX

;; Data Vars
(define-data-var owner principal tx-sender)
(define-data-var contract-paused bool false)
(define-data-var yes-votes uint u0)
(define-data-var no-votes uint u0)

;; Maps
(define-map user-data principal { count: uint, amount: uint })
(define-map vips principal bool)
(define-map has-voted principal bool)

;; --- Public Functions ---

;; 1. Send Tip & Automatic VIP Promo
(define-public (send-tip (recipient principal) (amount uint))
    (let
        (
            (sender tx-sender)
            (previous-data (default-to { count: u0, amount: u0 } (map-get? user-data sender)))
            (new-amount (+ (get amount previous-data) amount))
        )
        (asserts! (not (var-get contract-paused)) (err u402))
        (try! (stx-transfer? amount sender recipient))

        (map-set user-data sender { count: (+ (get count previous-data) u1), amount: new-amount })
        
        ;; Ajuste: El if ahora devuelve un booleano consistente
        (if (>= new-amount VIP-LIMIT)
            (ok (map-set vips sender true))
            (ok true)
        )
    )
)

;; 2. Vote (Only for VIPs)
(define-public (vote-on-status (vote bool))
    (let ((is-vip (default-to false (map-get? vips tx-sender))))
        (asserts! is-vip ERR-NOT-VIP)
        (asserts! (is-none (map-get? has-voted tx-sender)) (err u405))

        (if vote
            (var-set yes-votes (+ (var-get yes-votes) u1))
            (var-set no-votes (+ (var-get no-votes) u1))
        )
        
        (map-set has-voted tx-sender true)
        (ok true)
    )
)

;; 3. Admin: Reset Poll
(define-public (reset-poll)
    (begin
        (asserts! (is-eq tx-sender (var-get owner)) ERR-UNAUTHORIZED)
        (var-set yes-votes u0)
        (var-set no-votes u0)
        (ok true)
    )
)

;; --- Read-only Functions ---

(define-read-only (get-voting-results)
    {
        yes: (var-get yes-votes),
        no: (var-get no-votes),
        total-voters: (+ (var-get yes-votes) (var-get no-votes))
    }
)

(define-read-only (get-user-status (user principal))
    {
        is-vip: (default-to false (map-get? vips user)),
        has-voted: (default-to false (map-get? has-voted user)),
        stats: (default-to { count: u0, amount: u0 } (map-get? user-data user))
    }
)
