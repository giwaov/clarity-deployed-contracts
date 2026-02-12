(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u700))
(define-constant ERR_NFT_NOT_FOUND (err u701))
(define-constant ERR_INVALID_PERMISSION (err u702))

(define-non-fungible-token smart-nft uint)

(define-data-var next-nft-id uint u1)

(define-map nft-logic
  uint
  {
    logic-hash: (buff 32),
    verification-state: (string-ascii 20),
    owner: principal,
    created-at: uint
  }
)

(define-map nft-permissions
  {nft-id: uint, caller: principal}
  bool
)

(define-map intent-proxies
  uint
  principal
)

(define-read-only (get-contract-hash)
  (contract-hash? .intent-centric-nft)
)

(define-read-only (get-nft-logic (nft-id uint))
  (ok (unwrap! (map-get? nft-logic nft-id) ERR_NFT_NOT_FOUND))
)

(define-read-only (get-owner (nft-id uint))
  (ok (nft-get-owner? smart-nft nft-id))
)

(define-public (mint-smart-nft (to principal) (logic-hash (buff 32)))
  (let
    (
      (nft-id (var-get next-nft-id))
    )
    (try! (nft-mint? smart-nft nft-id to))
    (map-set nft-logic nft-id {
      logic-hash: logic-hash,
      verification-state: "Unverified",
      owner: to,
      created-at: stacks-block-time
    })
    (var-set next-nft-id (+ nft-id u1))
    (ok nft-id)
  )
)

(define-public (execute-intent (nft-id uint) (intent-data (buff 256)))
  (let
    (
      (nft-data (unwrap! (map-get? nft-logic nft-id) ERR_NFT_NOT_FOUND))
      (has-permission (default-to false (map-get? nft-permissions {nft-id: nft-id, caller: tx-sender})))
    )
    (asserts! (or (is-eq (get owner nft-data) tx-sender) has-permission) ERR_NOT_AUTHORIZED)
    (ok true)
  )
)

(define-public (validate-permission (nft-id uint) (caller principal))
  (ok (default-to false (map-get? nft-permissions {nft-id: nft-id, caller: caller})))
)

(define-public (grant-permission (nft-id uint) (caller principal))
  (let
    (
      (nft-data (unwrap! (map-get? nft-logic nft-id) ERR_NFT_NOT_FOUND))
    )
    (asserts! (is-eq (get owner nft-data) tx-sender) ERR_NOT_AUTHORIZED)
    (map-set nft-permissions {nft-id: nft-id, caller: caller} true)
    (ok true)
  )
)

(define-public (revoke-permission (nft-id uint) (caller principal))
  (let
    (
      (nft-data (unwrap! (map-get? nft-logic nft-id) ERR_NFT_NOT_FOUND))
    )
    (asserts! (is-eq (get owner nft-data) tx-sender) ERR_NOT_AUTHORIZED)
    (map-set nft-permissions {nft-id: nft-id, caller: caller} false)
    (ok true)
  )
)

(define-public (set-verification-state (nft-id uint) (state (string-ascii 20)))
  (let
    (
      (nft-data (unwrap! (map-get? nft-logic nft-id) ERR_NFT_NOT_FOUND))
    )
    (asserts! (is-eq (get owner nft-data) tx-sender) ERR_NOT_AUTHORIZED)
    (map-set nft-logic nft-id (merge nft-data {verification-state: state}))
    (ok true)
  )
)

(define-public (transfer (nft-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    (nft-transfer? smart-nft nft-id sender recipient)
  )
)

(define-read-only (verify-permission-signature (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (ok (secp256r1-verify message signature public-key))
)

(define-read-only (get-time)
  stacks-block-time
)
