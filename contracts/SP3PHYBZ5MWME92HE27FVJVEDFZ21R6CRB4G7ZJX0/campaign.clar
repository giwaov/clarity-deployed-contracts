;; Contract: Crowdfunding Campaign
;; Description: Simple fundraising logic with a goal.

(define-data-var target-amount uint u1000) ;; Target: 1000 micro-STX
(define-data-var total-raised uint u0)
(define-map contributors principal uint)
(define-constant campaign-owner tx-sender)

(define-public (donate (amount uint))
    (begin
        ;; Transfer STX to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Record contribution
        (var-set total-raised (+ (var-get total-raised) amount))
        (map-set contributors tx-sender amount)
        (ok "Donation Received")
    )
)

(define-public (withdraw-funds)
    (begin
        (asserts! (is-eq tx-sender campaign-owner) (err u403))
        
        ;; Only allow withdraw if target is met
        (asserts! (>= (var-get total-raised) (var-get target-amount)) (err u500))
        
        ;; Send all funds to owner
        (as-contract (stx-transfer? (var-get total-raised) tx-sender campaign-owner))
    )
)

(define-read-only (get-progress)
    (ok { raised: (var-get total-raised), goal: (var-get target-amount) })
)