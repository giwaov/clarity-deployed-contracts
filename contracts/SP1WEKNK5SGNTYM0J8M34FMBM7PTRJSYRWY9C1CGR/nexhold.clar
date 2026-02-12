;; title: nexhold
;; version: 1
;; summary: A decentralized escrow service with built-in dispute resolution and counter functionality.
;; description: Secure peer-to-peer transactions where buyers deposit STX into escrow, sellers confirm delivery, and funds are released upon completion or refunded in case of disputes. Includes a simple counter for tracking operations.

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ESCROW_NOT_FOUND (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_INVALID_STATUS (err u103))
(define-constant ERR_SELF_ESCROW (err u104))
(define-constant ERR_ALREADY_ACCEPTED (err u105))
(define-constant ERR_NOT_PENDING (err u106))
(define-constant ERR_NOT_ACCEPTED (err u107))
(define-constant ERR_NOT_DELIVERED (err u108))
(define-constant ERR_ALREADY_COMPLETED (err u109))
(define-constant ERR_TRANSFER_FAILED (err u110))
(define-constant ERR_NOT_BUYER (err u111))
(define-constant ERR_NOT_SELLER (err u112))
(define-constant ERR_NOT_PARTY (err u113))
(define-constant ERR_ALREADY_DISPUTED (err u114))
(define-constant ERR_NOT_DISPUTED (err u115))
(define-constant ERR_UNDERFLOW (err u116))

;; status constants
(define-constant STATUS_PENDING u"pending")
(define-constant STATUS_ACCEPTED u"accepted")
(define-constant STATUS_DELIVERED u"delivered")
(define-constant STATUS_COMPLETED u"completed")
(define-constant STATUS_CANCELLED u"cancelled")
(define-constant STATUS_REFUNDED u"refunded")
(define-constant STATUS_DISPUTED u"disputed")

;; data vars
(define-data-var counter uint u0)
(define-data-var escrow-nonce uint u0)

;; data maps
(define-map escrows
    uint
    {
        buyer: principal,
        seller: principal,
        amount: uint,
        status: (string-utf8 20),
        created-at: uint,
        accepted-at: (optional uint),
        delivered-at: (optional uint),
        completed-at: (optional uint),
        description: (string-utf8 256),
        dispute-reason: (optional (string-utf8 256)),
        arbitrator: (optional principal)
    }
)

;; Track user escrows for easy lookup
(define-map user-escrows-as-buyer
    principal
    (list 100 uint)
)

(define-map user-escrows-as-seller
    principal
    (list 100 uint)
)

;; Arbitrator authorization
(define-map arbitrators
    principal
    bool
)

;; public functions

;; --- Counter Functions ---

(define-public (increment)
    (let
        ((new-value (+ (var-get counter) u1)))
        (begin
            (var-set counter new-value)
            (print {
                event: "counter-incremented",
                caller: tx-sender,
                new-value: new-value,
                block-height: block-height
            })
            (ok new-value)
        )
    )
)

(define-public (decrement)
    (let
        ((current-value (var-get counter)))
        (begin
            ;; Prevent underflow
            (asserts! (> current-value u0) ERR_UNDERFLOW)
            (let
                ((new-value (- current-value u1)))
                (begin
                    (var-set counter new-value)
                    (print {
                        event: "counter-decremented",
                        caller: tx-sender,
                        new-value: new-value,
                        block-height: block-height
                    })
                    (ok new-value)
                )
            )
        )
    )
)

;; --- Escrow Functions ---

(define-public (create-escrow (seller principal) (amount uint) (description (string-utf8 256)))
    (let
        (
            (escrow-id (+ (var-get escrow-nonce) u1))
            (buyer tx-sender)
        )
        (begin
            ;; Validations
            (asserts! (> amount u0) ERR_INVALID_AMOUNT)
            (asserts! (not (is-eq buyer seller)) ERR_SELF_ESCROW)

            ;; Transfer STX from buyer to contract
            (unwrap! (stx-transfer? amount buyer (as-contract tx-sender)) ERR_TRANSFER_FAILED)

            ;; Create escrow record
            (map-set escrows escrow-id {
                buyer: buyer,
                seller: seller,
                amount: amount,
                status: STATUS_PENDING,
                created-at: block-height,
                accepted-at: none,
                delivered-at: none,
                completed-at: none,
                description: description,
                dispute-reason: none,
                arbitrator: none
            })

            ;; Update nonce
            (var-set escrow-nonce escrow-id)

            ;; Track user escrows
            (map-set user-escrows-as-buyer buyer 
                (unwrap-panic (as-max-len? (append (default-to (list) (map-get? user-escrows-as-buyer buyer)) escrow-id) u100)))
            (map-set user-escrows-as-seller seller 
                (unwrap-panic (as-max-len? (append (default-to (list) (map-get? user-escrows-as-seller seller)) escrow-id) u100)))

            ;; Emit event
            (print {
                event: "escrow-created",
                escrow-id: escrow-id,
                buyer: buyer,
                seller: seller,
                amount: amount,
                description: description,
                block-height: block-height
            })

            (ok escrow-id)
        )
    )
)

(define-public (accept-escrow (escrow-id uint))
    (let
        (
            (escrow (unwrap! (map-get? escrows escrow-id) ERR_ESCROW_NOT_FOUND))
            (seller tx-sender)
        )
        (begin
            ;; Validations
            (asserts! (is-eq seller (get seller escrow)) ERR_NOT_SELLER)
            (asserts! (is-eq (get status escrow) STATUS_PENDING) ERR_NOT_PENDING)

            ;; Update escrow
            (map-set escrows escrow-id (merge escrow {
                status: STATUS_ACCEPTED,
                accepted-at: (some block-height)
            }))

            ;; Emit event
            (print {
                event: "escrow-accepted",
                escrow-id: escrow-id,
                seller: seller,
                block-height: block-height
            })

            (ok true)
        )
    )
)

(define-public (confirm-delivery (escrow-id uint))
    (let
        (
            (escrow (unwrap! (map-get? escrows escrow-id) ERR_ESCROW_NOT_FOUND))
            (seller tx-sender)
        )
        (begin
            ;; Validations
            (asserts! (is-eq seller (get seller escrow)) ERR_NOT_SELLER)
            (asserts! (is-eq (get status escrow) STATUS_ACCEPTED) ERR_NOT_ACCEPTED)

            ;; Update escrow
            (map-set escrows escrow-id (merge escrow {
                status: STATUS_DELIVERED,
                delivered-at: (some block-height)
            }))

            ;; Emit event
            (print {
                event: "delivery-confirmed",
                escrow-id: escrow-id,
                seller: seller,
                block-height: block-height
            })

            (ok true)
        )
    )
)

(define-public (release-funds (escrow-id uint))
    (let
        (
            (escrow (unwrap! (map-get? escrows escrow-id) ERR_ESCROW_NOT_FOUND))
            (buyer tx-sender)
            (seller (get seller escrow))
            (amount (get amount escrow))
        )
        (begin
            ;; Validations
            (asserts! (is-eq buyer (get buyer escrow)) ERR_NOT_BUYER)
            (asserts! (is-eq (get status escrow) STATUS_DELIVERED) ERR_NOT_DELIVERED)

            ;; Transfer funds from contract to seller
            (unwrap! (as-contract (stx-transfer? amount tx-sender seller)) ERR_TRANSFER_FAILED)

            ;; Update escrow
            (map-set escrows escrow-id (merge escrow {
                status: STATUS_COMPLETED,
                completed-at: (some block-height)
            }))

            ;; Emit event
            (print {
                event: "funds-released",
                escrow-id: escrow-id,
                buyer: buyer,
                seller: seller,
                amount: amount,
                block-height: block-height
            })

            (ok true)
        )
    )
)

(define-public (cancel-escrow (escrow-id uint))
    (let
        (
            (escrow (unwrap! (map-get? escrows escrow-id) ERR_ESCROW_NOT_FOUND))
            (buyer tx-sender)
            (amount (get amount escrow))
        )
        (begin
            ;; Validations
            (asserts! (is-eq buyer (get buyer escrow)) ERR_NOT_BUYER)
            (asserts! (is-eq (get status escrow) STATUS_PENDING) ERR_NOT_PENDING)

            ;; Refund to buyer
            (unwrap! (as-contract (stx-transfer? amount tx-sender buyer)) ERR_TRANSFER_FAILED)

            ;; Update escrow
            (map-set escrows escrow-id (merge escrow {
                status: STATUS_CANCELLED
            }))

            ;; Emit event
            (print {
                event: "escrow-cancelled",
                escrow-id: escrow-id,
                buyer: buyer,
                amount: amount,
                block-height: block-height
            })

            (ok true)
        )
    )
)

(define-public (request-refund (escrow-id uint) (reason (string-utf8 256)))
    (let
        (
            (escrow (unwrap! (map-get? escrows escrow-id) ERR_ESCROW_NOT_FOUND))
            (buyer tx-sender)
        )
        (begin
            ;; Validations
            (asserts! (is-eq buyer (get buyer escrow)) ERR_NOT_BUYER)
            (asserts! (not (is-eq (get status escrow) STATUS_DELIVERED)) ERR_INVALID_STATUS)
            (asserts! (not (is-eq (get status escrow) STATUS_COMPLETED)) ERR_ALREADY_COMPLETED)

            ;; Mark as disputed with refund request
            (map-set escrows escrow-id (merge escrow {
                status: STATUS_DISPUTED,
                dispute-reason: (some reason)
            }))

            ;; Emit event
            (print {
                event: "refund-requested",
                escrow-id: escrow-id,
                buyer: buyer,
                reason: reason,
                block-height: block-height
            })

            (ok true)
        )
    )
)

(define-public (raise-dispute (escrow-id uint) (reason (string-utf8 256)))
    (let
        (
            (escrow (unwrap! (map-get? escrows escrow-id) ERR_ESCROW_NOT_FOUND))
            (caller tx-sender)
        )
        (begin
            ;; Validations - must be buyer or seller
            (asserts! (or (is-eq caller (get buyer escrow)) (is-eq caller (get seller escrow))) ERR_NOT_PARTY)
            (asserts! (not (is-eq (get status escrow) STATUS_DISPUTED)) ERR_ALREADY_DISPUTED)
            (asserts! (not (is-eq (get status escrow) STATUS_COMPLETED)) ERR_ALREADY_COMPLETED)

            ;; Update escrow
            (map-set escrows escrow-id (merge escrow {
                status: STATUS_DISPUTED,
                dispute-reason: (some reason)
            }))

            ;; Emit event
            (print {
                event: "dispute-raised",
                escrow-id: escrow-id,
                caller: caller,
                reason: reason,
                block-height: block-height
            })

            (ok true)
        )
    )
)

(define-public (resolve-dispute (escrow-id uint) (favor-buyer bool))
    (let
        (
            (escrow (unwrap! (map-get? escrows escrow-id) ERR_ESCROW_NOT_FOUND))
            (arbitrator tx-sender)
            (buyer (get buyer escrow))
            (seller (get seller escrow))
            (amount (get amount escrow))
        )
        (begin
            ;; Validations - must be contract owner or authorized arbitrator
            (asserts! (or (is-eq arbitrator CONTRACT_OWNER) (default-to false (map-get? arbitrators arbitrator))) ERR_NOT_AUTHORIZED)
            (asserts! (is-eq (get status escrow) STATUS_DISPUTED) ERR_NOT_DISPUTED)

            ;; Transfer funds based on decision
            (if favor-buyer
                (begin
                    ;; Refund to buyer
                    (unwrap! (as-contract (stx-transfer? amount tx-sender buyer)) ERR_TRANSFER_FAILED)
                    (map-set escrows escrow-id (merge escrow {
                        status: STATUS_REFUNDED,
                        arbitrator: (some arbitrator)
                    }))
                    (print {
                        event: "dispute-resolved",
                        escrow-id: escrow-id,
                        arbitrator: arbitrator,
                        buyer: buyer,
                        seller: seller,
                        amount: amount,
                        favor-buyer: true,
                        block-height: block-height
                    })
                )
                (begin
                    ;; Pay seller
                    (unwrap! (as-contract (stx-transfer? amount tx-sender seller)) ERR_TRANSFER_FAILED)
                    (map-set escrows escrow-id (merge escrow {
                        status: STATUS_COMPLETED,
                        arbitrator: (some arbitrator),
                        completed-at: (some block-height)
                    }))
                    (print {
                        event: "dispute-resolved",
                        escrow-id: escrow-id,
                        arbitrator: arbitrator,
                        buyer: buyer,
                        seller: seller,
                        amount: amount,
                        favor-buyer: false,
                        block-height: block-height
                    })
                )
            )

            (ok true)
        )
    )
)

(define-public (add-arbitrator (arbitrator principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-set arbitrators arbitrator true)
        (print {
            event: "arbitrator-added",
            arbitrator: arbitrator,
            block-height: block-height
        })
        (ok true)
    )
)

(define-public (remove-arbitrator (arbitrator principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-set arbitrators arbitrator false)
        (print {
            event: "arbitrator-removed",
            arbitrator: arbitrator,
            block-height: block-height
        })
        (ok true)
    )
)

;; read only functions

(define-read-only (get-counter)
    (ok (var-get counter))
)

(define-read-only (get-escrow (escrow-id uint))
    (ok (map-get? escrows escrow-id))
)

(define-read-only (get-escrow-status (escrow-id uint))
    (ok (get status (unwrap! (map-get? escrows escrow-id) ERR_ESCROW_NOT_FOUND)))
)

(define-read-only (get-user-escrows-as-buyer (user principal))
    (ok (default-to (list) (map-get? user-escrows-as-buyer user)))
)

(define-read-only (get-user-escrows-as-seller (user principal))
    (ok (default-to (list) (map-get? user-escrows-as-seller user)))
)

(define-read-only (get-total-escrows)
    (ok (var-get escrow-nonce))
)

(define-read-only (is-arbitrator (user principal))
    (ok (or (is-eq user CONTRACT_OWNER) (default-to false (map-get? arbitrators user))))
)

(define-read-only (get-escrow-details (escrow-id uint))
    (let
        ((escrow (unwrap! (map-get? escrows escrow-id) ERR_ESCROW_NOT_FOUND)))
        (ok {
            escrow-id: escrow-id,
            buyer: (get buyer escrow),
            seller: (get seller escrow),
            amount: (get amount escrow),
            status: (get status escrow),
            created-at: (get created-at escrow),
            description: (get description escrow)
        })
    )
)
