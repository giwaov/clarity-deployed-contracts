---
title: "Trait timelock-controller"
draft: true
---
```
;; title: timelock-controller
;; version:
;; summary:
;; description:

;; Agriculture Supply Chain Management Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1))
(define-constant ERR_PRODUCT_DOES_NOT_EXIST (err u2))
(define-constant ERR_INVALID_STATUS_CHANGE (err u3))
(define-constant ERR_PRODUCT_ALREADY_EXISTS (err u4))
(define-constant ERR_INVALID_PARAMETER (err u5))

;; Data Variables
(define-data-var required-quality-score uint u60)

;; Principal Maps
(define-map stakeholder-registry
    principal
    {
        stakeholder-type: (string-ascii 20),
        stakeholder-status: bool,
        stakeholder-score: uint
    }
)

;; Product Structure
(define-map product-registry
    uint  ;; product-id
    {
        name: (string-ascii 50),
        original-producer: principal,
        current-owner: principal,
        current-state: (string-ascii 20),
        quality-score: uint,
        creation-time: uint,
        physical-location: (string-ascii 100),
        current-price: uint,
        quality-verified: bool
    }
)

;; Transaction History
(define-map transaction-history
    {product-id: uint, transaction-id: uint}
    {
        from-party: principal,
        to-party: principal,
        action-type: (string-ascii 20),
        action-time: uint,
        action-details: (string-ascii 200)
    }
)

;; Counter for transaction IDs
(define-data-var total-transactions uint u0)

;; Read-only functions
(define-read-only (get-product-details (product-id uint))
    (map-get? product-registry product-id)
)

(define-read-only (get-stakeholder-details (stakeholder-address principal))
    (map-get? stakeholder-registry stakeholder-address)
)

(define-read-only (get-transaction-details (product-id uint) (transaction-id uint))
    (map-get? transaction-history {product-id: product-id, transaction-id: transaction-id})
)

;; Internal Functions
(define-private (is-stakeholder-active (stakeholder-address principal))
    (let ((stakeholder-info (unwrap! (map-get? stakeholder-registry stakeholder-address) false)))
        (get stakeholder-status stakeholder-info)
    )
)

(define-private (get-next-transaction-id)
    (begin
        (var-set total-transactions (+ (var-get total-transactions) u1))
        (var-get total-transactions)
    )
)

;; Input validation functions
(define-private (validate-short-string (input (string-ascii 20)))
    (and (>= (len input) u1) (<= (len input) u20))
)

(define-private (validate-medium-string (input (string-ascii 50)))
    (and (>= (len input) u1) (<= (len input) u50))
)

(define-private (validate-long-string (input (string-ascii 100)))
    (and (>= (len input) u1) (<= (len input) u100))
)

(define-private (validate-description (input (string-ascii 200)))
    (and (>= (len input) u1) (<= (len input) u200))
)

(define-private (validate-number (input uint))
    (< input u340282366920938463463374607431768211455)  ;; Max uint value
)

;; Administrative Functions
(define-public (register-stakeholder (stakeholder-address principal) (stakeholder-type (string-ascii 20)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR_NOT_AUTHORIZED)
        (asserts! (is-none (map-get? stakeholder-registry stakeholder-address)) ERR_PRODUCT_ALREADY_EXISTS)
        (asserts! (validate-short-string stakeholder-type) ERR_INVALID_PARAMETER)
        (ok (map-set stakeholder-registry 
            stakeholder-address
            {
                stakeholder-type: stakeholder-type,
                stakeholder-status: true,
                stakeholder-score: u100
            }
        ))
    )
)

(define-public (update-stakeholder-status (stakeholder-address principal) (new-status bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR_NOT_AUTHORIZED)
        (asserts! (is-some (map-get? stakeholder-registry stakeholder-address)) ERR_NOT_AUTHORIZED)
        (ok (map-set stakeholder-registry 
            stakeholder-address
            (merge (unwrap-panic (map-get? stakeholder-registry stakeholder-address))
                  {stakeholder-status: new-status})
        ))
    )
)

;; Product Management Functions
(define-public (register-product 
    (product-id uint)
    (product-name (string-ascii 50))
    (product-location (string-ascii 100))
    (product-price uint))
    (let ((registering-party tx-sender))
        (begin
            (asserts! (is-stakeholder-active registering-party) ERR_NOT_AUTHORIZED)
            (asserts! (is-none (map-get? product-registry product-id)) ERR_PRODUCT_ALREADY_EXISTS)
            (asserts! (validate-number product-id) ERR_INVALID_PARAMETER)
            (asserts! (validate-medium-string product-name) ERR_INVALID_PARAMETER)
            (asserts! (validate-long-string product-location) ERR_INVALID_PARAMETER)
            (asserts! (validate-number product-price) ERR_INVALID_PARAMETER)
            (ok (map-set product-registry
                product-id
                {
                    name: product-name,
                    original-producer: registering-party,
                    current-owner: registering-party,
                    current-state: "registered",
                    quality-score: u100,
                    creation-time: stacks-block-height,
                    physical-location: product-location,
                    current-price: product-price,
                    quality-verified: false
                }
            ))
        )
    )
)

(define-public (update-product-state 
    (product-id uint)
    (new-state (string-ascii 20))
    (state-change-notes (string-ascii 200)))
    (let (
        (updating-party tx-sender)
        (product-info (unwrap! (map-get? product-registry product-id) ERR_PRODUCT_DOES_NOT_EXIST))
        )
        (begin
            (asserts! (is-stakeholder-active updating-party) ERR_NOT_AUTHORIZED)
            (asserts! (is-eq (get current-owner product-info) updating-party) ERR_NOT_AUTHORIZED)
            (asserts! (validate-number product-id) ERR_INVALID_PARAMETER)
            (asserts! (validate-short-string new-state) ERR_INVALID_PARAMETER)
            (asserts! (validate-description state-change-notes) ERR_INVALID_PARAMETER)
            (map-set product-registry
                product-id
                (merge product-info {current-state: new-state})
            )
            (map-set transaction-history
                {product-id: product-id, transaction-id: (get-next-transaction-id)}
                {
                    from-party: updating-party,
                    to-party: updating-party,
                    action-type: new-state,
                    action-time: stacks-block-height,
                    action-details: state-change-notes
                }
            )
            (ok true)
        )
    )
)

(define-public (transfer-ownership
    (product-id uint)
    (new-owner principal)
    (transfer-details (string-ascii 200)))
    (let (
        (current-owner tx-sender)
        (product-info (unwrap! (map-get? product-registry product-id) ERR_PRODUCT_DOES_NOT_EXIST))
        )
        (begin
            (asserts! (is-stakeholder-active current-owner) ERR_NOT_AUTHORIZED)
            (asserts! (is-stakeholder-active new-owner) ERR_NOT_AUTHORIZED)
            (asserts! (is-eq (get current-owner product-info) current-owner) ERR_NOT_AUTHORIZED)
            (asserts! (validate-number product-id) ERR_INVALID_PARAMETER)
            (asserts! (validate-description transfer-details) ERR_INVALID_PARAMETER)
            (map-set product-registry
                product-id
                (merge product-info {
                    current-owner: new-owner,
                    current-state: "transferred"
                })
            )
            (map-set transaction-history
                {product-id: product-id, transaction-id: (get-next-transaction-id)}
                {
                    from-party: current-owner,
                    to-party: new-owner,
                    action-type: "transfer",
                    action-time: stacks-block-height,
                    action-details: transfer-details
                }
            )
            (ok true)
        )
    )
)

(define-public (update-quality-rating
    (product-id uint)
    (new-quality-score uint)
    (quality-update-notes (string-ascii 200)))
    (let (
        (quality-inspector tx-sender)
        (product-info (unwrap! (map-get? product-registry product-id) ERR_PRODUCT_DOES_NOT_EXIST))
        )
        (begin
            (asserts! (is-stakeholder-active quality-inspector) ERR_NOT_AUTHORIZED)
            (asserts! (validate-number product-id) ERR_INVALID_PARAMETER)
            (asserts! (<= new-quality-score u100) ERR_INVALID_PARAMETER)
            (asserts! (validate-description quality-update-notes) ERR_INVALID_PARAMETER)
            (map-set product-registry
                product-id
                (merge product-info {
                    quality-score: new-quality-score,
                    quality-verified: (>= new-quality-score (var-get required-quality-score))
                })
            )
            (map-set transaction-history
                {product-id: product-id, transaction-id: (get-next-transaction-id)}
                {
                    from-party: quality-inspector,
                    to-party: quality-inspector,
                    action-type: "quality-update",
                    action-time: stacks-block-height,
                    action-details: quality-update-notes
                }
            )
            (ok true)
        )
    )
)

(define-public (update-location
    (product-id uint)
    (new-location (string-ascii 100))
    (location-update-notes (string-ascii 200)))
    (let (
        (updating-party tx-sender)
        (product-info (unwrap! (map-get? product-registry product-id) ERR_PRODUCT_DOES_NOT_EXIST))
        )
        (begin
            (asserts! (is-stakeholder-active updating-party) ERR_NOT_AUTHORIZED)
            (asserts! (is-eq (get current-owner product-info) updating-party) ERR_NOT_AUTHORIZED)
            (asserts! (validate-number product-id) ERR_INVALID_PARAMETER)
            (asserts! (validate-long-string new-location) ERR_INVALID_PARAMETER)
            (asserts! (validate-description location-update-notes) ERR_INVALID_PARAMETER)
            (map-set product-registry
                product-id
                (merge product-info {physical-location: new-location})
            )
            (map-set transaction-history
                {product-id: product-id, transaction-id: (get-next-transaction-id)}
                {
                    from-party: updating-party,
                    to-party: updating-party,
                    action-type: "location-update",
                    action-time: stacks-block-height,
                    action-details: location-update-notes
                }
            )
            (ok true)
        )
    )
)
```
