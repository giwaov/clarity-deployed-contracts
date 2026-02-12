(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1100))
(define-constant ERR_SWAP_NOT_FOUND (err u1101))
(define-constant ERR_INVALID_KEY (err u1102))

(define-data-var next-swap-id uint u1)

(define-map dvp-swaps
  uint
  {
    initiator: principal,
    counterparty: principal,
    asset-amount: uint,
    payment-amount: uint,
    encrypted-key: (buff 256),
    decryption-condition: (buff 256),
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-map swap-locks
  uint
  {
    asset-locked: bool,
    payment-locked: bool,
    asset-hash: (buff 32),
    payment-hash: (buff 32)
  }
)

(define-map oracle-attestations
  {swap-id: uint, oracle: principal}
  {
    condition-met: bool,
    attestation-time: uint,
    signature: (buff 65)
  }
)

(define-read-only (get-contract-hash)
  (contract-hash? .conditional-decryption)
)

(define-read-only (get-swap (swap-id uint))
  (ok (unwrap! (map-get? dvp-swaps swap-id) ERR_SWAP_NOT_FOUND))
)

(define-read-only (get-lock-status (swap-id uint))
  (ok (map-get? swap-locks swap-id))
)

(define-public (initiate-swap 
  (counterparty principal)
  (asset-amount uint)
  (payment-amount uint)
  (encrypted-key (buff 256))
  (decryption-condition (buff 256))
)
  (let
    (
      (swap-id (var-get next-swap-id))
    )
    (map-set dvp-swaps swap-id {
      initiator: tx-sender,
      counterparty: counterparty,
      asset-amount: asset-amount,
      payment-amount: payment-amount,
      encrypted-key: encrypted-key,
      decryption-condition: decryption-condition,
      status: "Initiated",
      created-at: stacks-block-time
    })
    (map-set swap-locks swap-id {
      asset-locked: false,
      payment-locked: false,
      asset-hash: 0x,
      payment-hash: 0x
    })
    (var-set next-swap-id (+ swap-id u1))
    (ok swap-id)
  )
)

(define-public (lock-asset (swap-id uint) (asset-hash (buff 32)))
  (let
    (
      (swap-data (unwrap! (map-get? dvp-swaps swap-id) ERR_SWAP_NOT_FOUND))
      (lock-data (unwrap! (map-get? swap-locks swap-id) ERR_SWAP_NOT_FOUND))
    )
    (asserts! (is-eq (get initiator swap-data) tx-sender) ERR_NOT_AUTHORIZED)
    (map-set swap-locks swap-id (merge lock-data {
      asset-locked: true,
      asset-hash: asset-hash
    }))
    (ok true)
  )
)

(define-public (lock-payment (swap-id uint) (payment-hash (buff 32)))
  (let
    (
      (swap-data (unwrap! (map-get? dvp-swaps swap-id) ERR_SWAP_NOT_FOUND))
      (lock-data (unwrap! (map-get? swap-locks swap-id) ERR_SWAP_NOT_FOUND))
    )
    (asserts! (is-eq (get counterparty swap-data) tx-sender) ERR_NOT_AUTHORIZED)
    (map-set swap-locks swap-id (merge lock-data {
      payment-locked: true,
      payment-hash: payment-hash
    }))
    (ok true)
  )
)

(define-public (oracle-attest 
  (swap-id uint)
  (condition-met bool)
  (signature (buff 65))
)
  (begin
    (map-set oracle-attestations 
      {swap-id: swap-id, oracle: tx-sender}
      {
        condition-met: condition-met,
        attestation-time: stacks-block-time,
        signature: signature
      }
    )
    (if condition-met
      (let
        (
          (swap-data (unwrap! (map-get? dvp-swaps swap-id) ERR_SWAP_NOT_FOUND))
        )
        (map-set dvp-swaps swap-id (merge swap-data {status: "Completed"}))
        (ok true)
      )
      (ok false)
    )
  )
)

(define-public (execute-swap (swap-id uint) (decryption-key (buff 256)))
  (let
    (
      (swap-data (unwrap! (map-get? dvp-swaps swap-id) ERR_SWAP_NOT_FOUND))
      (lock-data (unwrap! (map-get? swap-locks swap-id) ERR_SWAP_NOT_FOUND))
    )
    (asserts! (get asset-locked lock-data) ERR_NOT_AUTHORIZED)
    (asserts! (get payment-locked lock-data) ERR_NOT_AUTHORIZED)
    (map-set dvp-swaps swap-id (merge swap-data {status: "Executed"}))
    (ok true)
  )
)

(define-read-only (verify-signature-r1 (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (ok (secp256r1-verify message signature public-key))
)

(define-read-only (get-timestamp)
  stacks-block-time
)

(define-read-only (check-restrictions)
  (ok (is-ok (contract-hash? .conditional-decryption)))
)
