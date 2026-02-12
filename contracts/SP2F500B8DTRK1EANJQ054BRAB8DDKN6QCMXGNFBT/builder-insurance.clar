;; Builder Insurance Fund - Clarity 4
;; Insurance pool for project failures

(define-constant contract-owner tx-sender)
(define-constant err-insufficient-funds (err u4000))
(define-constant err-not-eligible (err u4001))
(define-constant err-claim-exists (err u4002))

(define-data-var insurance-pool uint u0)
(define-data-var premium-rate uint u500) ;; 5%
(define-data-var max-coverage uint u50000000) ;; 50 STX

(define-map policies
    principal
    {premium-paid: uint, coverage: uint, active: bool, claims: uint}
)

(define-map claims
    {user: principal, claim-id: uint}
    {amount: uint, reason: (string-utf8 200), approved: bool, processed: bool}
)

(define-map user-claim-count principal uint)

(define-read-only (get-policy (user principal))
    (map-get? policies user)
)

(define-read-only (get-pool-balance)
    (var-get insurance-pool)
)

(define-public (buy-insurance (coverage uint))
    (let (
        (premium (/ (* coverage (var-get premium-rate)) u10000))
    )
        (asserts! (<= coverage (var-get max-coverage)) err-not-eligible)
        (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
        
        (var-set insurance-pool (+ (var-get insurance-pool) premium))
        (ok (map-set policies tx-sender {
            premium-paid: premium,
            coverage: coverage,
            active: true,
            claims: u0
        }))
    )
)

(define-public (file-claim (amount uint) (reason (string-utf8 200)))
    (let (
        (policy (unwrap! (get-policy tx-sender) err-not-eligible))
        (claim-id (default-to u0 (map-get? user-claim-count tx-sender)))
    )
        (asserts! (get active policy) err-not-eligible)
        (asserts! (<= amount (get coverage policy)) err-insufficient-funds)
        
        (map-set claims {user: tx-sender, claim-id: claim-id}
            {amount: amount, reason: reason, approved: false, processed: false}
        )
        (map-set user-claim-count tx-sender (+ claim-id u1))
        (ok claim-id)
    )
)

(define-public (approve-claim (user principal) (claim-id uint))
    (let (
        (claim (unwrap! (map-get? claims {user: user, claim-id: claim-id}) err-not-eligible))
        (pool (var-get insurance-pool))
    )
        (asserts! (is-eq tx-sender contract-owner) err-not-eligible)
        (asserts! (>= pool (get amount claim)) err-insufficient-funds)
        (asserts! (not (get processed claim)) err-claim-exists)
        
        (map-set claims {user: user, claim-id: claim-id}
            (merge claim {approved: true, processed: true})
        )
        (var-set insurance-pool (- pool (get amount claim)))
        (try! (as-contract (stx-transfer? (get amount claim) tx-sender user)))
        (ok true)
    )
)

(define-public (fund-pool (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set insurance-pool (+ (var-get insurance-pool) amount))
        (ok true)
    )
)
