(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1400))
(define-constant ERR_NFT_NOT_FOUND (err u1401))
(define-constant ERR_INSUFFICIENT_FRACTIONAL (err u1402))

(define-non-fungible-token fractional-nft uint)
(define-fungible-token fractional-token)

(define-data-var next-nft-id uint u1)
(define-data-var reserve-ratio uint u100)

(define-map nft-metadata
  uint
  {
    owner: principal,
    total-fractional: uint,
    created-at: uint
  }
)

(define-map segregated-accounts
  principal
  {fractional-balance: uint, nft-held: (optional uint)}
)

(define-read-only (get-contract-hash)
  (contract-hash? .fractional-nft)
)

(define-read-only (get-nft-owner (nft-id uint))
  (ok (nft-get-owner? fractional-nft nft-id))
)

(define-read-only (get-fractional-balance (account principal))
  (ok (ft-get-balance fractional-token account))
)

(define-read-only (balance-of-fractional (account principal))
  (let
    (
      (account-data (default-to {fractional-balance: u0, nft-held: none} (map-get? segregated-accounts account)))
    )
    (ok (get fractional-balance account-data))
  )
)

(define-public (mint-nft (to principal))
  (let
    (
      (nft-id (var-get next-nft-id))
    )
    (try! (nft-mint? fractional-nft nft-id to))
    (map-set nft-metadata nft-id {
      owner: to,
      total-fractional: u0,
      created-at: stacks-block-time
    })
    (var-set next-nft-id (+ nft-id u1))
    (ok nft-id)
  )
)

(define-public (fractional-reserve-mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (try! (ft-mint? fractional-token amount recipient))
    (let
      (
        (account-data (default-to {fractional-balance: u0, nft-held: none} (map-get? segregated-accounts recipient)))
      )
      (map-set segregated-accounts recipient (merge account-data {
        fractional-balance: (+ (get fractional-balance account-data) amount)
      }))
    )
    (ok true)
  )
)

(define-public (fractional-reserve-burn (amount uint))
  (let
    (
      (account-data (default-to {fractional-balance: u0, nft-held: none} (map-get? segregated-accounts tx-sender)))
    )
    (asserts! (>= (get fractional-balance account-data) amount) ERR_INSUFFICIENT_FRACTIONAL)
    (try! (ft-burn? fractional-token amount tx-sender))
    (map-set segregated-accounts tx-sender (merge account-data {
      fractional-balance: (- (get fractional-balance account-data) amount)
    }))
    (ok true)
  )
)

(define-public (deposit-nft-for-fractional (nft-id uint) (fractional-amount uint))
  (let
    (
      (nft-data (unwrap! (map-get? nft-metadata nft-id) ERR_NFT_NOT_FOUND))
      (account-data (default-to {fractional-balance: u0, nft-held: none} (map-get? segregated-accounts tx-sender)))
    )
    (asserts! (is-eq (get owner nft-data) tx-sender) ERR_NOT_AUTHORIZED)
    (try! (nft-transfer? fractional-nft nft-id tx-sender CONTRACT_OWNER))
    (try! (ft-mint? fractional-token fractional-amount tx-sender))
    (map-set segregated-accounts tx-sender (merge account-data {
      fractional-balance: (+ (get fractional-balance account-data) fractional-amount),
      nft-held: (some nft-id)
    }))
    (ok true)
  )
)

(define-public (withdraw-nft-for-fractional (nft-id uint) (fractional-amount uint))
  (let
    (
      (account-data (unwrap! (map-get? segregated-accounts tx-sender) ERR_NOT_AUTHORIZED))
    )
    (asserts! (is-eq (get nft-held account-data) (some nft-id)) ERR_NOT_AUTHORIZED)
    (asserts! (>= (get fractional-balance account-data) fractional-amount) ERR_INSUFFICIENT_FRACTIONAL)
    (try! (ft-burn? fractional-token fractional-amount tx-sender))
    (try! (nft-transfer? fractional-nft nft-id CONTRACT_OWNER tx-sender))
    (map-set segregated-accounts tx-sender (merge account-data {
      fractional-balance: (- (get fractional-balance account-data) fractional-amount),
      nft-held: none
    }))
    (ok true)
  )
)

(define-read-only (verify-r1-signature (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (ok (secp256r1-verify message signature public-key))
)

(define-read-only (get-timestamp)
  stacks-block-time
)

(define-read-only (check-asset-restrictions)
  (ok (is-ok (contract-hash? .fractional-nft)))
)
