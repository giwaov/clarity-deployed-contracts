;; VIP BAZAAR - Unique NFT Marketplace
;; Inspired by the Tiny Market pattern but optimized for v11

;; Traits definitions
(use-trait nft-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)
(use-trait ft-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Constants
(define-constant BAZAAR-ADMIN tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u3001))
(define-constant ERR-INVALID-PRICE (err u3002))
(define-constant ERR-LISTING-NOT-FOUND (err u3003))
(define-constant ERR-EXPIRED (err u3004))

;; Data Structures
(define-map active-offers
    uint 
    {
        seller: principal,
        buyer-only: (optional principal),
        token-id: uint,
        nft-contract: principal,
        deadline: uint,
        cost: uint,
        payment-token: (optional principal)
    }
)

(define-data-var offer-nonce uint u0)
(define-map authorized-contracts principal bool)

;; --- Authorization ---

(define-read-only (is-authorized (contract principal))
    (default-to true (map-get? authorized-contracts contract))
)

(define-public (toggle-contract (contract principal) (status bool))
    (begin
        (asserts! (is-eq tx-sender BAZAAR-ADMIN) ERR-NOT-AUTHORIZED)
        (ok (map-set authorized-contracts contract status))
    )
)

;; --- Internal Helpers ---

(define-private (move-nft (contract <nft-trait>) (id uint) (from principal) (to principal))
    (contract-call? contract transfer id from to)
)

(define-private (move-ft (contract <ft-trait>) (amount uint) (from principal) (to principal))
    (contract-call? contract transfer amount from to none)
)

;; --- Core Functions ---

;; List a new VIP Item
(define-public (create-offer
    (nft-contract <nft-trait>)
    (details {
        buyer-only: (optional principal),
        token-id: uint,
        deadline: uint,
        cost: uint,
        payment-token: (optional principal)
    })
)
    (let ((offer-id (var-get offer-nonce)))
        (asserts! (is-authorized (contract-of nft-contract)) ERR-NOT-AUTHORIZED)
        (asserts! (> (get cost details) u0) ERR-INVALID-PRICE)
        
        ;; Lock NFT in the contract (Escrow)
        (try! (move-nft nft-contract (get token-id details) tx-sender (as-contract tx-sender)))
        
        (map-set active-offers offer-id
            (merge {
                seller: tx-sender,
                nft-contract: (contract-of nft-contract)
            } details)
        )
        
        (var-set offer-nonce (+ offer-id u1))
        (ok offer-id)
    )
)

;; Purchase with STX
(define-public (fill-offer-stx (offer-id uint) (nft-contract <nft-trait>))
    (let (
        (offer (unwrap! (map-get? active-offers offer-id) ERR-LISTING-NOT-FOUND))
        (buyer tx-sender)
    )
        ;; Validations
        (asserts! (not (is-eq (get seller offer) buyer)) (err u3005))
        (asserts! (< burn-block-height (get deadline offer)) ERR-EXPIRED)
        (asserts! (is-eq (get nft-contract offer) (contract-of nft-contract)) (err u3006))
        
        ;; Payments & Transfer
        (try! (as-contract (move-nft nft-contract (get token-id offer) tx-sender buyer)))
        (try! (stx-transfer? (get cost offer) buyer (get seller offer)))
        
        (map-delete active-offers offer-id)
        (ok offer-id)
    )
)

;; --- Read Only ---
(define-read-only (get-offer-data (id uint))
    (map-get? active-offers id)
)
