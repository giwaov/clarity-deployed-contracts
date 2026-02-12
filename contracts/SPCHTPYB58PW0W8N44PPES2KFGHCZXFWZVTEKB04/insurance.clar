;; Insurance Pool Contract
;; Decentralized insurance coverage

(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-insufficient-coverage (err u101))
(define-constant err-claim-exists (err u102))
(define-constant err-invalid-claim (err u103))

(define-data-var total-pool uint u0)
(define-data-var claim-nonce uint u0)
(define-data-var premium-rate uint u100) ;; 1% of coverage amount

(define-map policies
    principal
    {
        coverage-amount: uint,
        premium-paid: uint,
        start-block: uint,
        end-block: uint,
        active: bool
    }
)

(define-map claims
    uint
    {
        policy-holder: principal,
        amount: uint,
        description: (string-utf8 500),
        timestamp: uint,
        approved: bool,
        processed: bool
    }
)

(define-public (purchase-policy (coverage-amount uint) (duration uint))
    (let
        (
            (premium (/ (* coverage-amount (var-get premium-rate)) u10000))
            (end-block (+ block-height duration))
        )
        (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
        (var-set total-pool (+ (var-get total-pool) premium))
        
        (map-set policies tx-sender {
            coverage-amount: coverage-amount,
            premium-paid: premium,
            start-block: block-height,
            end-block: end-block,
            active: true
        })
        (ok end-block)
    )
)

(define-public (file-claim (amount uint) (description (string-utf8 500)))
    (let
        (
            (policy (unwrap! (map-get? policies tx-sender) err-invalid-claim))
            (claim-id (var-get claim-nonce))
        )
        (asserts! (get active policy) err-invalid-claim)
        (asserts! (< block-height (get end-block policy)) err-invalid-claim)
        (asserts! (<= amount (get coverage-amount policy)) err-insufficient-coverage)
        
        (map-set claims claim-id {
            policy-holder: tx-sender,
            amount: amount,
            description: description,
            timestamp: block-height,
            approved: false,
            processed: false
        })
        (var-set claim-nonce (+ claim-id u1))
        (ok claim-id)
    )
)

(define-public (approve-claim (claim-id uint))
    (let
        (
            (claim (unwrap! (map-get? claims claim-id) err-invalid-claim))
        )
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (not (get processed claim)) err-claim-exists)
        (asserts! (<= (get amount claim) (var-get total-pool)) err-insufficient-coverage)
        
        (try! (as-contract (stx-transfer? (get amount claim) tx-sender (get policy-holder claim))))
        (var-set total-pool (- (var-get total-pool) (get amount claim)))
        
        (map-set claims claim-id (merge claim {
            approved: true,
            processed: true
        }))
        (ok true)
    )
)

(define-public (reject-claim (claim-id uint))
    (let ((claim (unwrap! (map-get? claims claim-id) err-invalid-claim)))
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (not (get processed claim)) err-claim-exists)
        (map-set claims claim-id (merge claim {processed: true}))
        (ok true)
    )
)

(define-read-only (get-policy (user principal))
    (map-get? policies user)
)

(define-read-only (get-claim (claim-id uint))
    (map-get? claims claim-id)
)

(define-read-only (get-pool-balance)
    (var-get total-pool)
)
