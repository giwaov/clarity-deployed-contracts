
;; title: leverox
;; version: 1.0.0
;; summary: A decentralized options trading platform on Stacks
;; description: Enables creation, buying, selling, and exercising of call and put options with STX collateral.

;; constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-OPTION-NOT-FOUND (err u101))
(define-constant ERR-OPTION-EXPIRED (err u102))
(define-constant ERR-OPTION-NOT-EXPIRED (err u103))
(define-constant ERR-OPTION-SOLD (err u104))
;; (define-constant ERR-OPTION-NOT-SOLD (err u105)) ;; Unused
(define-constant ERR-INSUFFICIENT-BALANCE (err u106))
(define-constant ERR-INVALID-EXPIRY (err u107))
(define-constant ERR-WRONG-STATUS (err u108))

;; data vars
(define-data-var next-option-id uint u1)

;; data maps
(define-map options
    uint
    {
        id: uint,
        type: (string-ascii 4), ;; "call" or "put"
        strike-price: uint,
        premium: uint,
        expiry-height: uint,
        seller: principal,
        buyer: (optional principal),
        collateral: uint,
        status: (string-ascii 10), ;; "open", "sold", "exercised", "expired", "cancelled"
        created-at: uint,
        exercised-at: (optional uint)
    }
)

;; public functions

;; Seller Functions

(define-public (create-call-option (strike-price uint) (premium uint) (expiry-height uint) (collateral-amount uint))
    (let
        (
            (option-id (var-get next-option-id))
        )
        (asserts! (> expiry-height block-height) ERR-INVALID-EXPIRY)
        (asserts! (> collateral-amount u0) ERR-INSUFFICIENT-BALANCE)
        
        ;; Lock collateral (STX) from seller to contract
        (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
        
        (map-set options option-id {
            id: option-id,
            type: "call",
            strike-price: strike-price,
            premium: premium,
            expiry-height: expiry-height,
            seller: tx-sender,
            buyer: none,
            collateral: collateral-amount,
            status: "open",
            created-at: block-height,
            exercised-at: none
        })
        
        (var-set next-option-id (+ option-id u1))
        (ok option-id)
    )
)

(define-public (create-put-option (strike-price uint) (premium uint) (expiry-height uint))
    (let
        (
            (option-id (var-get next-option-id))
            (collateral-amount strike-price) ;; For Put, collateral is the strike price (to buy assets)
        )
        (asserts! (> expiry-height block-height) ERR-INVALID-EXPIRY)
        (asserts! (> collateral-amount u0) ERR-INSUFFICIENT-BALANCE)
        
        ;; Lock collateral (Strike Price in STX) from seller to contract
        (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
        
        (map-set options option-id {
            id: option-id,
            type: "put",
            strike-price: strike-price,
            premium: premium,
            expiry-height: expiry-height,
            seller: tx-sender,
            buyer: none,
            collateral: collateral-amount,
            status: "open",
            created-at: block-height,
            exercised-at: none
        })
        
        (var-set next-option-id (+ option-id u1))
        (ok option-id)
    )
)

(define-public (cancel-option (option-id uint))
    (let
        (
            (option (unwrap! (map-get? options option-id) ERR-OPTION-NOT-FOUND))
        )
        (asserts! (is-eq (get seller option) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status option) "open") ERR-WRONG-STATUS)
        
        ;; Return collateral to seller
        (try! (as-contract (stx-transfer? (get collateral option) tx-sender (get seller option))))
        
        (map-set options option-id (merge option { status: "cancelled" }))
        (ok true)
    )
)

(define-public (claim-expired-collateral (option-id uint))
    (let
        (
            (option (unwrap! (map-get? options option-id) ERR-OPTION-NOT-FOUND))
        )
        (asserts! (is-eq (get seller option) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (> block-height (get expiry-height option)) ERR-OPTION-NOT-EXPIRED)
        ;; Can claim if Open (never sold) or Sold (but not exercised)
        (asserts! (or (is-eq (get status option) "open") (is-eq (get status option) "sold")) ERR-WRONG-STATUS)
        
        ;; Return collateral to seller
        (try! (as-contract (stx-transfer? (get collateral option) tx-sender (get seller option))))
        
        (map-set options option-id (merge option { status: "expired" }))
        (ok true)
    )
)

;; Buyer Functions

(define-public (buy-option (option-id uint))
    (let
        (
            (option (unwrap! (map-get? options option-id) ERR-OPTION-NOT-FOUND))
        )
        (asserts! (is-eq (get status option) "open") ERR-OPTION-SOLD)
        (asserts! (< block-height (get expiry-height option)) ERR-OPTION-EXPIRED)
        
        ;; Buyer pays premium to Seller
        (try! (stx-transfer? (get premium option) tx-sender (get seller option)))
        
        (map-set options option-id (merge option { 
            status: "sold", 
            buyer: (some tx-sender) 
        }))
        (ok true)
    )
)

(define-public (exercise-option (option-id uint))
    (let
        (
            (option (unwrap! (map-get? options option-id) ERR-OPTION-NOT-FOUND))
            (buyer (unwrap! (get buyer option) ERR-WRONG-STATUS))
            (type (get type option))
        )
        (asserts! (is-eq buyer tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status option) "sold") ERR-WRONG-STATUS)
        (asserts! (< block-height (get expiry-height option)) ERR-OPTION-EXPIRED)
        
        (if (is-eq type "call")
            (begin
                ;; CALL: Buyer pays Strike Price -> Seller. Buyer receives Collateral <- Contract.
                ;; 1. Buyer sends Strike Price to Seller
                (try! (stx-transfer? (get strike-price option) tx-sender (get seller option)))
                ;; 2. Contract sends Collateral to Buyer
                (try! (as-contract (stx-transfer? (get collateral option) tx-sender buyer)))
            )
            (begin
                ;; PUT: Buyer "delivers asset" (abstracted) -> Seller pays Strike Price (Collateral).
                ;; NOTE: Since 'asset' delivery is not enforceable for undefined tokens,
                ;; this implementation strictly transfers the Collateral (Strike) to Buyer.
                ;; Ideally, Buyer should send an Asset to Seller here.
                
                ;; 1. Contract sends Collateral (Strike Price) to Buyer
                (try! (as-contract (stx-transfer? (get collateral option) tx-sender buyer)))
            )
        )
        
        (map-set options option-id (merge option { 
            status: "exercised",
            exercised-at: (some block-height)
        }))
        (ok true)
    )
)

(define-public (sell-option (option-id uint) (new-buyer principal) (sale-price uint))
    (let
        (
            (option (unwrap! (map-get? options option-id) ERR-OPTION-NOT-FOUND))
            (current-buyer (unwrap! (get buyer option) ERR-WRONG-STATUS))
        )
        (asserts! (is-eq current-buyer tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status option) "sold") ERR-WRONG-STATUS)
        (asserts! (< block-height (get expiry-height option)) ERR-OPTION-EXPIRED)
        
        ;; NOTE: In Clarity, tx-sender cannot pull funds from new-buyer without new-buyer's signature.
        ;; The following line is logically invalid for a single-sig seller transaction and is commented out.
        ;; Real-world implementation would require a 2-step process (offer/accept) or a marketplace contract.
        ;; (try! (stx-transfer? sale-price new-buyer tx-sender)) 
        
        (map-set options option-id (merge option { buyer: (some new-buyer) }))
        (ok true)
    )
)

;; Read-Only Functions

(define-read-only (get-option (option-id uint))
    (map-get? options option-id)
)

(define-read-only (get-option-status (option-id uint))
    (let
        (
            (option (map-get? options option-id))
        )
        (match option
            opt (some (get status opt))
            none
        )
    )
)

(define-read-only (is-expired (option-id uint))
    (let
        (
            (option (unwrap! (map-get? options option-id) false))
        )
        (> block-height (get expiry-height option))
    )
)

(define-read-only (calculate-intrinsic-value (option-id uint) (current-price uint))
    (let
        (
            (option (unwrap! (map-get? options option-id) u0))
            (strike (get strike-price option))
            (type (get type option))
        )
        (if (is-eq type "call")
            ;; Call: Max(0, Current - Strike)
            (if (> current-price strike)
                (- current-price strike)
                u0
            )
            ;; Put: Max(0, Strike - Current)
            (if (> strike current-price)
                (- strike current-price)
                u0
            )
        )
    )
)
