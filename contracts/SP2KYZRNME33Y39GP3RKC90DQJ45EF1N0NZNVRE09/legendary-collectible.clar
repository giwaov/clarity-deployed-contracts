;; Legendary Collectible NFT Contract
;; Implements SIP-009 NFT standard
;; Supply: 1,000 | Mint Price: 0.07 STX

(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Define the NFT
(define-non-fungible-token legendary-collectible uint)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-SOLD-OUT (err u101))
(define-constant ERR-INSUFFICIENT-FUNDS (err u102))
(define-constant ERR-NOT-TOKEN-OWNER (err u103))

;; Pricing: 0.07 STX = 70,000 microSTX
(define-constant MINT-PRICE u70000)
(define-constant MAX-SUPPLY u1000)

;; Data Variables
(define-data-var last-token-id uint u0)
(define-data-var base-uri (string-ascii 256) "https://mintmart.io/api/metadata/legendary/")

;; SIP-009 Functions
(define-read-only (get-last-token-id)
    (ok (var-get last-token-id)))

(define-read-only (get-token-uri (token-id uint))
    (ok (some (var-get base-uri))))

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? legendary-collectible token-id)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (nft-transfer? legendary-collectible token-id sender recipient)))

;; Mint Functions
(define-public (mint)
    (let ((next-id (+ (var-get last-token-id) u1)))
        (asserts! (<= next-id MAX-SUPPLY) ERR-SOLD-OUT)
        (try! (stx-transfer? MINT-PRICE tx-sender CONTRACT-OWNER))
        (try! (nft-mint? legendary-collectible next-id tx-sender))
        (var-set last-token-id next-id)
        (ok next-id)))

;; Batch mint for gas optimization
(define-public (mint-many (count uint))
    (let ((start-id (var-get last-token-id))
          (end-id (+ start-id count)))
        (asserts! (<= end-id MAX-SUPPLY) ERR-SOLD-OUT)
        (try! (stx-transfer? (* MINT-PRICE count) tx-sender CONTRACT-OWNER))
        (try! (fold mint-iter (list u1 u2 u3 u4 u5) (ok start-id)))
        (ok end-id)))

(define-private (mint-iter (n uint) (prev-result (response uint uint)))
    (match prev-result
        prev-id (let ((next-id (+ prev-id u1)))
            (if (<= next-id MAX-SUPPLY)
                (begin
                    (try! (nft-mint? legendary-collectible next-id tx-sender))
                    (var-set last-token-id next-id)
                    (ok next-id))
                ERR-SOLD-OUT))
        err-val (err err-val)))

;; Read-only helpers
(define-read-only (get-mint-price)
    (ok MINT-PRICE))

(define-read-only (get-max-supply)
    (ok MAX-SUPPLY))

(define-read-only (get-available-supply)
    (ok (- MAX-SUPPLY (var-get last-token-id))))

;; Admin Functions
(define-public (set-base-uri (new-uri (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set base-uri new-uri)
        (ok true)))
