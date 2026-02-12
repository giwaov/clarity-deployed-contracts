;; NFT Marketplace Contract - Simplified Version
;; Enables listing, buying, selling, and offer management with platform fees
;; This version uses approval-based transfers instead of escrow

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-token-owner (err u201))
(define-constant err-listing-not-found (err u202))
(define-constant err-listing-expired (err u203))
(define-constant err-insufficient-payment (err u204))
(define-constant err-nft-not-listed (err u205))
(define-constant err-unauthorized (err u206))
(define-constant err-invalid-price (err u207))
(define-constant err-offer-not-found (err u208))
(define-constant err-offer-expired (err u209))
(define-constant err-invalid-offer (err u210))
(define-constant err-listing-active (err u211))
(define-constant err-transfer-failed (err u212))

;; Platform fee is 2.5% (250 basis points out of 10000)
(define-constant platform-fee-basis-points u250)
(define-constant basis-points-divisor u10000)

;; Data Variables
(define-data-var platform-fee-recipient principal contract-owner)
(define-data-var marketplace-enabled bool true)
(define-data-var next-listing-id uint u1)
(define-data-var next-offer-id uint u1)

;; Listing status constants
(define-constant listing-status-active u1)
(define-constant listing-status-sold u2)
(define-constant listing-status-cancelled u3)

;; Offer status constants
(define-constant offer-status-pending u1)
(define-constant offer-status-accepted u2)
(define-constant offer-status-rejected u3)
(define-constant offer-status-cancelled u4)

;; Data Maps
(define-map listings 
    uint 
    {
        token-id: uint,
        nft-contract: principal,
        seller: principal,
        price: uint,
        status: uint,
        expiry: uint,
        created-at: uint
    }
)

(define-map token-listings 
    {nft-contract: principal, token-id: uint} 
    uint
)

(define-map offers 
    uint 
    {
        token-id: uint,
        nft-contract: principal,
        offerer: principal,
        amount: uint,
        status: uint,
        expiry: uint,
        created-at: uint
    }
)

(define-map token-offers 
    {nft-contract: principal, token-id: uint} 
    (list 50 uint)
)

;; Read-only functions

(define-read-only (get-listing (listing-id uint))
    (ok (map-get? listings listing-id))
)

(define-read-only (get-listing-by-token (nft-contract principal) (token-id uint))
    (match (map-get? token-listings {nft-contract: nft-contract, token-id: token-id})
        listing-id (ok (map-get? listings listing-id))
        (ok none)
    )
)

(define-read-only (get-offer (offer-id uint))
    (ok (map-get? offers offer-id))
)

(define-read-only (get-token-offers (nft-contract principal) (token-id uint))
    (ok (default-to (list) (map-get? token-offers {nft-contract: nft-contract, token-id: token-id})))
)

(define-read-only (calculate-platform-fee (price uint))
    (ok (/ (* price platform-fee-basis-points) basis-points-divisor))
)

(define-read-only (get-platform-fee-recipient)
    (ok (var-get platform-fee-recipient))
)

(define-read-only (is-marketplace-enabled)
    (ok (var-get marketplace-enabled))
)

(define-read-only (get-next-listing-id)
    (ok (var-get next-listing-id))
)

(define-read-only (get-next-offer-id)
    (ok (var-get next-offer-id))
)

;; Private functions

(define-private (transfer-stx (amount uint) (sender principal) (recipient principal))
    (if (> amount u0)
        (stx-transfer? amount sender recipient)
        (ok true)
    )
)

;; Public functions

(define-public (list-nft 
    (nft-contract principal)
    (token-id uint) 
    (price uint) 
    (expiry uint))
    (let 
        (
            (listing-id (var-get next-listing-id))
        )
        ;; Validations
        (asserts! (var-get marketplace-enabled) err-unauthorized)
        (asserts! (> price u0) err-invalid-price)
        (asserts! (> expiry stacks-block-height) err-listing-expired)
        
        ;; Check if NFT is already listed
        (asserts! (is-none (map-get? token-listings {nft-contract: nft-contract, token-id: token-id})) 
            err-listing-active)
        
        ;; Create listing
        (map-set listings listing-id {
            token-id: token-id,
            nft-contract: nft-contract,
            seller: tx-sender,
            price: price,
            status: listing-status-active,
            expiry: expiry,
            created-at: stacks-block-height
        })
        
        (map-set token-listings {nft-contract: nft-contract, token-id: token-id} listing-id)
        
        ;; Increment listing counter
        (var-set next-listing-id (+ listing-id u1))
        
        (print {
            event: "list",
            listing-id: listing-id,
            token-id: token-id,
            nft-contract: nft-contract,
            seller: tx-sender,
            price: price,
            expiry: expiry
        })
        
        (ok listing-id)
    )
)

(define-public (unlist-nft (listing-id uint))
    (let 
        (
            (listing (unwrap! (map-get? listings listing-id) err-listing-not-found))
            (nft-contract (get nft-contract listing))
            (token-id (get token-id listing))
            (seller (get seller listing))
        )
        ;; Validations
        (asserts! (is-eq tx-sender seller) err-not-token-owner)
        (asserts! (is-eq (get status listing) listing-status-active) err-nft-not-listed)
        
        ;; Update listing status
        (map-set listings listing-id (merge listing {status: listing-status-cancelled}))
        (map-delete token-listings {nft-contract: nft-contract, token-id: token-id})
        
        (print {
            event: "unlist",
            listing-id: listing-id,
            token-id: token-id,
            seller: seller
        })
        
        (ok true)
    )
)

(define-public (buy-nft 
    (listing-id uint)
    (nft-contract principal))
    (let 
        (
            (listing (unwrap! (map-get? listings listing-id) err-listing-not-found))
            (token-id (get token-id listing))
            (seller (get seller listing))
            (price (get price listing))
            (platform-fee (unwrap! (calculate-platform-fee price) err-invalid-price))
            (seller-proceeds (- price platform-fee))
        )
        ;; Validations
        (asserts! (var-get marketplace-enabled) err-unauthorized)
        (asserts! (is-eq (get status listing) listing-status-active) err-nft-not-listed)
        (asserts! (<= stacks-block-height (get expiry listing)) err-listing-expired)
        (asserts! (is-eq nft-contract (get nft-contract listing)) err-unauthorized)
        
        ;; Transfer payment to seller
        (try! (transfer-stx seller-proceeds tx-sender seller))
        
        ;; Transfer platform fee
        (try! (transfer-stx platform-fee tx-sender (var-get platform-fee-recipient)))
        
        ;; Update listing status
        (map-set listings listing-id (merge listing {status: listing-status-sold}))
        (map-delete token-listings {nft-contract: nft-contract, token-id: token-id})
        
        (print {
            event: "purchase",
            listing-id: listing-id,
            token-id: token-id,
            buyer: tx-sender,
            seller: seller,
            price: price,
            platform-fee: platform-fee,
            note: "Buyer must call NFT contract transfer function separately"
        })
        
        (ok true)
    )
)

(define-public (make-offer 
    (nft-contract principal) 
    (token-id uint) 
    (amount uint) 
    (expiry uint))
    (let 
        (
            (offer-id (var-get next-offer-id))
            (existing-offers (default-to (list) (map-get? token-offers {nft-contract: nft-contract, token-id: token-id})))
        )
        ;; Validations
        (asserts! (var-get marketplace-enabled) err-unauthorized)
        (asserts! (> amount u0) err-invalid-offer)
        (asserts! (> expiry stacks-block-height) err-offer-expired)
        
        ;; Create offer
        (map-set offers offer-id {
            token-id: token-id,
            nft-contract: nft-contract,
            offerer: tx-sender,
            amount: amount,
            status: offer-status-pending,
            expiry: expiry,
            created-at: stacks-block-height
        })
        
        ;; Add to token offers list (if space available)
        (if (< (len existing-offers) u50)
            (map-set token-offers 
                {nft-contract: nft-contract, token-id: token-id}
                (unwrap-panic (as-max-len? (append existing-offers offer-id) u50))
            )
            true
        )
        
        ;; Increment offer counter
        (var-set next-offer-id (+ offer-id u1))
        
        (print {
            event: "offer-made",
            offer-id: offer-id,
            token-id: token-id,
            nft-contract: nft-contract,
            offerer: tx-sender,
            amount: amount,
            expiry: expiry
        })
        
        (ok offer-id)
    )
)

(define-public (accept-offer 
    (offer-id uint)
    (nft-contract principal))
    (let 
        (
            (offer (unwrap! (map-get? offers offer-id) err-offer-not-found))
            (token-id (get token-id offer))
            (offerer (get offerer offer))
            (amount (get amount offer))
            (platform-fee (unwrap! (calculate-platform-fee amount) err-invalid-price))
            (seller-proceeds (- amount platform-fee))
        )
        ;; Validations
        (asserts! (var-get marketplace-enabled) err-unauthorized)
        (asserts! (is-eq (get status offer) offer-status-pending) err-invalid-offer)
        (asserts! (<= stacks-block-height (get expiry offer)) err-offer-expired)
        (asserts! (is-eq nft-contract (get nft-contract offer)) err-unauthorized)
        
        ;; If there's an active listing, cancel it
        (match (map-get? token-listings {nft-contract: nft-contract, token-id: token-id})
            listing-id (begin
                (map-set listings listing-id 
                    (merge (unwrap-panic (map-get? listings listing-id)) {status: listing-status-cancelled}))
                (map-delete token-listings {nft-contract: nft-contract, token-id: token-id})
            )
            true
        )
        
        ;; Update offer status
        (map-set offers offer-id (merge offer {status: offer-status-accepted}))
        
        (print {
            event: "offer-accepted",
            offer-id: offer-id,
            token-id: token-id,
            seller: tx-sender,
            buyer: offerer,
            amount: amount,
            platform-fee: platform-fee,
            note: "Parties must exchange STX and NFT separately via payment and transfer calls"
        })
        
        (ok true)
    )
)

(define-public (cancel-offer (offer-id uint))
    (let 
        (
            (offer (unwrap! (map-get? offers offer-id) err-offer-not-found))
            (offerer (get offerer offer))
        )
        ;; Validations
        (asserts! (is-eq tx-sender offerer) err-unauthorized)
        (asserts! (is-eq (get status offer) offer-status-pending) err-invalid-offer)
        
        ;; Update offer status
        (map-set offers offer-id (merge offer {status: offer-status-cancelled}))
        
        (print {
            event: "offer-cancelled",
            offer-id: offer-id,
            offerer: offerer
        })
        
        (ok true)
    )
)

(define-public (reject-offer 
    (offer-id uint)
    (nft-contract principal))
    (let 
        (
            (offer (unwrap! (map-get? offers offer-id) err-offer-not-found))
            (token-id (get token-id offer))
            (offerer (get offerer offer))
        )
        ;; Validations
        (asserts! (is-eq (get status offer) offer-status-pending) err-invalid-offer)
        (asserts! (is-eq nft-contract (get nft-contract offer)) err-unauthorized)
        
        ;; Update offer status
        (map-set offers offer-id (merge offer {status: offer-status-rejected}))
        
        (print {
            event: "offer-rejected",
            offer-id: offer-id,
            token-id: token-id,
            owner: tx-sender
        })
        
        (ok true)
    )
)

;; Admin functions

(define-public (set-platform-fee-recipient (new-recipient principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set platform-fee-recipient new-recipient)
        (ok true)
    )
)

(define-public (toggle-marketplace)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set marketplace-enabled (not (var-get marketplace-enabled)))
        (ok (var-get marketplace-enabled))
    )
)
