;; StakeFlow NFT - SIP-009 Non-Fungible Token
;; Minting costs 0.001 STX per NFT
;; MAINNET VERSION

(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant TREASURY 'SP1ZYBVXD24AG7HNQ9PXB7TBCY2FD4YWT307FRKA3)
(define-constant MINT-PRICE u100000) ;; 0.001 STX = 100,000 microSTX
(define-constant MAX-SUPPLY u10000000) ;; 10 million NFTs

;; Errors
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))
(define-constant ERR-TOKEN-NOT-FOUND (err u102))
(define-constant ERR-SOLD-OUT (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-TRANSFER-FAILED (err u105))

;; NFT Definition
(define-non-fungible-token stakeflow-nft uint)

;; Data vars
(define-data-var last-token-id uint u0)
(define-data-var base-uri (string-ascii 256) "https://stakeflow.io/metadata/")
(define-data-var mint-paused bool false)

;; ---------------------------------------------------------
;; SIP-009 Functions
;; ---------------------------------------------------------

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (some (var-get base-uri)))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? stakeflow-nft token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (nft-get-owner? stakeflow-nft token-id)) ERR-TOKEN-NOT-FOUND)
    (nft-transfer? stakeflow-nft token-id sender recipient)
  )
)

;; ---------------------------------------------------------
;; Minting Functions
;; ---------------------------------------------------------

(define-public (mint)
  (let
    (
      (next-id (+ (var-get last-token-id) u1))
    )
    ;; Check not paused
    (asserts! (not (var-get mint-paused)) ERR-NOT-AUTHORIZED)
    ;; Check supply
    (asserts! (<= next-id MAX-SUPPLY) ERR-SOLD-OUT)
    ;; Transfer mint fee to treasury
    (try! (stx-transfer? MINT-PRICE tx-sender TREASURY))
    ;; Mint NFT
    (try! (nft-mint? stakeflow-nft next-id tx-sender))
    ;; Update last token id
    (var-set last-token-id next-id)
    (ok next-id)
  )
)

;; Mint multiple NFTs (up to 10 at once)
(define-public (mint-many (count uint))
  (begin
    (asserts! (not (var-get mint-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (<= count u10) ERR-NOT-AUTHORIZED)
    (asserts! (<= (+ (var-get last-token-id) count) MAX-SUPPLY) ERR-SOLD-OUT)
    (try! (stx-transfer? (* MINT-PRICE count) tx-sender TREASURY))
    (ok (fold mint-one 
      (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) 
      { count: count, minted: u0 }
    ))
  )
)

(define-private (mint-one (idx uint) (state { count: uint, minted: uint }))
  (if (< (get minted state) (get count state))
    (let ((next-id (+ (var-get last-token-id) u1)))
      (match (nft-mint? stakeflow-nft next-id tx-sender)
        success
          (begin
            (var-set last-token-id next-id)
            { count: (get count state), minted: (+ (get minted state) u1) }
          )
        error state
      )
    )
    state
  )
)

;; ---------------------------------------------------------
;; Admin Functions
;; ---------------------------------------------------------

(define-public (set-base-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set base-uri new-uri))
  )
)

(define-public (set-mint-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set mint-paused paused))
  )
)

;; ---------------------------------------------------------
;; Read-only Functions
;; ---------------------------------------------------------

(define-read-only (get-mint-price)
  MINT-PRICE
)

(define-read-only (get-max-supply)
  MAX-SUPPLY
)

(define-read-only (get-remaining-supply)
  (- MAX-SUPPLY (var-get last-token-id))
)

(define-read-only (is-mint-paused)
  (var-get mint-paused)
)

(define-read-only (get-treasury)
  TREASURY
)
