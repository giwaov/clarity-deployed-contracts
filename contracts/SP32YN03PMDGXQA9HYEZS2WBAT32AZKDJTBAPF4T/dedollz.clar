;; Title: Dedollz NFT
;; Version: 1.0
;; Summary: SIP-009 NFT Contract for Stacks Mainnet
;; Description: This contract implements a 1,000 supply NFT collection called Dedollz.

;; 1. Trait Definition
;; Implementing the standard SIP-009 trait for Stacks Mainnet
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; 2. Data Definitions
;; Define the NFT name as Dedollz
(define-non-fungible-token dedollz uint)

;; Track the last minted ID
(define-data-var last-token-id uint u0)

;; Base URI for metadata (pointing to your IPFS folder)
;; Note: {id} will be replaced by the specific token ID on the frontend/marketplace
(define-data-var base-uri (string-ascii 256) "https://ipfs.io/ipfs/QmXtnT5CeDYMyxovYRcQuM6xb6cubt8JUKh1xcyiSPYMkQ/{id}.json")

;; 3. Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant COLLECTION-LIMIT u1000) ;; Limited to 1,000 supply

;; Error Codes
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))
(define-constant ERR-SOLD-OUT (err u300))

;; 4. SIP-009 Read-Only Functions

;; Get the last minted token ID
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

;; Get the metadata URI for a specific token
(define-read-only (get-token-uri (token-id uint))
  (ok (some (var-get base-uri)))
)

;; Get the current owner of a specific token
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? dedollz token-id))
)

;; 5. Public Functions

;; Transfer an NFT to a new recipient
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-TOKEN-OWNER)
    (nft-transfer? dedollz token-id sender recipient)
  )
)

;; Mint a new Dedollz NFT
(define-public (mint (recipient principal))
  (let ((token-id (+ (var-get last-token-id) u1)))
    ;; Ensure it doesn't exceed 1,000
    (asserts! (<= token-id COLLECTION-LIMIT) ERR-SOLD-OUT)
    
    ;; Minting logic
    (try! (nft-mint? dedollz token-id recipient))
    
    ;; Update the counter
    (var-set last-token-id token-id)
    (ok token-id)
  )
)

;; Admin function to update metadata URI if needed
(define-public (set-base-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set base-uri new-uri)
    (ok true)
  )
)