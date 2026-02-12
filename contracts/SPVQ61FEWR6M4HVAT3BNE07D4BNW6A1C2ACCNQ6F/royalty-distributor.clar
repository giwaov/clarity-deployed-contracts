;; Royalty Distributor Contract
;; Handles automatic royalty distribution for NFT sales

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u300))
(define-constant err-invalid-royalty (err u301))
(define-constant err-invalid-amount (err u302))
(define-constant err-transfer-failed (err u303))
(define-constant err-royalty-not-set (err u304))
(define-constant err-invalid-recipient (err u305))
(define-constant err-calculation-error (err u306))

;; Maximum royalty: 10% (1000 basis points)
(define-constant max-royalty-basis-points u1000)
(define-constant basis-points-divisor u10000)

;; Default platform fee: 2.5% (250 basis points)
(define-constant default-platform-fee u250)

;; Data Variables
(define-data-var platform-fee-recipient principal contract-owner)
(define-data-var platform-fee-basis-points uint default-platform-fee)
(define-data-var royalty-enabled bool true)

;; Data Maps
(define-map token-royalties 
    {nft-contract: principal, token-id: uint}
    {
        creator: principal,
        royalty-percent: uint
    }
)

(define-map collection-default-royalties
    principal
    {
        creator: principal,
        royalty-percent: uint
    }
)

(define-map creator-earnings principal uint)
(define-map platform-earnings principal uint)

;; Read-only functions

(define-read-only (get-token-royalty (nft-contract principal) (token-id uint))
    (ok (map-get? token-royalties {nft-contract: nft-contract, token-id: token-id}))
)

(define-read-only (get-collection-default-royalty (nft-contract principal))
    (ok (map-get? collection-default-royalties nft-contract))
)

(define-read-only (calculate-royalty (sale-price uint) (royalty-percent uint))
    (if (<= royalty-percent max-royalty-basis-points)
        (ok (/ (* sale-price royalty-percent) basis-points-divisor))
        err-invalid-royalty
    )
)

(define-read-only (calculate-platform-fee (sale-price uint))
    (ok (/ (* sale-price (var-get platform-fee-basis-points)) basis-points-divisor))
)

(define-read-only (calculate-distribution (sale-price uint) (royalty-percent uint))
    (let 
        (
            (platform-fee (unwrap! (calculate-platform-fee sale-price) err-calculation-error))
            (royalty-amount (unwrap! (calculate-royalty sale-price royalty-percent) err-calculation-error))
            (seller-amount (- (- sale-price platform-fee) royalty-amount))
        )
        (ok {
            platform-fee: platform-fee,
            royalty-amount: royalty-amount,
            seller-amount: seller-amount,
            total: sale-price
        })
    )
)

(define-read-only (get-creator-earnings (creator principal))
    (ok (default-to u0 (map-get? creator-earnings creator)))
)

(define-read-only (get-platform-earnings)
    (ok (default-to u0 (map-get? platform-earnings (var-get platform-fee-recipient))))
)

(define-read-only (get-platform-fee-info)
    (ok {
        recipient: (var-get platform-fee-recipient),
        fee-basis-points: (var-get platform-fee-basis-points),
        fee-percentage: (/ (* (var-get platform-fee-basis-points) u100) basis-points-divisor)
    })
)

(define-read-only (is-royalty-enabled)
    (ok (var-get royalty-enabled))
)

;; Private functions

(define-private (transfer-stx-safe (amount uint) (sender principal) (recipient principal))
    (if (> amount u0)
        (stx-transfer? amount sender recipient)
        (ok true)
    )
)

(define-private (update-creator-earnings (creator principal) (amount uint))
    (let ((current-earnings (default-to u0 (map-get? creator-earnings creator))))
        (map-set creator-earnings creator (+ current-earnings amount))
        true
    )
)

(define-private (update-platform-earnings (amount uint))
    (let 
        (
            (recipient (var-get platform-fee-recipient))
            (current-earnings (default-to u0 (map-get? platform-earnings recipient)))
        )
        (map-set platform-earnings recipient (+ current-earnings amount))
        true
    )
)

;; Public functions

(define-public (set-token-royalty 
    (nft-contract principal) 
    (token-id uint) 
    (creator principal) 
    (royalty-percent uint))
    (begin
        ;; Validations
        (asserts! (<= royalty-percent max-royalty-basis-points) err-invalid-royalty)
        (asserts! (not (is-eq creator (var-get platform-fee-recipient))) err-invalid-recipient)
        
        ;; Set royalty info
        (map-set token-royalties 
            {nft-contract: nft-contract, token-id: token-id}
            {creator: creator, royalty-percent: royalty-percent}
        )
        
        (print {
            event: "royalty-set",
            nft-contract: nft-contract,
            token-id: token-id,
            creator: creator,
            royalty-percent: royalty-percent
        })
        
        (ok true)
    )
)

(define-public (set-collection-default-royalty 
    (nft-contract principal) 
    (creator principal) 
    (royalty-percent uint))
    (begin
        ;; Validations
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= royalty-percent max-royalty-basis-points) err-invalid-royalty)
        
        ;; Set collection default
        (map-set collection-default-royalties 
            nft-contract
            {creator: creator, royalty-percent: royalty-percent}
        )
        
        (print {
            event: "collection-royalty-set",
            nft-contract: nft-contract,
            creator: creator,
            royalty-percent: royalty-percent
        })
        
        (ok true)
    )
)

(define-public (distribute-payment 
    (nft-contract principal) 
    (token-id uint) 
    (sale-price uint) 
    (seller principal) 
    (buyer principal))
    (let 
        (
            (royalty-info (default-to 
                (default-to {creator: seller, royalty-percent: u0} 
                    (map-get? collection-default-royalties nft-contract))
                (map-get? token-royalties {nft-contract: nft-contract, token-id: token-id})))
            (creator (get creator royalty-info))
            (royalty-percent (get royalty-percent royalty-info))
            (distribution (unwrap! (calculate-distribution sale-price royalty-percent) err-calculation-error))
            (platform-fee (get platform-fee distribution))
            (royalty-amount (get royalty-amount distribution))
            (seller-amount (get seller-amount distribution))
        )
        ;; Validations
        (asserts! (var-get royalty-enabled) err-owner-only)
        (asserts! (> sale-price u0) err-invalid-amount)
        
        ;; Transfer platform fee
        (if (> platform-fee u0)
            (begin
                (try! (transfer-stx-safe platform-fee buyer (var-get platform-fee-recipient)))
                (asserts! (update-platform-earnings platform-fee) err-transfer-failed)
            )
            true
        )
        
        ;; Transfer royalty to creator
        (if (and (> royalty-amount u0) (not (is-eq creator seller)))
            (begin
                (try! (transfer-stx-safe royalty-amount buyer creator))
                (asserts! (update-creator-earnings creator royalty-amount) err-transfer-failed)
            )
            true
        )
        
        ;; Transfer remaining amount to seller
        (try! (transfer-stx-safe seller-amount buyer seller))
        
        (print {
            event: "payment-distributed",
            nft-contract: nft-contract,
            token-id: token-id,
            sale-price: sale-price,
            buyer: buyer,
            seller: seller,
            creator: creator,
            platform-fee: platform-fee,
            royalty-amount: royalty-amount,
            seller-amount: seller-amount
        })
        
        (ok {
            platform-fee: platform-fee,
            royalty-amount: royalty-amount,
            seller-amount: seller-amount
        })
    )
)

(define-public (distribute-payment-simple
    (sale-price uint)
    (seller principal)
    (creator principal)
    (royalty-percent uint))
    (let 
        (
            (distribution (unwrap! (calculate-distribution sale-price royalty-percent) err-calculation-error))
            (platform-fee (get platform-fee distribution))
            (royalty-amount (get royalty-amount distribution))
            (seller-amount (get seller-amount distribution))
        )
        ;; Validations
        (asserts! (var-get royalty-enabled) err-owner-only)
        (asserts! (> sale-price u0) err-invalid-amount)
        (asserts! (<= royalty-percent max-royalty-basis-points) err-invalid-royalty)
        
        ;; Transfer platform fee
        (if (> platform-fee u0)
            (begin
                (try! (transfer-stx-safe platform-fee tx-sender (var-get platform-fee-recipient)))
                (asserts! (update-platform-earnings platform-fee) err-transfer-failed)
            )
            true
        )
        
        ;; Transfer royalty to creator
        (if (and (> royalty-amount u0) (not (is-eq creator seller)))
            (begin
                (try! (transfer-stx-safe royalty-amount tx-sender creator))
                (asserts! (update-creator-earnings creator royalty-amount) err-transfer-failed)
            )
            true
        )
        
        ;; Transfer remaining amount to seller
        (try! (transfer-stx-safe seller-amount tx-sender seller))
        
        (print {
            event: "simple-payment-distributed",
            sale-price: sale-price,
            buyer: tx-sender,
            seller: seller,
            creator: creator,
            platform-fee: platform-fee,
            royalty-amount: royalty-amount,
            seller-amount: seller-amount
        })
        
        (ok distribution)
    )
)

;; Withdrawal functions

(define-public (withdraw-creator-earnings)
    (let 
        (
            (earnings (default-to u0 (map-get? creator-earnings tx-sender)))
        )
        (asserts! (> earnings u0) err-invalid-amount)
        
        ;; Reset earnings
        (map-set creator-earnings tx-sender u0)
        
        (print {
            event: "creator-withdrawal",
            creator: tx-sender,
            amount: earnings,
            note: "Earnings tracked but withdrawal must be processed separately"
        })
        
        (ok earnings)
    )
)

(define-public (withdraw-platform-earnings)
    (let 
        (
            (recipient (var-get platform-fee-recipient))
            (earnings (default-to u0 (map-get? platform-earnings recipient)))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> earnings u0) err-invalid-amount)
        
        ;; Reset earnings
        (map-set platform-earnings recipient u0)
        
        (print {
            event: "platform-withdrawal",
            recipient: recipient,
            amount: earnings,
            note: "Earnings tracked but withdrawal must be processed separately"
        })
        
        (ok earnings)
    )
)

;; Admin functions

(define-public (set-platform-fee-recipient (new-recipient principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set platform-fee-recipient new-recipient)
        
        (print {
            event: "platform-fee-recipient-updated",
            new-recipient: new-recipient
        })
        
        (ok true)
    )
)

(define-public (set-platform-fee (new-fee-basis-points uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-fee-basis-points max-royalty-basis-points) err-invalid-royalty)
        (var-set platform-fee-basis-points new-fee-basis-points)
        
        (print {
            event: "platform-fee-updated",
            new-fee-basis-points: new-fee-basis-points
        })
        
        (ok true)
    )
)

(define-public (toggle-royalty-system)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set royalty-enabled (not (var-get royalty-enabled)))
        
        (print {
            event: "royalty-system-toggled",
            enabled: (var-get royalty-enabled)
        })
        
        (ok (var-get royalty-enabled))
    )
)
