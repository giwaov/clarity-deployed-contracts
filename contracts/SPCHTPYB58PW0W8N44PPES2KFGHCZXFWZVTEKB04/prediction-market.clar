;; Prediction Market Contract
;; Bet on future outcomes

(define-constant err-market-closed (err u100))
(define-constant err-market-not-resolved (err u101))
(define-constant err-not-authorized (err u102))
(define-constant err-already-claimed (err u103))

(define-data-var market-nonce uint u0)

(define-map markets
    uint
    {
        creator: principal,
        question: (string-utf8 500),
        end-block: uint,
        total-yes: uint,
        total-no: uint,
        resolved: bool,
        outcome: (optional bool)
    }
)

(define-map positions
    {market-id: uint, user: principal}
    {
        yes-amount: uint,
        no-amount: uint,
        claimed: bool
    }
)

(define-public (create-market (question (string-utf8 500)) (duration uint))
    (let ((market-id (var-get market-nonce)))
        (map-set markets market-id {
            creator: tx-sender,
            question: question,
            end-block: (+ block-height duration),
            total-yes: u0,
            total-no: u0,
            resolved: false,
            outcome: none
        })
        (var-set market-nonce (+ market-id u1))
        (ok market-id)
    )
)

(define-public (bet (market-id uint) (bet-yes bool) (amount uint))
    (let
        (
            (market (unwrap! (map-get? markets market-id) err-market-closed))
            (position-key {market-id: market-id, user: tx-sender})
            (current-position (default-to {yes-amount: u0, no-amount: u0, claimed: false} 
                              (map-get? positions position-key)))
        )
        (asserts! (< block-height (get end-block market)) err-market-closed)
        (asserts! (not (get resolved market)) err-market-closed)
        
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (if bet-yes
            (begin
                (map-set markets market-id (merge market {
                    total-yes: (+ (get total-yes market) amount)
                }))
                (map-set positions position-key (merge current-position {
                    yes-amount: (+ (get yes-amount current-position) amount)
                }))
            )
            (begin
                (map-set markets market-id (merge market {
                    total-no: (+ (get total-no market) amount)
                }))
                (map-set positions position-key (merge current-position {
                    no-amount: (+ (get no-amount current-position) amount)
                }))
            )
        )
        (ok true)
    )
)

(define-public (resolve-market (market-id uint) (outcome bool))
    (let ((market (unwrap! (map-get? markets market-id) err-market-closed)))
        (asserts! (is-eq tx-sender (get creator market)) err-not-authorized)
        (asserts! (>= block-height (get end-block market)) err-market-closed)
        (asserts! (not (get resolved market)) err-market-closed)
        
        (map-set markets market-id (merge market {
            resolved: true,
            outcome: (some outcome)
        }))
        (ok true)
    )
)

(define-public (claim-winnings (market-id uint))
    (let
        (
            (market (unwrap! (map-get? markets market-id) err-market-closed))
            (position-key {market-id: market-id, user: tx-sender})
            (position (unwrap! (map-get? positions position-key) err-not-authorized))
            (outcome (unwrap! (get outcome market) err-market-not-resolved))
        )
        (asserts! (get resolved market) err-market-not-resolved)
        (asserts! (not (get claimed position)) err-already-claimed)
        
        (let
            (
                (winning-amount (if outcome (get yes-amount position) (get no-amount position)))
                (total-pool (+ (get total-yes market) (get total-no market)))
                (winning-pool (if outcome (get total-yes market) (get total-no market)))
                (payout (if (> winning-pool u0)
                           (/ (* winning-amount total-pool) winning-pool)
                           u0))
            )
            (if (> payout u0)
                (try! (as-contract (stx-transfer? payout tx-sender tx-sender)))
                true
            )
            (map-set positions position-key (merge position {claimed: true}))
            (ok payout)
        )
    )
)

(define-read-only (get-market (market-id uint))
    (map-get? markets market-id)
)

(define-read-only (get-position (market-id uint) (user principal))
    (map-get? positions {market-id: market-id, user: user})
)
