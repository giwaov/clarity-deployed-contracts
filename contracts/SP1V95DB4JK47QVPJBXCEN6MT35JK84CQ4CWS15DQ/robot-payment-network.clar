(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-insufficient-balance (err u105))
(define-constant err-payment-failed (err u106))

(define-data-var payment-nonce uint u0)

(define-map robot-wallets
  principal
  {
    robot-id: uint,
    balance: uint,
    total-sent: uint,
    total-received: uint,
    escrow-locked: uint
  }
)

(define-map payments
  uint
  {
    sender: principal,
    receiver: principal,
    amount: uint,
    service-type: (string-ascii 40),
    payment-block: uint,
    status: (string-ascii 20),
    escrow-release-block: (optional uint)
  }
)

(define-map escrow-payments
  uint
  {
    payer: principal,
    payee: principal,
    amount: uint,
    release-condition-hash: (buff 32),
    released: bool,
    refunded: bool
  }
)

(define-map wallet-payments principal (list 200 uint))

(define-public (initialize-wallet (robot-id uint))
  (begin
    (asserts! (is-none (map-get? robot-wallets tx-sender)) err-already-exists)
    (map-set robot-wallets tx-sender
      {
        robot-id: robot-id,
        balance: u0,
        total-sent: u0,
        total-received: u0,
        escrow-locked: u0
      }
    )
    (ok true)
  )
)

(define-public (deposit-funds (amount uint))
  (let
    (
      (wallet (unwrap! (map-get? robot-wallets tx-sender) err-not-found))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set robot-wallets tx-sender (merge wallet {
      balance: (+ (get balance wallet) amount)
    }))
    (ok true)
  )
)

(define-public (send-payment (receiver principal) (amount uint) (service-type (string-ascii 40)))
  (let
    (
      (sender-wallet (unwrap! (map-get? robot-wallets tx-sender) err-not-found))
      (receiver-wallet (unwrap! (map-get? robot-wallets receiver) err-not-found))
      (payment-id (+ (var-get payment-nonce) u1))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= (get balance sender-wallet) amount) err-insufficient-balance)
    (map-set robot-wallets tx-sender (merge sender-wallet {
      balance: (- (get balance sender-wallet) amount),
      total-sent: (+ (get total-sent sender-wallet) amount)
    }))
    (map-set robot-wallets receiver (merge receiver-wallet {
      balance: (+ (get balance receiver-wallet) amount),
      total-received: (+ (get total-received receiver-wallet) amount)
    }))
    (map-set payments payment-id
      {
        sender: tx-sender,
        receiver: receiver,
        amount: amount,
        service-type: service-type,
        payment-block: stacks-block-height,
        status: "completed",
        escrow-release-block: none
      }
    )
    (map-set wallet-payments tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? wallet-payments tx-sender)) payment-id) u200)))
    (var-set payment-nonce payment-id)
    (ok payment-id)
  )
)

(define-public (create-escrow-payment (payee principal) (amount uint) (release-condition-hash (buff 32)))
  (let
    (
      (wallet (unwrap! (map-get? robot-wallets tx-sender) err-not-found))
      (payment-id (+ (var-get payment-nonce) u1))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= (get balance wallet) amount) err-insufficient-balance)
    (map-set robot-wallets tx-sender (merge wallet {
      balance: (- (get balance wallet) amount),
      escrow-locked: (+ (get escrow-locked wallet) amount)
    }))
    (map-set escrow-payments payment-id
      {
        payer: tx-sender,
        payee: payee,
        amount: amount,
        release-condition-hash: release-condition-hash,
        released: false,
        refunded: false
      }
    )
    (var-set payment-nonce payment-id)
    (ok payment-id)
  )
)

(define-public (release-escrow (payment-id uint))
  (let
    (
      (escrow (unwrap! (map-get? escrow-payments payment-id) err-not-found))
      (payer-wallet (unwrap! (map-get? robot-wallets (get payer escrow)) err-not-found))
      (payee-wallet (unwrap! (map-get? robot-wallets (get payee escrow)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get payer escrow)) err-unauthorized)
    (asserts! (not (get released escrow)) err-already-exists)
    (asserts! (not (get refunded escrow)) err-already-exists)
    (map-set robot-wallets (get payee escrow) (merge payee-wallet {
      balance: (+ (get balance payee-wallet) (get amount escrow)),
      total-received: (+ (get total-received payee-wallet) (get amount escrow))
    }))
    (map-set robot-wallets (get payer escrow) (merge payer-wallet {
      escrow-locked: (- (get escrow-locked payer-wallet) (get amount escrow)),
      total-sent: (+ (get total-sent payer-wallet) (get amount escrow))
    }))
    (map-set escrow-payments payment-id (merge escrow {released: true}))
    (ok true)
  )
)

(define-public (refund-escrow (payment-id uint))
  (let
    (
      (escrow (unwrap! (map-get? escrow-payments payment-id) err-not-found))
      (payer-wallet (unwrap! (map-get? robot-wallets (get payer escrow)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get payee escrow)) err-unauthorized)
    (asserts! (not (get released escrow)) err-already-exists)
    (asserts! (not (get refunded escrow)) err-already-exists)
    (map-set robot-wallets (get payer escrow) (merge payer-wallet {
      balance: (+ (get balance payer-wallet) (get amount escrow)),
      escrow-locked: (- (get escrow-locked payer-wallet) (get amount escrow))
    }))
    (map-set escrow-payments payment-id (merge escrow {refunded: true}))
    (ok true)
  )
)

(define-public (withdraw-funds (amount uint))
  (let
    (
      (wallet (unwrap! (map-get? robot-wallets tx-sender) err-not-found))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= (get balance wallet) amount) err-insufficient-balance)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (map-set robot-wallets tx-sender (merge wallet {
      balance: (- (get balance wallet) amount)
    }))
    (ok true)
  )
)

(define-read-only (get-wallet (owner principal))
  (ok (map-get? robot-wallets owner))
)

(define-read-only (get-payment (payment-id uint))
  (ok (map-get? payments payment-id))
)

(define-read-only (get-escrow-payment (payment-id uint))
  (ok (map-get? escrow-payments payment-id))
)

(define-read-only (get-wallet-payments (owner principal))
  (ok (map-get? wallet-payments owner))
)
