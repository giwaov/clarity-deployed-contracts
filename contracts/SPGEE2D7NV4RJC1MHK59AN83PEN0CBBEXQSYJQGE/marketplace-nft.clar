;; NFT Marketplace Contract - Clarity 4
;; Allows users to mint, list, buy, and trade NFTs

(define-non-fungible-token marketplace-nft uint)

(define-data-var last-token-id uint u0)
(define-data-var marketplace-fee-percent uint u250) ;; 2.5% fee

(define-map token-listings
  uint
  {
    seller: principal,
    price: uint,
    listed: bool
  }
)

(define-map token-metadata
  uint
  {
    name: (string-utf8 64),
    uri: (string-utf8 256),
    creator: principal,
    royalty: uint
  }
)

(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-listed (err u102))
(define-constant err-not-listed (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-transfer-failed (err u105))

;; Read-only functions
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (get uri (unwrap! (map-get? token-metadata token-id) err-not-found)))
)

(define-read-only (get-owner (token-id uint))
  (ok (unwrap! (nft-get-owner? marketplace-nft token-id) err-not-found))
)

(define-read-only (get-listing (token-id uint))
  (ok (unwrap! (map-get? token-listings token-id) err-not-found))
)

(define-read-only (get-marketplace-fee)
  (ok (var-get marketplace-fee-percent))
)

(define-read-only (get-token-metadata (token-id uint))
  (ok (unwrap! (map-get? token-metadata token-id) err-not-found))
)

;; Mint new NFT
(define-public (mint-nft (name (string-utf8 64)) (uri (string-utf8 256)) (royalty uint))
  (let
    (
      (token-id (+ (var-get last-token-id) u1))
    )
    (asserts! (<= royalty u1000) (err u106)) ;; Max 10% royalty
    (try! (nft-mint? marketplace-nft token-id tx-sender))
    (map-set token-metadata token-id {
      name: name,
      uri: uri,
      creator: tx-sender,
      royalty: royalty
    })
    (var-set last-token-id token-id)
    (ok token-id)
  )
)

;; List NFT for sale
(define-public (list-nft (token-id uint) (price uint))
  (let
    (
      (owner (unwrap! (nft-get-owner? marketplace-nft token-id) err-not-found))
    )
    (asserts! (is-eq tx-sender owner) err-not-authorized)
    (asserts! (> price u0) (err u107))
    (map-set token-listings token-id {
      seller: tx-sender,
      price: price,
      listed: true
    })
    (ok true)
  )
)

;; Unlist NFT
(define-public (unlist-nft (token-id uint))
  (let
    (
      (listing (unwrap! (map-get? token-listings token-id) err-not-listed))
      (owner (unwrap! (nft-get-owner? marketplace-nft token-id) err-not-found))
    )
    (asserts! (is-eq tx-sender owner) err-not-authorized)
    (map-delete token-listings token-id)
    (ok true)
  )
)

;; Buy NFT
(define-public (buy-nft (token-id uint))
  (let
    (
      (listing (unwrap! (map-get? token-listings token-id) err-not-listed))
      (metadata (unwrap! (map-get? token-metadata token-id) err-not-found))
      (price (get price listing))
      (seller (get seller listing))
      (marketplace-fee (/ (* price (var-get marketplace-fee-percent)) u10000))
      (royalty-fee (/ (* price (get royalty metadata)) u10000))
      (seller-amount (- (- price marketplace-fee) royalty-fee))
    )
    (asserts! (get listed listing) err-not-listed)
    (asserts! (not (is-eq tx-sender seller)) err-not-authorized)
    
    ;; Transfer payment
    (try! (stx-transfer? seller-amount tx-sender seller))
    (try! (stx-transfer? marketplace-fee tx-sender contract-owner))
    (try! (stx-transfer? royalty-fee tx-sender (get creator metadata)))
    
    ;; Transfer NFT
    (try! (nft-transfer? marketplace-nft token-id seller tx-sender))
    
    ;; Remove listing
    (map-delete token-listings token-id)
    
    (ok true)
  )
)

;; Transfer NFT
(define-public (transfer-nft (token-id uint) (recipient principal))
  (let
    (
      (owner (unwrap! (nft-get-owner? marketplace-nft token-id) err-not-found))
    )
    (asserts! (is-eq tx-sender owner) err-not-authorized)
    (map-delete token-listings token-id)
    (try! (nft-transfer? marketplace-nft token-id tx-sender recipient))
    (ok true)
  )
)

;; Update marketplace fee (owner only)
(define-public (set-marketplace-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
    (asserts! (<= new-fee u1000) (err u108)) ;; Max 10% fee
    (var-set marketplace-fee-percent new-fee)
    (ok true)
  )
)
