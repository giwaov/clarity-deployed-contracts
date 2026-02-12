;; mintMart - Common Collectible NFT Contract
;; Rarity: Common | Supply: 10,000 | Price: 0.01 STX (10000 microSTX)

;; SIP-009 NFT Trait
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-OWNER (err u100))
(define-constant ERR-SOLD-OUT (err u101))
(define-constant ERR-WRONG-PRICE (err u102))
(define-constant ERR-NOT-TOKEN-OWNER (err u103))
(define-constant ERR-LISTING-NOT-FOUND (err u104))

(define-constant MINT-PRICE u10000) ;; 0.01 STX in microSTX
(define-constant MAX-SUPPLY u10000)

;; Data Variables
(define-data-var last-token-id uint u0)
(define-data-var base-uri (string-ascii 200) "https://mintmart.io/api/metadata/common/")

;; NFT Definition
(define-non-fungible-token common-collectible uint)

;; SIP-009 Functions
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id)))

(define-read-only (get-token-uri (token-id uint))
  (ok (some (var-get base-uri))))

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? common-collectible token-id)))

;; Transfer function
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-TOKEN-OWNER)
    (nft-transfer? common-collectible token-id sender recipient)))

;; Mint function - optimized for low gas
(define-public (mint)
  (let ((next-id (+ (var-get last-token-id) u1)))
    (asserts! (<= next-id MAX-SUPPLY) ERR-SOLD-OUT)
    (try! (stx-transfer? MINT-PRICE tx-sender CONTRACT-OWNER))
    (try! (nft-mint? common-collectible next-id tx-sender))
    (var-set last-token-id next-id)
    (ok next-id)))

;; Batch mint for scripts - more gas efficient for multiple mints
(define-public (mint-many (count uint))
  (let ((start-id (var-get last-token-id)))
    (asserts! (<= (+ start-id count) MAX-SUPPLY) ERR-SOLD-OUT)
    (try! (stx-transfer? (* MINT-PRICE count) tx-sender CONTRACT-OWNER))
    (fold mint-single (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) (ok start-id))))

(define-private (mint-single (n uint) (prev-result (response uint uint)))
  (match prev-result
    prev-id (let ((next-id (+ prev-id u1)))
              (if (<= next-id MAX-SUPPLY)
                (match (nft-mint? common-collectible next-id tx-sender)
                  success (begin (var-set last-token-id next-id) (ok next-id))
                  error (ok prev-id))
                (ok prev-id)))
    error (err error)))

;; Read-only functions
(define-read-only (get-mint-price)
  (ok MINT-PRICE))

(define-read-only (get-max-supply)
  (ok MAX-SUPPLY))

(define-read-only (get-available-supply)
  (ok (- MAX-SUPPLY (var-get last-token-id))))

;; Admin functions
(define-public (set-base-uri (new-uri (string-ascii 200)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-OWNER)
    (var-set base-uri new-uri)
    (ok true)))
