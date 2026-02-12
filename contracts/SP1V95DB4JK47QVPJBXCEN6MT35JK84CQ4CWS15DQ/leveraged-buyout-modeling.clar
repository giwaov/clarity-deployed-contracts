(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))

(define-data-var lbo-nonce uint u0)

(define-map lbo-models
  uint
  {
    sponsor: principal,
    target-company: principal,
    purchase-price: uint,
    equity-contribution: uint,
    debt-financing: uint,
    leverage-ratio: uint,
    debt-interest-rate: uint,
    exit-multiple: uint,
    hold-period-blocks: uint,
    created-block: uint,
    exited: bool
  }
)

(define-map debt-schedules
  {lbo-id: uint, period: uint}
  {
    beginning-balance: uint,
    interest-expense: uint,
    principal-payment: uint,
    ending-balance: uint
  }
)

(define-map lbo-returns
  uint
  {
    exit-value: uint,
    debt-paydown: uint,
    equity-proceeds: uint,
    irr: uint,
    moic: uint
  }
)

(define-map sponsor-lbos principal (list 30 uint))

(define-public (create-lbo (target principal) (price uint) (equity uint) (debt uint) 
                            (leverage uint) (rate uint) (exit-mult uint) (hold-period uint))
  (let
    (
      (lbo-id (+ (var-get lbo-nonce) u1))
    )
    (asserts! (is-eq (+ equity debt) price) err-invalid-amount)
    (map-set lbo-models lbo-id {
      sponsor: tx-sender,
      target-company: target,
      purchase-price: price,
      equity-contribution: equity,
      debt-financing: debt,
      leverage-ratio: leverage,
      debt-interest-rate: rate,
      exit-multiple: exit-mult,
      hold-period-blocks: hold-period,
      created-block: stacks-block-height,
      exited: false
    })
    (map-set sponsor-lbos tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? sponsor-lbos tx-sender)) lbo-id) u30)))
    (var-set lbo-nonce lbo-id)
    (ok lbo-id)
  )
)

(define-public (add-debt-schedule (lbo-id uint) (period uint) (beginning uint) 
                                   (interest uint) (principal uint))
  (let
    (
      (lbo (unwrap! (map-get? lbo-models lbo-id) err-not-found))
      (ending (- beginning principal))
    )
    (asserts! (is-eq tx-sender (get sponsor lbo)) err-unauthorized)
    (map-set debt-schedules {lbo-id: lbo-id, period: period} {
      beginning-balance: beginning,
      interest-expense: interest,
      principal-payment: principal,
      ending-balance: ending
    })
    (ok ending)
  )
)

(define-public (execute-exit (lbo-id uint) (exit-value uint))
  (let
    (
      (lbo (unwrap! (map-get? lbo-models lbo-id) err-not-found))
      (remaining-debt (calculate-remaining-debt lbo-id))
      (equity-proceeds (- exit-value remaining-debt))
      (moic (/ (* equity-proceeds u100) (get equity-contribution lbo)))
    )
    (asserts! (is-eq tx-sender (get sponsor lbo)) err-unauthorized)
    (asserts! (not (get exited lbo)) err-not-found)
    (map-set lbo-returns lbo-id {
      exit-value: exit-value,
      debt-paydown: remaining-debt,
      equity-proceeds: equity-proceeds,
      irr: u0,
      moic: moic
    })
    (map-set lbo-models lbo-id (merge lbo {exited: true}))
    (ok equity-proceeds)
  )
)

(define-public (update-irr (lbo-id uint) (calculated-irr uint))
  (let
    (
      (lbo (unwrap! (map-get? lbo-models lbo-id) err-not-found))
      (returns (unwrap! (map-get? lbo-returns lbo-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get sponsor lbo)) err-unauthorized)
    (map-set lbo-returns lbo-id (merge returns {irr: calculated-irr}))
    (ok calculated-irr)
  )
)

(define-read-only (get-lbo (lbo-id uint))
  (ok (map-get? lbo-models lbo-id))
)

(define-read-only (get-debt-schedule (lbo-id uint) (period uint))
  (ok (map-get? debt-schedules {lbo-id: lbo-id, period: period}))
)

(define-read-only (get-returns (lbo-id uint))
  (ok (map-get? lbo-returns lbo-id))
)

(define-read-only (get-sponsor-lbos (sponsor principal))
  (ok (map-get? sponsor-lbos sponsor))
)

(define-read-only (calculate-remaining-debt (lbo-id uint))
  (let
    (
      (lbo (unwrap-panic (map-get? lbo-models lbo-id)))
      (initial-debt (get debt-financing lbo))
    )
    initial-debt
  )
)

(define-read-only (calculate-exit-value (lbo-id uint) (ebitda uint))
  (let
    (
      (lbo (unwrap-panic (map-get? lbo-models lbo-id)))
      (multiple (get exit-multiple lbo))
    )
    (/ (* ebitda multiple) u100)
  )
)

(define-read-only (calculate-leverage-ratio (lbo-id uint))
  (let
    (
      (lbo (unwrap-panic (map-get? lbo-models lbo-id)))
    )
    (ok (/ (* (get debt-financing lbo) u100) (get purchase-price lbo)))
  )
)

(define-read-only (get-lbo-metrics (lbo-id uint))
  (let
    (
      (lbo (unwrap-panic (map-get? lbo-models lbo-id)))
      (returns-data (map-get? lbo-returns lbo-id))
    )
    (ok {
      purchase-price: (get purchase-price lbo),
      equity-contribution: (get equity-contribution lbo),
      leverage-ratio: (get leverage-ratio lbo),
      exited: (get exited lbo)
    })
  )
)
