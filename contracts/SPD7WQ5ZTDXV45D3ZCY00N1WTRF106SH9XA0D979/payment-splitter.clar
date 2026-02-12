;; Payment Splitter - Simplified (using list for recipients instead of recursion)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-invalid-split (err u401))
(define-constant err-unauthorized (err u402))
(define-constant err-split-not-found (err u403))
(define-constant platform-fee-percentage u150)

;; Data
(define-data-var total-splits uint u0)
(define-data-var total-fees uint u0)

(define-map splits
    uint
    { creator: principal, description: (string-ascii 100), created-at: uint }
)

;; Read-only
(define-read-only (get-split (split-id uint))
    (map-get? splits split-id)
)

(define-read-only (get-total-splits)
    (ok (var-get total-splits))
)

;; Create split
(define-public (create-split (description (string-ascii 100)))
    (let ((split-id (+ (var-get total-splits) u1)))
        (map-set splits split-id
            { creator: tx-sender, description: description, created-at: stacks-block-height }
        )
        (var-set total-splits split-id)
        (ok split-id)
    )
)

;; Execute split with list of recipients
(define-public (execute-split-list 
    (amount uint)
    (recipients (list 20 { recipient: principal, percentage: uint }))
)
    (let (
        (fee (/ (* amount platform-fee-percentage) u10000))
        (net-amount (- amount fee))
    )
        ;; Pay each recipient
        (try! (fold pay-one recipients (ok net-amount)))
        ;; Collect fee (skip if sender is contract owner)
        (if (is-eq tx-sender contract-owner)
            true
            (try! (stx-transfer? fee tx-sender contract-owner))
        )
        (var-set total-fees (+ (var-get total-fees) fee))
        (ok true)
    )
)

(define-private (pay-one 
    (recipient-data { recipient: principal, percentage: uint })
    (result (response uint uint))
)
    (match result
        net-amount
            (let ((payment (/ (* net-amount (get percentage recipient-data)) u10000)))
                (match (stx-transfer? payment tx-sender (get recipient recipient-data))
                    success (ok net-amount)
                    error (err u1)
                )
            )
        error (err error)
    )
)
