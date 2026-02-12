---
title: "Trait stacksmint-collection"
draft: true
---
```
;; StacksMint Collection Contract
;; Manages NFT collections with metadata
;; Creator Fee: 0.01 STX per collection creation

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-NOT-COLLECTION-OWNER (err u103))
(define-constant ERR-INVALID-COLLECTION (err u104))
(define-constant ERR-TRANSFER-FAILED (err u105))
(define-constant CREATOR-FEE u10000) ;; 0.01 STX in microSTX

;; Data Variables
(define-data-var last-collection-id uint u0)

;; Data Maps
(define-map collections uint {
  owner: principal,
  name: (string-ascii 64),
  description: (string-ascii 256),
  image: (string-ascii 256),
  max-supply: uint,
  minted: uint,
  is-active: bool,
  created-at: uint
})

(define-map collection-by-owner principal (list 50 uint))

;; Read-only functions

;; Get creator fee
(define-read-only (get-creator-fee)
  CREATOR-FEE
)

;; Get last collection ID
(define-read-only (get-last-collection-id)
  (var-get last-collection-id)
)

;; Get collection by ID
(define-read-only (get-collection (collection-id uint))
  (map-get? collections collection-id)
)

;; Get collection owner
(define-read-only (get-collection-owner (collection-id uint))
  (match (map-get? collections collection-id)
    collection (some (get owner collection))
    none
  )
)

;; Get collection name
(define-read-only (get-collection-name (collection-id uint))
  (match (map-get? collections collection-id)
    collection (some (get name collection))
    none
  )
)

;; Check if collection exists
(define-read-only (collection-exists (collection-id uint))
  (is-some (map-get? collections collection-id))
)

;; Check if collection is active
(define-read-only (is-collection-active (collection-id uint))
  (match (map-get? collections collection-id)
    collection (get is-active collection)
    false
  )
)

;; Get collection minted count
(define-read-only (get-collection-minted (collection-id uint))
  (match (map-get? collections collection-id)
    collection (get minted collection)
    u0
  )
)

;; Get collection max supply
(define-read-only (get-collection-max-supply (collection-id uint))
  (match (map-get? collections collection-id)
    collection (get max-supply collection)
    u0
  )
)

;; Check if collection can mint more
(define-read-only (can-mint (collection-id uint))
  (match (map-get? collections collection-id)
    collection (and 
      (get is-active collection)
      (< (get minted collection) (get max-supply collection))
    )
    false
  )
)

;; Public functions

;; Create new collection with creator fee
(define-public (create-collection 
  (name (string-ascii 64))
  (description (string-ascii 256))
  (image (string-ascii 256))
  (max-supply uint)
)
  (let
    (
      (collection-id (+ (var-get last-collection-id) u1))
    )
    ;; Pay creator fee
    (try! (stx-transfer? CREATOR-FEE tx-sender CONTRACT-OWNER))
    ;; Create collection
    (map-set collections collection-id {
      owner: tx-sender,
      name: name,
      description: description,
      image: image,
      max-supply: max-supply,
      minted: u0,
      is-active: true,
      created-at: block-height
    })
    ;; Update last collection ID
    (var-set last-collection-id collection-id)
    (ok collection-id)
  )
)

;; Increment collection minted count (called when NFT minted to collection)
(define-public (increment-minted (collection-id uint))
  (match (map-get? collections collection-id)
    collection (begin
      (asserts! (get is-active collection) ERR-INVALID-COLLECTION)
      (asserts! (< (get minted collection) (get max-supply collection)) ERR-INVALID-COLLECTION)
      (map-set collections collection-id 
        (merge collection { minted: (+ (get minted collection) u1) })
      )
      (ok true)
    )
    ERR-NOT-FOUND
  )
)

;; Update collection metadata (collection owner only)
(define-public (update-collection 
  (collection-id uint)
  (name (string-ascii 64))
  (description (string-ascii 256))
  (image (string-ascii 256))
)
  (match (map-get? collections collection-id)
    collection (begin
      (asserts! (is-eq tx-sender (get owner collection)) ERR-NOT-COLLECTION-OWNER)
      (map-set collections collection-id 
        (merge collection { 
          name: name, 
          description: description, 
          image: image 
        })
      )
      (ok true)
    )
    ERR-NOT-FOUND
  )
)

;; Pause collection (collection owner only)
(define-public (pause-collection (collection-id uint))
  (match (map-get? collections collection-id)
    collection (begin
      (asserts! (is-eq tx-sender (get owner collection)) ERR-NOT-COLLECTION-OWNER)
      (map-set collections collection-id 
        (merge collection { is-active: false })
      )
      (ok true)
    )
    ERR-NOT-FOUND
  )
)

;; Resume collection (collection owner only)
(define-public (resume-collection (collection-id uint))
  (match (map-get? collections collection-id)
    collection (begin
      (asserts! (is-eq tx-sender (get owner collection)) ERR-NOT-COLLECTION-OWNER)
      (map-set collections collection-id 
        (merge collection { is-active: true })
      )
      (ok true)
    )
    ERR-NOT-FOUND
  )
)

;; Transfer collection ownership (collection owner only)
(define-public (transfer-collection (collection-id uint) (new-owner principal))
  (match (map-get? collections collection-id)
    collection (begin
      (asserts! (is-eq tx-sender (get owner collection)) ERR-NOT-COLLECTION-OWNER)
      (map-set collections collection-id 
        (merge collection { owner: new-owner })
      )
      (ok true)
    )
    ERR-NOT-FOUND
  )
)

```
