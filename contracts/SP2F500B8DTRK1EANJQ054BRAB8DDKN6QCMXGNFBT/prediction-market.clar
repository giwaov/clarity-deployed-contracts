;; Prediction Market - Clarity 4
;; Binary outcome prediction markets

(define-constant contract-owner tx-sender)
(define-constant err-not-found (err u2000))
(define-constant err-market-closed (err u2001))
(define-constant err-already-resolved (err u2002))
(define-constant err-invalid-outcome (err u2003))

(define-data-var market-nonce uint u0)

(define-map markets
    uint
    {
        question: (string-utf8 200),
        end-height: uint,
        yes-pool: uint,
        no-pool: uint,
        resolved: bool,
        outcome: (optional bool)
    }
)

(define-map positions
    {market-id: uint, user: principal}
    {yes-shares: uint, no-shares: uint}
)

(define-read-only (get-market (market-id uint))
    (map-get? markets market-id)
)

(define-read-only (get-position (market-id uint) (user principal))
    (default-to {yes-shares: u0, no-shares: u0}
        (map-get? positions {market-id: market-id, user: user}))
)

(define-read-only (calculate-payout (market-id uint) (user principal))
    (match (get-market market-id)
        market
        (if (get resolved market)
            (match (get outcome market)
                outcome
                (let (
                    (position (get-position market-id user))
                    (total-pool (+ (get yes-pool market) (get no-pool market)))
                )
                    (if outcome
                        (if (> (get yes-pool market) u0)
                            (/ (* (get yes-shares position) total-pool) (get yes-pool market))
                            u0
                        )
                        (if (> (get no-pool market) u0)
                            (/ (* (get no-shares position) total-pool) (get no-pool market))
                            u0
                        )
                    )
                )
                u0
            )
            u0
        )
        u0
    )
)

(define-public (create-market (question (string-utf8 200)) (duration-blocks uint))
    (let (
        (market-id (var-get market-nonce))
    )
        (map-set markets market-id {
            question: question,
            end-height: (+ stacks-block-height duration-blocks),
            yes-pool: u0,
            no-pool: u0,
            resolved: false,
            outcome: none
        })
        (var-set market-nonce (+ market-id u1))
        (ok market-id)
    )
)

(define-public (buy-shares (market-id uint) (amount uint) (predict-yes bool))
    (let (
        (market (unwrap! (get-market market-id) err-not-found))
        (position (get-position market-id tx-sender))
    )
        (asserts! (< stacks-block-height (get end-height market)) err-market-closed)
        (asserts! (not (get resolved market)) err-already-resolved)
        
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (map-set markets market-id 
            (if predict-yes
                (merge market {yes-pool: (+ (get yes-pool market) amount)})
                (merge market {no-pool: (+ (get no-pool market) amount)})
            )
        )
        
        (ok (map-set positions {market-id: market-id, user: tx-sender}
            (if predict-yes
                (merge position {yes-shares: (+ (get yes-shares position) amount)})
                (merge position {no-shares: (+ (get no-shares position) amount)})
            )
        ))
    )
)

(define-public (resolve-market (market-id uint) (outcome bool))
    (let (
        (market (unwrap! (get-market market-id) err-not-found))
    )
        (asserts! (is-eq tx-sender contract-owner) err-not-found)
        (asserts! (>= stacks-block-height (get end-height market)) err-market-closed)
        (asserts! (not (get resolved market)) err-already-resolved)
        
        (ok (map-set markets market-id 
            (merge market {resolved: true, outcome: (some outcome)})
        ))
    )
)

(define-public (claim-winnings (market-id uint))
    (let (
        (payout (calculate-payout market-id tx-sender))
    )
        (asserts! (> payout u0) err-invalid-outcome)
        (try! (as-contract (stx-transfer? payout tx-sender tx-sender)))
        (ok payout)
    )
)
