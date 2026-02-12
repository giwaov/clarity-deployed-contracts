;; title: usevault
;; version:
;; summary:
;; description:


;; token definitions
(define-fungible-token sbtc-token)

;; constants
(define-constant err-not-member (err u101))
(define-constant err-proposal-not-found (err u102))
(define-constant err-voting-ended (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-already-voted (err u105))
(define-constant err-voting-not-ended (err u106))
(define-constant err-already-executed (err u107))
(define-constant err-proposal-rejected (err u108))
(define-constant err-asset-restriction-failed (err u109))
(define-constant err-invalid-signature (err u110))
(define-constant err-passkey-not-found (err u111))
(define-constant err-invalid-contract-hash (err u112))

;; Voting period: 24 hours (144 blocks * 10 minutes per block)
(define-constant voting-period-blocks u144)

;; data vars
(define-data-var proposal-nonce uint u0)
(define-data-var treasury-principal principal tx-sender)

;; data maps
(define-map dao-members principal bool)
(define-map proposals
  uint
  {
    creator: principal,
    amount: uint,
    recipient: principal,
    yes-votes: uint,
    no-votes: uint,
    end-block: uint,
    end-timestamp: uint,
    executed: bool,
    created-at: uint
  }
)
(define-map member-votes { proposal-id: uint, voter: principal } bool)

;; passkey storage for biometric authentication (Clarity 4)
(define-map member-passkeys principal (buff 33))

;; trusted contracts registry (Clarity 4)
(define-map trusted-contracts principal bool)

;; read-only functions (defined before use)
(define-read-only (is-member (user principal))
  (default-to false (map-get? dao-members user))
)

;; public functions
(define-public (join-dao)
  (begin
    (map-set dao-members tx-sender true)
    (ok true)
  )
)

;; Join DAO with passkey (secp256r1-verify - Clarity 4)
(define-public (join-dao-with-passkey (public-key (buff 33)) (message-hash (buff 32)) (signature (buff 64)))
  (begin
    (asserts! (secp256r1-verify message-hash signature public-key) err-invalid-signature)
    (map-set dao-members tx-sender true)
    (map-set member-passkeys tx-sender public-key)
    (ok true)
  )
)

;; Vote with passkey authentication (secp256r1-verify - Clarity 4)
(define-public (vote-with-passkey (proposal-id uint) (vote-yes bool) (message-hash (buff 32)) (signature (buff 64)))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
    (passkey (unwrap! (map-get? member-passkeys tx-sender) err-passkey-not-found))
  )
    (asserts! (secp256r1-verify message-hash signature passkey) err-invalid-signature)
    (asserts! (is-member tx-sender) err-not-member)
    (asserts! (< stacks-block-time (get end-timestamp proposal)) err-voting-ended)
    (asserts! (is-none (map-get? member-votes { proposal-id: proposal-id, voter: tx-sender })) err-already-voted)

    (map-set member-votes { proposal-id: proposal-id, voter: tx-sender } true)

    (if vote-yes
      (map-set proposals proposal-id (merge proposal { yes-votes: (+ (get yes-votes proposal) u1) }))
      (map-set proposals proposal-id (merge proposal { no-votes: (+ (get no-votes proposal) u1) }))
    )
    (ok true)
  )
)
