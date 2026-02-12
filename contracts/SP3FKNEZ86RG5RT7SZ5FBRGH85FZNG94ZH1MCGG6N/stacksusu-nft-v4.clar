(define-constant CONTRACT-OWNER tx-sender)

(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-NOT-FOUND (err u1001))
(define-constant ERR-ALREADY-MINTED (err u1002))
(define-constant ERR-NOT-OWNER (err u1003))
(define-constant ERR-LISTING-NOT-FOUND (err u1004))
(define-constant ERR-WRONG-PRICE (err u1005))
(define-constant ERR-CANNOT-TRANSFER (err u1006))
(define-constant ERR-CIRCLE-NOT-TRADEABLE (err u1007))
(define-constant ERR-SELF-TRANSFER (err u1008))
(define-constant ERR-PAUSED (err u1021))
(define-constant ERR-TRANSFER-FAILED (err u1017))

(define-non-fungible-token stacksusu-slot uint)

(define-data-var token-id-counter uint u0)
(define-data-var base-uri (string-ascii 256) "https://api.stacksusu.xyz/metadata/")

(define-map token-metadata
  uint
  { circle-id: uint, slot: uint, original-owner: principal, minted-at: uint }
)

(define-map slot-to-token
  { circle-id: uint, slot: uint }
  uint
)

(define-map slot-holder
  { circle-id: uint, slot: uint }
  principal
)

(define-map listings
  uint
  { price: uint, seller: principal, listed-at: uint }
)

(define-map circle-trading-enabled uint bool)
(define-map authorized-minters principal bool)


(define-read-only (is-authorized-minter (caller principal))
  (or (is-eq caller CONTRACT-OWNER) (default-to false (map-get? authorized-minters caller)))
)

(define-public (authorize-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-minters minter true))
  )
)

(define-public (revoke-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-minters minter))
  )
)


(define-read-only (get-last-token-id)
  (ok (var-get token-id-counter))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (some (var-get base-uri)))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? stacksusu-slot token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let
    (
      (token-info (unwrap! (map-get? token-metadata token-id) ERR-NOT-FOUND))
      (circle-id (get circle-id token-info))
      (slot (get slot token-info))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v4 is-paused)) ERR-PAUSED)
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq sender recipient)) ERR-SELF-TRANSFER)
    (asserts! (is-trading-enabled circle-id) ERR-CIRCLE-NOT-TRADEABLE)
    (asserts! (is-eq (some sender) (nft-get-owner? stacksusu-slot token-id)) ERR-NOT-OWNER)
    
    (try! (nft-transfer? stacksusu-slot token-id sender recipient))
    (try! (contract-call? .stacksusu-core-v4 update-slot-holder circle-id slot recipient))
    (map-set slot-holder { circle-id: circle-id, slot: slot } recipient)
    (map-delete listings token-id)
    (ok true)
  )
)


(define-public (mint-slot-nft (circle-id uint) (slot uint) (member principal))
  (let ((token-id (+ (var-get token-id-counter) u1)))
    (asserts! (is-authorized-minter contract-caller) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? slot-to-token { circle-id: circle-id, slot: slot })) ERR-ALREADY-MINTED)
    
    (try! (nft-mint? stacksusu-slot token-id member))
    
    (map-set token-metadata token-id
      { circle-id: circle-id, slot: slot, original-owner: member, minted-at: block-height }
    )
    (map-set slot-to-token { circle-id: circle-id, slot: slot } token-id)
    (map-set slot-holder { circle-id: circle-id, slot: slot } member)
    (var-set token-id-counter token-id)
    (ok token-id)
  )
)


(define-public (list-for-sale (token-id uint) (price uint))
  (let
    (
      (owner (unwrap! (nft-get-owner? stacksusu-slot token-id) ERR-NOT-FOUND))
      (token-info (unwrap! (map-get? token-metadata token-id) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender owner) ERR-NOT-OWNER)
    (asserts! (is-trading-enabled (get circle-id token-info)) ERR-CIRCLE-NOT-TRADEABLE)
    (asserts! (> price u0) ERR-WRONG-PRICE)
    
    (map-set listings token-id { price: price, seller: tx-sender, listed-at: block-height })
    (ok true)
  )
)

(define-public (unlist (token-id uint))
  (let ((listing (unwrap! (map-get? listings token-id) ERR-LISTING-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get seller listing)) ERR-NOT-AUTHORIZED)
    (map-delete listings token-id)
    (ok true)
  )
)

(define-public (buy-slot (token-id uint))
  (let
    (
      (listing (unwrap! (map-get? listings token-id) ERR-LISTING-NOT-FOUND))
      (price (get price listing))
      (seller (get seller listing))
      (buyer tx-sender)
      (token-info (unwrap! (map-get? token-metadata token-id) ERR-NOT-FOUND))
      (circle-id (get circle-id token-info))
      (slot (get slot token-info))
    )
    (asserts! (not (is-eq buyer seller)) ERR-SELF-TRANSFER)
    (asserts! (is-trading-enabled circle-id) ERR-CIRCLE-NOT-TRADEABLE)
    
    (match (stx-transfer? price buyer seller)
      success
        (begin
          (try! (nft-transfer? stacksusu-slot token-id seller buyer))
          (try! (contract-call? .stacksusu-core-v4 update-slot-holder circle-id slot buyer))
          (map-set slot-holder { circle-id: circle-id, slot: slot } buyer)
          (map-delete listings token-id)
          (ok price)
        )
      error ERR-TRANSFER-FAILED
    )
  )
)


(define-public (set-circle-trading (circle-id uint) (enabled bool))
  (let
    (
      (circle-info (unwrap! (contract-call? .stacksusu-core-v4 get-circle-info circle-id) ERR-NOT-FOUND))
      (circle (unwrap! circle-info ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get creator circle)) ERR-NOT-AUTHORIZED)
    (ok (map-set circle-trading-enabled circle-id enabled))
  )
)

(define-read-only (is-trading-enabled (circle-id uint))
  (default-to true (map-get? circle-trading-enabled circle-id))
)


(define-read-only (get-token-info (token-id uint))
  (ok (map-get? token-metadata token-id))
)

(define-read-only (get-token-by-slot (circle-id uint) (slot uint))
  (ok (map-get? slot-to-token { circle-id: circle-id, slot: slot }))
)

(define-read-only (get-slot-holder (circle-id uint) (slot uint))
  (ok (map-get? slot-holder { circle-id: circle-id, slot: slot }))
)

(define-read-only (get-listing (token-id uint))
  (ok (map-get? listings token-id))
)

(define-public (set-base-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set base-uri new-uri))
  )
)
