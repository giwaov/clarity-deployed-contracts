---
title: "Trait knight-game"
draft: true
---
```
;; Gamin Gaming Platform Smart Contract
;; Handles in-game asset ownership and trading functionality

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-not-authorized (err u102))
(define-constant err-invalid-input (err u103))
(define-constant err-invalid-price (err u104))
(define-constant max-level u100)
(define-constant max-experience u10000)
(define-constant max-metadata-length u256)
(define-constant max-batch-size u10) ;; Limit batch operations to prevent potential gas issues

;; Data Variables
(define-map assets
  { asset-id: uint }
  {
    owner: principal,
    metadata-uri: (string-utf8 256),
    transferable: bool,
  }
)

(define-map asset-prices
  { asset-id: uint }
  { price: uint }
)

(define-map player-stats
  { player: principal }
  {
    experience: uint,
    level: uint,
  }
)

(define-map marketplace-listings
  { asset-id: uint }
  {
    seller: principal,
    price: uint,
    listed-at: uint,
  }
)

;; Asset Counter
(define-data-var asset-counter uint u0)

;; Helper Functions

;; Validate asset exists and return asset data
(define-private (get-asset-checked (asset-id uint))
  (let ((asset (map-get? assets { asset-id: asset-id })))
    (asserts!
      (and
        (is-some asset)
        (<= asset-id (var-get asset-counter))
      )
      err-not-found
    )
    (ok (unwrap-panic asset))
  )
)

;; Validate metadata URI length
(define-private (validate-metadata-uri (uri (string-utf8 256)))
  (let ((uri-length (len uri)))
    (and
      (> uri-length u0)
      (<= uri-length max-metadata-length)
    )
  )
)

;; Public Functions

;; Batch Mint new gaming assets
(define-public (batch-mint-assets
    (metadata-uris (list 10 (string-utf8 256)))
    (transferable-list (list 10 bool))
  )
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts!
      (and
        (> (len metadata-uris) u0)
        (<= (len metadata-uris) max-batch-size)
        (is-eq (len metadata-uris) (len transferable-list))
      )
      err-invalid-input
    )
    (let ((minted-assets (map mint-single-asset metadata-uris transferable-list)))
      (ok minted-assets)
    )
  )
)

;; Helper function for batch minting
(define-private (mint-single-asset
    (uri (string-utf8 256))
    (transferable bool)
  )
  (let ((asset-id (+ (var-get asset-counter) u1)))
    (asserts! (validate-metadata-uri uri) err-invalid-input)
    (map-set assets { asset-id: asset-id } {
      owner: contract-owner,
      metadata-uri: uri,
      transferable: transferable,
    })
    (var-set asset-counter asset-id)
    (ok asset-id)
  )
)

;; Batch Transfer assets
(define-public (batch-transfer-assets
    (asset-ids (list 10 uint))
    (recipients (list 10 principal))
  )
  (begin
    (asserts!
      (and
        (> (len asset-ids) u0)
        (<= (len asset-ids) max-batch-size)
        (is-eq (len asset-ids) (len recipients))
      )
      err-invalid-input
    )
    (let ((transfers (map transfer-single-asset asset-ids recipients)))
      (ok transfers)
    )
  )
)

;; Helper function for batch transfer
(define-private (transfer-single-asset
    (asset-id uint)
    (recipient principal)
  )
  (let ((asset (unwrap-panic (get-asset-checked asset-id))))
    (asserts!
      (and
        (is-eq (get owner asset) tx-sender)
        (get transferable asset)
        (not (is-eq recipient tx-sender))
      )
      err-not-authorized
    )
    (map-set assets { asset-id: asset-id } {
      owner: recipient,
      metadata-uri: (get metadata-uri asset),
      transferable: (get transferable asset),
    })
    (ok true)
  )
)
;; Changed to return (ok true)

;; Mint single asset
(define-public (mint-asset
    (metadata-uri (string-utf8 256))
    (transferable bool)
  )
  (let ((asset-id (+ (var-get asset-counter) u1)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (validate-metadata-uri metadata-uri) err-invalid-input)
    (map-set assets { asset-id: asset-id } {
      owner: tx-sender,
      metadata-uri: metadata-uri,
      transferable: transferable,
    })
    (var-set asset-counter asset-id)
    (ok asset-id)
  )
)

;; Transfer asset ownership
(define-public (transfer-asset
    (asset-id uint)
    (recipient principal)
  )
  (begin
    (asserts! (<= asset-id (var-get asset-counter)) err-invalid-input)
    (let ((asset (try! (get-asset-checked asset-id))))
      (asserts!
        (and
          (is-eq (get owner asset) tx-sender)
          (get transferable asset)
          (not (is-eq recipient tx-sender))
        )
        err-not-authorized ;; Prevent self-transfers
      )
      (map-set assets { asset-id: asset-id } {
        owner: recipient,
        metadata-uri: (get metadata-uri asset),
        transferable: (get transferable asset),
      })
      (ok true)
    )
  )
)

;; List asset for sale with enhanced marketplace listing
(define-public (list-asset-for-sale
    (asset-id uint)
    (price uint)
  )
  (begin
    (asserts! (<= asset-id (var-get asset-counter)) err-invalid-input)
    (let ((asset (try! (get-asset-checked asset-id))))
      (asserts!
        (and
          (is-eq (get owner asset) tx-sender)
          (> price u0)
          (get transferable asset)
        )
        err-invalid-price
      )
      (map-set marketplace-listings { asset-id: asset-id } {
        seller: tx-sender,
        price: price,
        listed-at: stacks-block-height,
      })
      (ok true)
    )
  )
)

;; Purchase listed asset with enhanced marketplace mechanics
(define-public (purchase-asset (asset-id uint))
  (begin
    (asserts! (<= asset-id (var-get asset-counter)) err-invalid-input)
    (let (
        (asset (try! (get-asset-checked asset-id)))
        (listing (unwrap! (map-get? marketplace-listings { asset-id: asset-id })
          err-not-found
        ))
      )
      (asserts!
        (and
          (not (is-eq (get seller listing) tx-sender))
          (get transferable asset)
        )
        err-not-authorized
      )
      (try! (stx-transfer? (get price listing) tx-sender (get seller listing)))
      (map-set assets { asset-id: asset-id } {
        owner: tx-sender,
        metadata-uri: (get metadata-uri asset),
        transferable: (get transferable asset),
      })
      (map-delete marketplace-listings { asset-id: asset-id })
      (ok true)
    )
  )
)

;; Remove asset from marketplace listing
(define-public (delist-asset (asset-id uint))
  (begin
    ;; Validate asset-id is within the range of minted assets
    (asserts! (<= asset-id (var-get asset-counter)) err-invalid-input)

    ;; Try to get the listing, return error if not found
    (let ((listing (unwrap! (map-get? marketplace-listings { asset-id: asset-id })
        err-not-found
      )))
      ;; Ensure only the seller can delist
      (asserts! (is-eq tx-sender (get seller listing)) err-not-authorized)

      ;; Delete the marketplace listing
      (map-delete marketplace-listings { asset-id: asset-id })

      ;; Return success
      (ok true)
    )
  )
)

;; Update player stats with validation
(define-public (update-player-stats
    (experience uint)
    (level uint)
  )
  (begin
    (asserts! (<= experience max-experience) err-invalid-input)
    (asserts! (<= level max-level) err-invalid-input)
    (map-set player-stats { player: tx-sender } {
      experience: experience,
      level: level,
    })
    (ok true)
  )
)

;; Read-only Functions

;; Get asset details
(define-read-only (get-asset-details (asset-id uint))
  (if (<= asset-id (var-get asset-counter))
    (map-get? assets { asset-id: asset-id })
    none
  )
)

;; Get marketplace listing details
(define-read-only (get-marketplace-listing (asset-id uint))
  (map-get? marketplace-listings { asset-id: asset-id })
)

;; Get player stats
(define-read-only (get-player-stats (player principal))
  (map-get? player-stats { player: player })
)

;; Get total assets minted
(define-read-only (get-total-assets)
  (var-get asset-counter)
)

```
