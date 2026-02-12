(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-insufficient-balance (err u105))

(define-data-var payment-nonce uint u0)

(define-map service-providers
  principal
  {
    service-type: (string-ascii 40),
    revenue-share-rate: uint,
    total-earned: uint,
    total-revenue-shared: uint,
    active: bool
  }
)

(define-map micropayments
  uint
  {
    payer: principal,
    provider: principal,
    amount: uint,
    service-hash: (buff 32),
    payment-block: uint,
    revenue-distributed: bool
  }
)

(define-map revenue-shares
  {payment-id: uint, beneficiary: principal}
  {
    share-amount: uint,
    distributed: bool
  }
)

(define-map user-balances
  principal
  uint
)

(define-map provider-payments principal (list 200 uint))

(define-public (register-provider (service-type (string-ascii 40)) (revenue-share-rate uint))
  (begin
    (asserts! (is-none (map-get? service-providers tx-sender)) err-already-exists)
    (asserts! (<= revenue-share-rate u10000) err-invalid-amount)
    (map-set service-providers tx-sender
      {
        service-type: service-type,
        revenue-share-rate: revenue-share-rate,
        total-earned: u0,
        total-revenue-shared: u0,
        active: true
      }
    )
    (ok true)
  )
)

(define-public (deposit-balance (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set user-balances tx-sender
      (+ (default-to u0 (map-get? user-balances tx-sender)) amount))
    (ok true)
  )
)

(define-public (make-micropayment (provider principal) (amount uint) (service-hash (buff 32)))
  (let
    (
      (provider-info (unwrap! (map-get? service-providers provider) err-not-found))
      (user-balance (default-to u0 (map-get? user-balances tx-sender)))
      (payment-id (+ (var-get payment-nonce) u1))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= user-balance amount) err-insufficient-balance)
    (asserts! (get active provider-info) err-not-found)
    (map-set user-balances tx-sender (- user-balance amount))
    (map-set micropayments payment-id
      {
        payer: tx-sender,
        provider: provider,
        amount: amount,
        service-hash: service-hash,
        payment-block: stacks-block-height,
        revenue-distributed: false
      }
    )
    (map-set provider-payments provider
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? provider-payments provider)) payment-id) u200)))
    (var-set payment-nonce payment-id)
    (ok payment-id)
  )
)

(define-public (distribute-revenue (payment-id uint) (beneficiaries (list 10 {addr: principal, share: uint})))
  (let
    (
      (payment (unwrap! (map-get? micropayments payment-id) err-not-found))
      (provider-info (unwrap! (map-get? service-providers (get provider payment)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get provider payment)) err-unauthorized)
    (asserts! (not (get revenue-distributed payment)) err-already-exists)
    (let
      (
        (revenue-to-share (/ (* (get amount payment) (get revenue-share-rate provider-info)) u10000))
        (provider-amount (- (get amount payment) revenue-to-share))
      )
      (try! (as-contract (stx-transfer? provider-amount tx-sender (get provider payment))))
      (map distribute-to-beneficiary beneficiaries)
      (map-set micropayments payment-id (merge payment {revenue-distributed: true}))
      (map-set service-providers (get provider payment) (merge provider-info {
        total-earned: (+ (get total-earned provider-info) provider-amount),
        total-revenue-shared: (+ (get total-revenue-shared provider-info) revenue-to-share)
      }))
      (ok true)
    )
  )
)

(define-private (distribute-to-beneficiary (beneficiary {addr: principal, share: uint}))
  (begin
    (unwrap-panic (as-contract (stx-transfer? (get share beneficiary) tx-sender (get addr beneficiary))))
    true
  )
)

(define-public (withdraw-balance (amount uint))
  (let
    (
      (balance (default-to u0 (map-get? user-balances tx-sender)))
    )
    (asserts! (>= balance amount) err-insufficient-balance)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (map-set user-balances tx-sender (- balance amount))
    (ok true)
  )
)

(define-public (update-revenue-share-rate (new-rate uint))
  (let
    (
      (provider-info (unwrap! (map-get? service-providers tx-sender) err-not-found))
    )
    (asserts! (<= new-rate u10000) err-invalid-amount)
    (map-set service-providers tx-sender (merge provider-info {revenue-share-rate: new-rate}))
    (ok true)
  )
)

(define-read-only (get-provider (provider principal))
  (ok (map-get? service-providers provider))
)

(define-read-only (get-micropayment (payment-id uint))
  (ok (map-get? micropayments payment-id))
)

(define-read-only (get-user-balance (user principal))
  (ok (map-get? user-balances user))
)

(define-read-only (get-provider-payments (provider principal))
  (ok (map-get? provider-payments provider))
)
