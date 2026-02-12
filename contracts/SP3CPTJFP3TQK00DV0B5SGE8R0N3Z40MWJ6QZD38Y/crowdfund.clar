;; crowdfund.clar
;; A campaign where users pledge funds. Funds are released only if goal is met by deadline.

(define-constant campaign-goal u10000)
(define-constant campaign-deadline u100) ;; Block height
(define-data-var pledged-amount uint u0)
(define-map pledges principal uint)

(define-public (pledge (amount uint))
    (begin
        (asserts! (> amount u0) (err u103))
        (asserts! (< block-height campaign-deadline) (err u100)) ;; ERR_CAMPAIGN_ENDED
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set pledges tx-sender (+ (default-to u0 (map-get? pledges tx-sender)) amount))
        (var-set pledged-amount (+ (var-get pledged-amount) amount))
        (ok true)
    )
)

(define-public (claim-funds)
    (begin
        (asserts! (>= (var-get pledged-amount) campaign-goal) (err u101)) ;; ERR_GOAL_NOT_MET
        ;; In reality, check if sender is owner
        (try! (as-contract (stx-transfer? (var-get pledged-amount) tx-sender tx-sender)))
        (ok true)
    )
)

(define-public (refund)
    (let
        (
            (amount (unwrap! (map-get? pledges tx-sender) (err u102))) ;; ERR_NO_PLEDGE
        )
        (asserts! (> block-height campaign-deadline) (err u103)) ;; ERR_CAMPAIGN_ACTIVE
        (asserts! (< (var-get pledged-amount) campaign-goal) (err u104)) ;; ERR_GOAL_MET
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (map-delete pledges tx-sender)
        (ok true)
    )
)
