;; This contract use the SIP-010 community-standard Fungible Token trait
(use-trait sip-010-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait) ;; 

;; SIP-010 transfer implementation
(define-private (transfer-ft (token-contract <sip-010-trait>) (amount uint) (sender principal) (recipient principal))
  (contract-call? token-contract transfer amount sender recipient none)
)

;; SIP-010 get balance implementation
(define-private (get-balance-ft (token-contract <sip-010-trait>) (sender principal) )
  (unwrap-panic (contract-call? token-contract get-balance sender ))
)

;; This contract use the SIP-09 community-standard Non Fungible Token trait
(use-trait nft-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait) ;; 

;; SIP-09 transfer implementation
(define-private (transfer-nft (token-contract <nft-trait>) (id uint) (sender principal) (recipient principal))
  (contract-call? token-contract transfer id sender recipient)
)

;; Two owners to split payment
(define-data-var OWNER_ONE principal tx-sender)
(define-data-var OWNER_TWO principal tx-sender)

(define-constant ERR_OWNER_ONLY (err u1000)) ;; not an owners address
(define-constant ERR_OUT_OF_RANGE (err u1001)) ;; minimum amount not reached

;; check the contract caller is the owner
(define-private (is-owner) 
    (or (is-eq contract-caller (var-get OWNER_ONE)) (is-eq contract-caller (var-get OWNER_TWO)))
)

;; only owner one can change his address for payment
(define-public (change-owner-one (address principal))
    (begin
        (asserts! (is-eq contract-caller (var-get OWNER_ONE)) ERR_OWNER_ONLY)
        (var-set OWNER_ONE address)
        (print {
            newOwnerOne: address,
            prevOwnerOne: contract-caller,
        })
        (ok true)
    )
)

;; only owner two can change his address for payment
(define-public (change-owner-two (address principal))
    (begin
        (asserts! (is-eq contract-caller (var-get OWNER_TWO)) ERR_OWNER_ONLY)
        (var-set OWNER_TWO address)
        (print {
            newOwnerTwo: address,
            prevOwnerTwo: contract-caller,
        })
        (ok true)
    )
)

;; both the owners can split the stx in the contract
(define-public (split)
    (let (
        (balance (stx-get-balance (as-contract tx-sender)))
        (half (/ balance u2))
    )
        (asserts! (is-owner) ERR_OWNER_ONLY)
        (asserts! (>= balance u2) ERR_OUT_OF_RANGE)
        (try! (as-contract (stx-transfer? half tx-sender (var-get OWNER_ONE))))
        (try! (as-contract (stx-transfer? (- balance half) tx-sender (var-get OWNER_TWO))))
        (ok true)
    )
)

;; both the owners can split the FT in the contract
(define-public (split-ft (ft <sip-010-trait>))
    (let (
        (balance (get-balance-ft ft (as-contract tx-sender)))
        (half (/ balance u2))
    )
        (asserts! (is-owner) ERR_OWNER_ONLY)
        (asserts! (>= balance u2) ERR_OUT_OF_RANGE)
        (try! (as-contract (transfer-ft ft half tx-sender (var-get OWNER_ONE))))
        (try! (as-contract (transfer-ft ft (- balance half) tx-sender (var-get OWNER_TWO))))
        (ok true)
    )
)

;; both the owners can split the NFT in the contract
(define-public (split-nft (nfts (list 100 {id: uint, contract: <nft-trait>})))
    (begin 
        (asserts! (is-owner) ERR_OWNER_ONLY)
        (asserts! (>= (len nfts) u2) ERR_OUT_OF_RANGE)
        (let (
            (half (/ (len nfts) u2))
            (one (unwrap-panic (slice? nfts u0 half)))
            (two (unwrap-panic (slice? nfts half u100)))
        )
            (try! (fold check-err (map transfer-one one) (ok true)))
            (try! (fold check-err (map transfer-two two) (ok true)))
        (ok true)
    )
    )
)
  
;; helper for transfer to owner one
(define-private (transfer-one (transfer {contract: <nft-trait>, id: uint,}))
    (transfer-nft (get contract transfer) (get id transfer) tx-sender (var-get OWNER_ONE))
)

;; helper for transfer to owner two
(define-private (transfer-two (transfer {contract: <nft-trait>, id: uint,}))
    (transfer-nft (get contract transfer) (get id transfer) tx-sender (var-get OWNER_TWO))
)

;; Helper to loop bulk actions
(define-private (check-err (result (response bool uint)) (prior (response bool uint)))
  (match prior ok-value result err-value (err err-value))
)