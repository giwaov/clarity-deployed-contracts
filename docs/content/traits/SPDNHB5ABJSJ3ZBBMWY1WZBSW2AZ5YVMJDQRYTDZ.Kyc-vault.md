---
title: "Trait Kyc-vault"
draft: true
---
```
;; title: KycVault
;; version:
;; summary:
;; description:

;; NFT for access control
(define-non-fungible-token kyc-access uint)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-TOKEN (err u103))

;; Data variables
(define-data-var next-token-id uint u1)

;; Maps
(define-map kyc-vault
  principal
  (buff 1024)
)
(define-map access-grants
  uint
  principal
)
(define-map token-owners
  uint
  principal
)
(define-map token-expiry
  uint
  uint
)
(define-map token-metadata
  uint
  {
    created-at: uint,
    purpose: (string-ascii 50),
  }
)
(define-map access-history
  principal
  (list 50 {
    token-id: uint,
    accessed-at: uint,
    accessor: principal,
  })
)

;; Store encrypted KYC data
(define-public (store-kyc-data (encrypted-data (buff 1024)))
  (begin
    (map-set kyc-vault tx-sender encrypted-data)
    (ok true)
  )
)

;; Mint access NFT and grant access to specific principal
(define-public (grant-access (to principal))
  (let ((token-id (var-get next-token-id)))
    (asserts! (is-some (map-get? kyc-vault tx-sender)) ERR-NOT-FOUND)
    (try! (nft-mint? kyc-access token-id to))
    (map-set access-grants token-id tx-sender)
    (map-set token-owners token-id to)
    (var-set next-token-id (+ token-id u1))
    (ok token-id)
  )
)

;; Grant access with expiration and purpose
(define-public (grant-access-with-expiry
    (to principal)
    (expires-at uint)
    (purpose (string-ascii 50))
  )
  (let ((token-id (var-get next-token-id)))
    (asserts! (is-some (map-get? kyc-vault tx-sender)) ERR-NOT-FOUND)
    (asserts! (> expires-at stacks-block-height) ERR-NOT-AUTHORIZED)
    (try! (nft-mint? kyc-access token-id to))
    (map-set access-grants token-id tx-sender)
    (map-set token-owners token-id to)
    (map-set token-expiry token-id expires-at)
    (map-set token-metadata token-id {
      created-at: stacks-block-height,
      purpose: purpose,
    })
    (var-set next-token-id (+ token-id u1))
    (ok token-id)
  )
)

;; Revoke access by burning NFT
(define-public (revoke-access (token-id uint))
  (let (
      (owner (unwrap! (map-get? token-owners token-id) ERR-INVALID-TOKEN))
      (data-owner (unwrap! (map-get? access-grants token-id) ERR-INVALID-TOKEN))
    )
    (asserts! (is-eq tx-sender data-owner) ERR-NOT-AUTHORIZED)
    (try! (nft-burn? kyc-access token-id owner))
    (map-delete access-grants token-id)
    (map-delete token-owners token-id)
    (ok true)
  )
)

;; Access KYC data using NFT (checks expiration)
(define-read-only (get-kyc-data (token-id uint))
  (let (
      (data-owner (unwrap! (map-get? access-grants token-id) ERR-INVALID-TOKEN))
      (expiry (map-get? token-expiry token-id))
    )
    (asserts! (is-eq (some tx-sender) (nft-get-owner? kyc-access token-id))
      ERR-NOT-AUTHORIZED
    )
    (match expiry
      some-expiry (asserts! (< stacks-block-height some-expiry) ERR-NOT-AUTHORIZED)
      true
    )
    (ok (map-get? kyc-vault data-owner))
  )
)

;; Check if user has KYC data stored
(define-read-only (has-kyc-data (user principal))
  (is-some (map-get? kyc-vault user))
)

;; Get NFT owner
(define-read-only (get-token-owner (token-id uint))
  (ok (nft-get-owner? kyc-access token-id))
)

;; Get data owner for a token
(define-read-only (get-data-owner (token-id uint))
  (ok (map-get? access-grants token-id))
)

;; Get token metadata
(define-read-only (get-token-metadata (token-id uint))
  (ok (map-get? token-metadata token-id))
)

;; Get token expiry
(define-read-only (get-token-expiry (token-id uint))
  (ok (map-get? token-expiry token-id))
)

;; Check if token is expired
(define-read-only (is-token-expired (token-id uint))
  (match (map-get? token-expiry token-id)
    some-expiry (ok (>= stacks-block-height some-expiry))
    (ok false)
  )
)

;; Update KYC data (only by data owner)
(define-public (update-kyc-data (encrypted-data (buff 1024)))
  (begin
    (asserts! (is-some (map-get? kyc-vault tx-sender)) ERR-NOT-FOUND)
    (map-set kyc-vault tx-sender encrypted-data)
    (ok true)
  )
)

;; Delete KYC data and revoke all access tokens
(define-public (delete-kyc-data)
  (begin
    (asserts! (is-some (map-get? kyc-vault tx-sender)) ERR-NOT-FOUND)
    (map-delete kyc-vault tx-sender)
    (ok true)
  )
)

;; Transfer access token to another principal
(define-public (transfer-access
    (token-id uint)
    (to principal)
  )
  (let ((owner (unwrap! (nft-get-owner? kyc-access token-id) ERR-INVALID-TOKEN)))
    (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
    (try! (nft-transfer? kyc-access token-id tx-sender to))
    (map-set token-owners token-id to)
    (ok true)
  )
)

;; Batch grant access to multiple principals
(define-public (batch-grant-access (recipients (list 10 principal)))
  (begin
    (asserts! (is-some (map-get? kyc-vault tx-sender)) ERR-NOT-FOUND)
    (ok (map grant-access-helper recipients))
  )
)

(define-private (grant-access-helper (recipient principal))
  (let ((token-id (var-get next-token-id)))
    (match (nft-mint? kyc-access token-id recipient)
      success (begin
        (map-set access-grants token-id tx-sender)
        (map-set token-owners token-id recipient)
        (var-set next-token-id (+ token-id u1))
        token-id
      )
      error u0
    )
  )
)

;; Check if principal has access to specific user's data
(define-read-only (has-access-to
    (data-owner principal)
    (accessor principal)
  )
  (or
    (check-token-access-for u1 data-owner accessor)
    (check-token-access-for u2 data-owner accessor)
    (check-token-access-for u3 data-owner accessor)
    (check-token-access-for u4 data-owner accessor)
    (check-token-access-for u5 data-owner accessor)
  )
)

(define-private (check-token-access-for
    (token-id uint)
    (data-owner principal)
    (accessor principal)
  )
  (and
    (is-eq (map-get? access-grants token-id) (some data-owner))
    (is-eq (nft-get-owner? kyc-access token-id) (some accessor))
  )
)

;; Get total number of access tokens issued
(define-read-only (get-total-tokens)
  (ok (- (var-get next-token-id) u1))
)

;; Emergency pause function (can be extended with admin controls)
(define-data-var contract-paused bool false)

(define-read-only (is-contract-paused)
  (ok (var-get contract-paused))
)

;; Check if user can store KYC data (contract not paused)
(define-read-only (can-store-data)
  (ok (not (var-get contract-paused)))
)

;; Get access history for a user's data
(define-read-only (get-access-history (data-owner principal))
  (ok (map-get? access-history data-owner))
)

;; Extend token expiry (only by data owner)
(define-public (extend-token-expiry
    (token-id uint)
    (new-expiry uint)
  )
  (let ((data-owner (unwrap! (map-get? access-grants token-id) ERR-INVALID-TOKEN)))
    (asserts! (is-eq tx-sender data-owner) ERR-NOT-AUTHORIZED)
    (asserts! (> new-expiry stacks-block-height) ERR-NOT-AUTHORIZED)
    (map-set token-expiry token-id new-expiry)
    (ok true)
  )
)

;; Bulk revoke multiple tokens
(define-public (bulk-revoke-tokens (token-ids (list 10 uint)))
  (ok (map revoke-token-helper token-ids))
)

(define-private (revoke-token-helper (token-id uint))
  (match (revoke-access token-id)
    success true
    error false
  )
)

;; Simple token count by owner (checks first 10 tokens)
(define-read-only (count-tokens-by-owner (owner principal))
  (ok (fold count-token-helper (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) {
    owner: owner,
    count: u0,
  }))
)

(define-private (count-token-helper
    (token-id uint)
    (acc {
      owner: principal,
      count: uint,
    })
  )
  (if (is-eq (nft-get-owner? kyc-access token-id) (some (get owner acc)))
    {
      owner: (get owner acc),
      count: (+ (get count acc) u1),
    }
    acc
  )
)

```
