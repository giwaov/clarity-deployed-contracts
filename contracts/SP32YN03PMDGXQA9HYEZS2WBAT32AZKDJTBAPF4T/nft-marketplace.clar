;; Dedollz NFT Marketplace
;; A marketplace for Dedollz and other whitelisted SIP-009 NFTs on Stacks Mainnet.

;; 1. Trait Definitions
(use-trait nft-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)
(use-trait ft-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; 2. Constants & Variables
(define-constant CONTRACT-OWNER tx-sender)

;; Error Codes
(define-constant ERR-EXPIRY-IN-PAST (err u1000))
(define-constant ERR-PRICE-ZERO (err u1001))
(define-constant ERR-UNKNOWN-LISTING (err u2000))
(define-constant ERR-UNAUTHORISED (err u2001))
(define-constant ERR-LISTING-EXPIRED (err u2002))
(define-constant ERR-NFT-ASSET-MISMATCH (err u2003))
(define-constant ERR-PAYMENT-ASSET-MISMATCH (err u2004))
(define-constant ERR-MAKER-TAKER-EQUAL (err u2005))
(define-constant ERR-UNINTENDED-TAKER (err u2006))
(define-constant ERR-ASSET-NOT-WHITELISTED (err u2007))
(define-constant ERR-PAYMENT-NOT-WHITELISTED (err u2008))

;; Data Structures
(define-map listings
  uint
  {
    maker: principal,
    taker: (optional principal),
    token-id: uint,
    nft-asset-contract: principal,
    expiry: uint,
    price: uint,
    payment-asset-contract: (optional principal),
  }
)

(define-data-var listing-nonce uint u0)

;; Whitelist management
(define-map whitelisted-asset-contracts principal bool)

;; 3. Read-Only Functions

(define-read-only (is-whitelisted (asset-contract principal))
  (default-to true (map-get? whitelisted-asset-contracts asset-contract))
)

(define-read-only (get-listing (listing-id uint))
  (map-get? listings listing-id)
)

;; 4. Administrative Functions

(define-public (set-whitelisted (asset-contract principal) (whitelisted bool))
  (begin
    (asserts! (is-eq CONTRACT-OWNER tx-sender) ERR-UNAUTHORISED)
    (ok (map-set whitelisted-asset-contracts asset-contract whitelisted))
  )
)

;; 5. Private Helper Functions

(define-private (transfer-nft (token-contract <nft-trait>) (token-id uint) (sender principal) (recipient principal))
  (contract-call? token-contract transfer token-id sender recipient)
)

(define-private (transfer-ft (token-contract <ft-trait>) (amount uint) (sender principal) (recipient principal))
  (contract-call? token-contract transfer amount sender recipient none)
)

(define-private (assert-can-fulfil (nft-asset-contract principal) (payment-asset-contract (optional principal)) (listing {maker: principal, taker: (optional principal), token-id: uint, nft-asset-contract: principal, expiry: uint, price: uint, payment-asset-contract: (optional principal)}))
  (begin
    (asserts! (not (is-eq (get maker listing) tx-sender)) ERR-MAKER-TAKER-EQUAL)
    (asserts! (match (get taker listing) intended-taker (is-eq intended-taker tx-sender) true) ERR-UNINTENDED-TAKER)
    (asserts! (< burn-block-height (get expiry listing)) ERR-LISTING-EXPIRED)
    (asserts! (is-eq (get nft-asset-contract listing) nft-asset-contract) ERR-NFT-ASSET-MISMATCH)
    (asserts! (is-eq (get payment-asset-contract listing) payment-asset-contract) ERR-PAYMENT-ASSET-MISMATCH)
    (ok true)
  )
)

;; 6. Public Marketplace Functions

;; List an NFT for sale
(define-public (list-asset (nft-asset-contract <nft-trait>) (nft-asset {taker: (optional principal), token-id: uint, expiry: uint, price: uint, payment-asset-contract: (optional principal)}))
  (let ((listing-id (var-get listing-nonce)))
    (asserts! (is-whitelisted (contract-of nft-asset-contract)) ERR-ASSET-NOT-WHITELISTED)
    (asserts! (> (get expiry nft-asset) burn-block-height) ERR-EXPIRY-IN-PAST)
    (asserts! (> (get price nft-asset) u0) ERR-PRICE-ZERO)
    
    ;; Transfer NFT to Marketplace Escrow
    (try! (transfer-nft nft-asset-contract (get token-id nft-asset) tx-sender (as-contract tx-sender)))
    
    (map-set listings listing-id
      (merge {
        maker: tx-sender,
        nft-asset-contract: (contract-of nft-asset-contract),
      }
      nft-asset
    ))
    
    (var-set listing-nonce (+ listing-id u1))
    (ok listing-id)
  )
)

;; Cancel a listing
(define-public (cancel-listing (listing-id uint) (nft-asset-contract <nft-trait>))
  (let (
    (listing (unwrap! (map-get? listings listing-id) ERR-UNKNOWN-LISTING))
    (maker (get maker listing))
  )
    (asserts! (is-eq maker tx-sender) ERR-UNAUTHORISED)
    (asserts! (is-eq (get nft-asset-contract listing) (contract-of nft-asset-contract)) ERR-NFT-ASSET-MISMATCH)
    
    (map-delete listings listing-id)
    (as-contract (transfer-nft nft-asset-contract (get token-id listing) tx-sender maker))
  )
)

;; Buy NFT with STX
(define-public (fulfil-listing-stx (listing-id uint) (nft-asset-contract <nft-trait>))
  (let (
    (listing (unwrap! (map-get? listings listing-id) ERR-UNKNOWN-LISTING))
    (taker tx-sender)
  )
    (try! (assert-can-fulfil (contract-of nft-asset-contract) none listing))
    
    ;; Payment
    (try! (stx-transfer? (get price listing) taker (get maker listing)))
    
    ;; NFT Transfer from Escrow to Buyer
    (try! (as-contract (transfer-nft nft-asset-contract (get token-id listing) tx-sender taker)))
    
    (map-delete listings listing-id)
    (ok listing-id)
  )
)

;; Buy NFT with Fungible Tokens (SIP-010)
(define-public (fulfil-listing-ft (listing-id uint) (nft-asset-contract <nft-trait>) (payment-asset-contract <ft-trait>))
  (let (
    (listing (unwrap! (map-get? listings listing-id) ERR-UNKNOWN-LISTING))
    (taker tx-sender)
  )
    (try! (assert-can-fulfil (contract-of nft-asset-contract) (some (contract-of payment-asset-contract)) listing))
    
    ;; Payment in FT
    (try! (transfer-ft payment-asset-contract (get price listing) taker (get maker listing)))
    
    ;; NFT Transfer from Escrow to Buyer
    (try! (as-contract (transfer-nft nft-asset-contract (get token-id listing) tx-sender taker)))
    
    (map-delete listings listing-id)
    (ok listing-id)
  )
)