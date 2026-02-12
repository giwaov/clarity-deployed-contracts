(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))

(define-data-var valuation-nonce uint u0)

(define-map valuations
  uint
  {
    analyst: principal,
    entity: principal,
    discount-rate: uint,
    growth-rate: uint,
    terminal-growth: uint,
    projection-years: uint,
    enterprise-value: uint,
    equity-value: uint,
    debt-value: uint,
    cash-value: uint,
    created-block: uint
  }
)

(define-map cash-flows
  {valuation-id: uint, year: uint}
  {
    projected-fcf: uint,
    discount-factor: uint,
    present-value: uint
  }
)

(define-map analyst-valuations principal (list 50 uint))

(define-public (create-valuation (entity principal) (discount uint) (growth uint) (terminal uint) 
                                  (years uint) (debt uint) (cash uint))
  (let
    (
      (valuation-id (+ (var-get valuation-nonce) u1))
    )
    (asserts! (> years u0) err-invalid-amount)
    (map-set valuations valuation-id {
      analyst: tx-sender,
      entity: entity,
      discount-rate: discount,
      growth-rate: growth,
      terminal-growth: terminal,
      projection-years: years,
      enterprise-value: u0,
      equity-value: u0,
      debt-value: debt,
      cash-value: cash,
      created-block: stacks-block-height
    })
    (map-set analyst-valuations tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? analyst-valuations tx-sender)) valuation-id) u50)))
    (var-set valuation-nonce valuation-id)
    (ok valuation-id)
  )
)

(define-public (add-cash-flow (valuation-id uint) (year uint) (fcf uint))
  (let
    (
      (valuation (unwrap! (map-get? valuations valuation-id) err-not-found))
      (discount-factor (calculate-discount-factor valuation-id year))
      (pv (/ (* fcf u100) discount-factor))
    )
    (asserts! (is-eq tx-sender (get analyst valuation)) err-unauthorized)
    (asserts! (<= year (get projection-years valuation)) err-invalid-amount)
    (map-set cash-flows {valuation-id: valuation-id, year: year} {
      projected-fcf: fcf,
      discount-factor: discount-factor,
      present-value: pv
    })
    (ok pv)
  )
)

(define-public (calculate-enterprise-value (valuation-id uint))
  (let
    (
      (valuation (unwrap! (map-get? valuations valuation-id) err-not-found))
      (terminal (calculate-terminal-value valuation-id))
      (pv-fcf (sum-present-values valuation-id))
      (ev (+ pv-fcf terminal))
    )
    (asserts! (is-eq tx-sender (get analyst valuation)) err-unauthorized)
    (map-set valuations valuation-id (merge valuation {enterprise-value: ev}))
    (ok ev)
  )
)

(define-public (calculate-equity-value (valuation-id uint))
  (let
    (
      (valuation (unwrap! (map-get? valuations valuation-id) err-not-found))
      (ev (get enterprise-value valuation))
      (debt (get debt-value valuation))
      (cash (get cash-value valuation))
      (equity (+ (- ev debt) cash))
    )
    (asserts! (is-eq tx-sender (get analyst valuation)) err-unauthorized)
    (map-set valuations valuation-id (merge valuation {equity-value: equity}))
    (ok equity)
  )
)

(define-read-only (get-valuation (valuation-id uint))
  (ok (map-get? valuations valuation-id))
)

(define-read-only (get-cash-flow (valuation-id uint) (year uint))
  (ok (map-get? cash-flows {valuation-id: valuation-id, year: year}))
)

(define-read-only (get-analyst-valuations (analyst principal))
  (ok (map-get? analyst-valuations analyst))
)

(define-read-only (calculate-discount-factor (valuation-id uint) (year uint))
  (let
    (
      (valuation (unwrap-panic (map-get? valuations valuation-id)))
      (rate (get discount-rate valuation))
      (factor (+ u100 (/ rate u100)))
    )
    (pow factor year)
  )
)

(define-read-only (calculate-terminal-value (valuation-id uint))
  (let
    (
      (valuation (unwrap-panic (map-get? valuations valuation-id)))
      (years (get projection-years valuation))
      (last-fcf-data (unwrap-panic (map-get? cash-flows {valuation-id: valuation-id, year: years})))
      (last-fcf (get projected-fcf last-fcf-data))
      (terminal-growth (get terminal-growth valuation))
      (discount (get discount-rate valuation))
      (terminal-fcf (/ (* last-fcf (+ u100 terminal-growth)) u100))
    )
    (/ terminal-fcf (- discount terminal-growth))
  )
)

(define-read-only (sum-present-values (valuation-id uint))
  (let
    (
      (valuation (unwrap-panic (map-get? valuations valuation-id)))
      (years (get projection-years valuation))
    )
    (fold + (map get-pv-for-year (list u1 u2 u3 u4 u5)) u0)
  )
)

(define-private (get-pv-for-year (year uint))
  u0
)

(define-read-only (get-valuation-metrics (valuation-id uint))
  (let
    (
      (valuation (unwrap-panic (map-get? valuations valuation-id)))
    )
    (ok {
      enterprise-value: (get enterprise-value valuation),
      equity-value: (get equity-value valuation),
      discount-rate: (get discount-rate valuation),
      growth-rate: (get growth-rate valuation)
    })
  )
)
