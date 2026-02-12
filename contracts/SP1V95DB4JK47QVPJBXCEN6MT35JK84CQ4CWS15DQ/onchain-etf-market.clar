(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-fund-inactive (err u105))

(define-data-var etf-nonce uint u0)

(define-map etf-funds
  uint
  {
    fund-manager: principal,
    fund-name: (string-ascii 50),
    fund-symbol: (string-ascii 10),
    total-shares: uint,
    nav-per-share: uint,
    management-fee: uint,
    active: bool,
    total-aum: uint
  }
)

(define-map fund-holdings
  {fund-id: uint, asset-id: uint}
  {
    asset-symbol: (string-ascii 10),
    quantity: uint,
    value: uint,
    weight-percentage: uint
  }
)

(define-map shareholder-positions
  {fund-id: uint, shareholder: principal}
  {
    shares-owned: uint,
    cost-basis: uint,
    purchase-block: uint
  }
)

(define-map manager-funds principal (list 20 uint))
(define-map fund-shareholders uint (list 500 principal))

(define-public (create-etf (fund-name (string-ascii 50)) (fund-symbol (string-ascii 10)) (initial-shares uint) (nav-per-share uint) (management-fee uint))
  (let
    (
      (fund-id (+ (var-get etf-nonce) u1))
    )
    (asserts! (> initial-shares u0) err-invalid-amount)
    (asserts! (> nav-per-share u0) err-invalid-amount)
    (asserts! (<= management-fee u1000) err-invalid-amount)
    (map-set etf-funds fund-id
      {
        fund-manager: tx-sender,
        fund-name: fund-name,
        fund-symbol: fund-symbol,
        total-shares: initial-shares,
        nav-per-share: nav-per-share,
        management-fee: management-fee,
        active: true,
        total-aum: (* initial-shares nav-per-share)
      }
    )
    (map-set shareholder-positions {fund-id: fund-id, shareholder: tx-sender}
      {
        shares-owned: initial-shares,
        cost-basis: nav-per-share,
        purchase-block: stacks-block-height
      }
    )
    (map-set manager-funds tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? manager-funds tx-sender)) fund-id) u20)))
    (var-set etf-nonce fund-id)
    (ok fund-id)
  )
)

(define-public (purchase-etf-shares (fund-id uint) (shares uint))
  (let
    (
      (fund (unwrap! (map-get? etf-funds fund-id) err-not-found))
      (position (default-to {shares-owned: u0, cost-basis: u0, purchase-block: u0} (map-get? shareholder-positions {fund-id: fund-id, shareholder: tx-sender})))
      (total-cost (* shares (get nav-per-share fund)))
    )
    (asserts! (get active fund) err-fund-inactive)
    (asserts! (> shares u0) err-invalid-amount)
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    (map-set shareholder-positions {fund-id: fund-id, shareholder: tx-sender}
      {
        shares-owned: (+ (get shares-owned position) shares),
        cost-basis: (get nav-per-share fund),
        purchase-block: stacks-block-height
      }
    )
    (map-set etf-funds fund-id (merge fund {
      total-shares: (+ (get total-shares fund) shares),
      total-aum: (+ (get total-aum fund) total-cost)
    }))
    (ok true)
  )
)

(define-public (redeem-etf-shares (fund-id uint) (shares uint))
  (let
    (
      (fund (unwrap! (map-get? etf-funds fund-id) err-not-found))
      (position (unwrap! (map-get? shareholder-positions {fund-id: fund-id, shareholder: tx-sender}) err-not-found))
      (redemption-value (* shares (get nav-per-share fund)))
    )
    (asserts! (get active fund) err-fund-inactive)
    (asserts! (>= (get shares-owned position) shares) err-invalid-amount)
    (try! (as-contract (stx-transfer? redemption-value tx-sender tx-sender)))
    (map-set shareholder-positions {fund-id: fund-id, shareholder: tx-sender}
      (merge position {shares-owned: (- (get shares-owned position) shares)}))
    (map-set etf-funds fund-id (merge fund {
      total-shares: (- (get total-shares fund) shares),
      total-aum: (- (get total-aum fund) redemption-value)
    }))
    (ok redemption-value)
  )
)

(define-public (add-fund-holding (fund-id uint) (asset-id uint) (asset-symbol (string-ascii 10)) (quantity uint) (value uint))
  (let
    (
      (fund (unwrap! (map-get? etf-funds fund-id) err-not-found))
      (weight-pct (if (> (get total-aum fund) u0) (/ (* value u10000) (get total-aum fund)) u0))
    )
    (asserts! (is-eq tx-sender (get fund-manager fund)) err-unauthorized)
    (map-set fund-holdings {fund-id: fund-id, asset-id: asset-id}
      {
        asset-symbol: asset-symbol,
        quantity: quantity,
        value: value,
        weight-percentage: weight-pct
      }
    )
    (ok true)
  )
)

(define-public (update-nav (fund-id uint) (new-nav uint))
  (let
    (
      (fund (unwrap! (map-get? etf-funds fund-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get fund-manager fund)) err-unauthorized)
    (asserts! (> new-nav u0) err-invalid-amount)
    (map-set etf-funds fund-id (merge fund {
      nav-per-share: new-nav,
      total-aum: (* (get total-shares fund) new-nav)
    }))
    (ok true)
  )
)

(define-public (collect-management-fee (fund-id uint))
  (let
    (
      (fund (unwrap! (map-get? etf-funds fund-id) err-not-found))
      (fee-amount (/ (* (get total-aum fund) (get management-fee fund)) u10000))
    )
    (asserts! (is-eq tx-sender (get fund-manager fund)) err-unauthorized)
    (try! (as-contract (stx-transfer? fee-amount tx-sender (get fund-manager fund))))
    (ok fee-amount)
  )
)

(define-public (deactivate-fund (fund-id uint))
  (let
    (
      (fund (unwrap! (map-get? etf-funds fund-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get fund-manager fund)) err-unauthorized)
    (map-set etf-funds fund-id (merge fund {active: false}))
    (ok true)
  )
)

(define-read-only (get-etf-fund (fund-id uint))
  (ok (map-get? etf-funds fund-id))
)

(define-read-only (get-fund-holding (fund-id uint) (asset-id uint))
  (ok (map-get? fund-holdings {fund-id: fund-id, asset-id: asset-id}))
)

(define-read-only (get-shareholder-position (fund-id uint) (shareholder principal))
  (ok (map-get? shareholder-positions {fund-id: fund-id, shareholder: shareholder}))
)

(define-read-only (get-manager-funds (manager principal))
  (ok (map-get? manager-funds manager))
)
