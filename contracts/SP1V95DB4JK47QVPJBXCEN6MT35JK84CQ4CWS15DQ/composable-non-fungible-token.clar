(define-non-fungible-token composable-nft uint)

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EQUIPPED (err u102))
(define-constant ERR-NOT-EQUIPPED (err u103))
(define-constant ERR-INVALID-SLOT (err u104))
(define-constant ERR-INVALID-PART (err u105))

(define-data-var token-id-nonce uint u0)
(define-data-var catalog-contract (optional principal) none)

(define-map token-uri uint (string-ascii 256))
(define-map token-assets uint (list 10 uint))
(define-map asset-parts uint {
  catalog: principal,
  parts: (list 20 uint),
  equippable-group: uint
})
(define-map equipped-items uint (list 10 {
  asset-id: uint,
  child-asset-id: uint,
  child-id: uint,
  child-contract: principal,
  slot-part-id: uint
}))
(define-map slot-parts uint {
  z-index: uint,
  equippable: (list 10 principal)
})
(define-map fixed-parts uint {
  z-index: uint,
  metadata: (string-ascii 256)
})

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce))
)

(define-read-only (get-token-uri (token uint))
  (ok (map-get? token-uri token))
)

(define-read-only (get-owner (token uint))
  (ok (nft-get-owner? composable-nft token))
)

(define-read-only (get-assets (token uint))
  (ok (default-to (list) (map-get? token-assets token)))
)

(define-read-only (get-asset-parts (asset-id uint))
  (ok (map-get? asset-parts asset-id))
)

(define-read-only (get-equipped-items (token uint))
  (ok (default-to (list) (map-get? equipped-items token)))
)

(define-read-only (get-slot-part (part-id uint))
  (ok (map-get? slot-parts part-id))
)

(define-read-only (get-fixed-part (part-id uint))
  (ok (map-get? fixed-parts part-id))
)

(define-read-only (is-child-equipped (token uint) (child-contract principal) (child-id uint))
  (let ((equipped (default-to (list) (map-get? equipped-items token))))
    (ok (is-some (index-of equipped {
      asset-id: u0,
      child-asset-id: u0,
      child-id: child-id,
      child-contract: child-contract,
      slot-part-id: u0
    })))
  )
)

(define-read-only (is-equipped (token uint) (asset-id uint) (slot-part-id uint))
  (let ((equipped (default-to (list) (map-get? equipped-items token))))
    (ok (> (len equipped) u0))
  )
)

(define-public (mint (recipient principal) (uri (string-ascii 256)))
  (let ((new-id (+ (var-get token-id-nonce) u1)))
    (try! (nft-mint? composable-nft new-id recipient))
    (map-set token-uri new-id uri)
    (var-set token-id-nonce new-id)
    (ok new-id)
  )
)

(define-public (transfer (token uint) (sender principal) (recipient principal))
  (let ((owner (unwrap! (nft-get-owner? composable-nft token) ERR-NOT-FOUND)))
    (asserts! (or (is-eq tx-sender owner) (is-eq tx-sender sender)) ERR-NOT-AUTHORIZED)
    (try! (nft-transfer? composable-nft token sender recipient))
    (ok true)
  )
)

(define-public (add-asset (token uint) (asset-id uint) (catalog principal) (parts (list 20 uint)) (equippable-group uint))
  (let ((owner (unwrap! (nft-get-owner? composable-nft token) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
    (map-set asset-parts asset-id {
      catalog: catalog,
      parts: parts,
      equippable-group: equippable-group
    })
    (let ((current-assets (default-to (list) (map-get? token-assets token))))
      (map-set token-assets token (unwrap! (as-max-len? (append current-assets asset-id) u10) ERR-INVALID-PART))
    )
    (ok true)
  )
)

(define-public (equip (token uint) (child-index uint) (asset-id uint) (slot-part-id uint) (child-asset-id uint))
  (let ((owner (unwrap! (nft-get-owner? composable-nft token) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
    (ok true)
  )
)

(define-public (unequip (token uint) (asset-id uint) (slot-part-id uint))
  (let (
    (owner (unwrap! (nft-get-owner? composable-nft token) ERR-NOT-FOUND))
    (current-equipped (default-to (list) (map-get? equipped-items token)))
  )
    (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
    (map-set equipped-items token (filter remove-equipped-item current-equipped))
    (ok true)
  )
)

(define-public (add-slot-part (part-id uint) (z-index uint) (equippable (list 10 principal)))
  (begin
    (map-set slot-parts part-id {z-index: z-index, equippable: equippable})
    (ok true)
  )
)

(define-public (add-fixed-part (part-id uint) (z-index uint) (metadata (string-ascii 256)))
  (begin
    (map-set fixed-parts part-id {z-index: z-index, metadata: metadata})
    (ok true)
  )
)

(define-private (remove-equipped-item (item {
  asset-id: uint,
  child-asset-id: uint,
  child-id: uint,
  child-contract: principal,
  slot-part-id: uint
}))
  true
)
