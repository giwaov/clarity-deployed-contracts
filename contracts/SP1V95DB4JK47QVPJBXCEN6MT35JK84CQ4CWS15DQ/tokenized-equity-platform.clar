(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-transfer-restricted (err u105))

(define-data-var token-nonce uint u0)

(define-map tokenized-equity
  uint
  {
    issuer: principal,
    company-name: (string-ascii 50),
    token-symbol: (string-ascii 10),
    total-supply: uint,
    price-per-token: uint,
    tokens-sold: uint,
    verified: bool,
    tradable: bool,
    kyc-required: bool
  }
)

(define-map equity-balances
  {token-id: uint, holder: principal}
  {
    balance: uint,
    kyc-verified: bool,
    purchase-block: uint
  }
)

(define-map equity-transfers
  {token-id: uint, transfer-id: uint}
  {
    from: principal,
    to: principal,
    amount: uint,
    transfer-block: uint,
    approved: bool
  }
)

(define-map issuer-tokens principal (list 50 uint))
(define-map transfer-count uint uint)

(define-public (issue-equity (company-name (string-ascii 50)) (token-symbol (string-ascii 10)) (total-supply uint) (price-per-token uint) (kyc-required bool))
  (let
    (
      (token-id (+ (var-get token-nonce) u1))
    )
    (asserts! (> total-supply u0) err-invalid-amount)
    (asserts! (> price-per-token u0) err-invalid-amount)
    (map-set tokenized-equity token-id
      {
        issuer: tx-sender,
        company-name: company-name,
        token-symbol: token-symbol,
        total-supply: total-supply,
        price-per-token: price-per-token,
        tokens-sold: u0,
        verified: false,
        tradable: false,
        kyc-required: kyc-required
      }
    )
    (map-set equity-balances {token-id: token-id, holder: tx-sender}
      {
        balance: total-supply,
        kyc-verified: true,
        purchase-block: stacks-block-height
      }
    )
    (map-set transfer-count token-id u0)
    (map-set issuer-tokens tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? issuer-tokens tx-sender)) token-id) u50)))
    (var-set token-nonce token-id)
    (ok token-id)
  )
)

(define-public (purchase-equity (token-id uint) (amount uint))
  (let
    (
      (equity (unwrap! (map-get? tokenized-equity token-id) err-not-found))
      (issuer-balance (unwrap! (map-get? equity-balances {token-id: token-id, holder: (get issuer equity)}) err-not-found))
      (buyer-balance (default-to {balance: u0, kyc-verified: false, purchase-block: u0} (map-get? equity-balances {token-id: token-id, holder: tx-sender})))
      (total-cost (* amount (get price-per-token equity)))
    )
    (asserts! (get verified equity) err-not-found)
    (asserts! (get tradable equity) err-transfer-restricted)
    (asserts! (>= (get balance issuer-balance) amount) err-invalid-amount)
    (asserts! (or (not (get kyc-required equity)) (get kyc-verified buyer-balance)) err-unauthorized)
    (try! (stx-transfer? total-cost tx-sender (get issuer equity)))
    (map-set equity-balances {token-id: token-id, holder: (get issuer equity)}
      (merge issuer-balance {balance: (- (get balance issuer-balance) amount)}))
    (map-set equity-balances {token-id: token-id, holder: tx-sender}
      (merge buyer-balance {
        balance: (+ (get balance buyer-balance) amount),
        purchase-block: stacks-block-height
      }))
    (map-set tokenized-equity token-id (merge equity {
      tokens-sold: (+ (get tokens-sold equity) amount)
    }))
    (ok true)
  )
)

(define-public (transfer-equity (token-id uint) (recipient principal) (amount uint))
  (let
    (
      (equity (unwrap! (map-get? tokenized-equity token-id) err-not-found))
      (sender-balance (unwrap! (map-get? equity-balances {token-id: token-id, holder: tx-sender}) err-not-found))
      (recipient-balance (default-to {balance: u0, kyc-verified: false, purchase-block: u0} (map-get? equity-balances {token-id: token-id, holder: recipient})))
      (transfer-id (+ (default-to u0 (map-get? transfer-count token-id)) u1))
    )
    (asserts! (get tradable equity) err-transfer-restricted)
    (asserts! (>= (get balance sender-balance) amount) err-invalid-amount)
    (asserts! (or (not (get kyc-required equity)) (get kyc-verified recipient-balance)) err-unauthorized)
    (map-set equity-balances {token-id: token-id, holder: tx-sender}
      (merge sender-balance {balance: (- (get balance sender-balance) amount)}))
    (map-set equity-balances {token-id: token-id, holder: recipient}
      (merge recipient-balance {balance: (+ (get balance recipient-balance) amount)}))
    (map-set equity-transfers {token-id: token-id, transfer-id: transfer-id}
      {
        from: tx-sender,
        to: recipient,
        amount: amount,
        transfer-block: stacks-block-height,
        approved: true
      }
    )
    (map-set transfer-count token-id transfer-id)
    (ok true)
  )
)

(define-public (verify-equity (token-id uint))
  (let
    (
      (equity (unwrap! (map-get? tokenized-equity token-id) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set tokenized-equity token-id (merge equity {verified: true}))
    (ok true)
  )
)

(define-public (enable-trading (token-id uint))
  (let
    (
      (equity (unwrap! (map-get? tokenized-equity token-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get issuer equity)) err-unauthorized)
    (asserts! (get verified equity) err-not-found)
    (map-set tokenized-equity token-id (merge equity {tradable: true}))
    (ok true)
  )
)

(define-public (verify-kyc (token-id uint) (holder principal))
  (let
    (
      (equity (unwrap! (map-get? tokenized-equity token-id) err-not-found))
      (balance (default-to {balance: u0, kyc-verified: false, purchase-block: u0} (map-get? equity-balances {token-id: token-id, holder: holder})))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set equity-balances {token-id: token-id, holder: holder}
      (merge balance {kyc-verified: true}))
    (ok true)
  )
)

(define-read-only (get-equity (token-id uint))
  (ok (map-get? tokenized-equity token-id))
)

(define-read-only (get-balance (token-id uint) (holder principal))
  (ok (map-get? equity-balances {token-id: token-id, holder: holder}))
)

(define-read-only (get-transfer (token-id uint) (transfer-id uint))
  (ok (map-get? equity-transfers {token-id: token-id, transfer-id: transfer-id}))
)

(define-read-only (get-issuer-tokens (issuer principal))
  (ok (map-get? issuer-tokens issuer))
)
