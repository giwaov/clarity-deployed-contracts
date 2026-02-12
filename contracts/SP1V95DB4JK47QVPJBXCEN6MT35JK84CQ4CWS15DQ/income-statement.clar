(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-STATEMENT-NOT-FOUND (err u101))
(define-constant ERR-INVALID-PERIOD (err u102))

(define-map income-statements
  { company: principal, period: uint }
  {
    revenue: uint,
    cost-of-goods-sold: uint,
    gross-profit: uint,
    operating-expenses: uint,
    operating-income: uint,
    interest-expense: uint,
    tax-expense: uint,
    net-income: uint,
    submitted-at: uint,
    submitted-by: principal
  }
)

(define-map company-owners principal principal)

(define-public (register-company (owner principal))
  (ok (map-set company-owners tx-sender owner))
)

(define-public (submit-statement
  (company principal)
  (period uint)
  (revenue uint)
  (cogs uint)
  (opex uint)
  (interest uint)
  (tax uint)
)
  (let (
    (gross-profit (- revenue cogs))
    (operating-income (- gross-profit opex))
    (ebt (- operating-income interest))
    (net-income (- ebt tax))
  )
    (asserts! (is-eq (some tx-sender) (map-get? company-owners company)) ERR-NOT-AUTHORIZED)
    (ok (map-set income-statements
      { company: company, period: period }
      {
        revenue: revenue,
        cost-of-goods-sold: cogs,
        gross-profit: gross-profit,
        operating-expenses: opex,
        operating-income: operating-income,
        interest-expense: interest,
        tax-expense: tax,
        net-income: net-income,
        submitted-at: stacks-block-height,
        submitted-by: tx-sender
      }
    ))
  )
)

(define-read-only (get-statement (company principal) (period uint))
  (map-get? income-statements { company: company, period: period })
)

(define-read-only (get-company-owner (company principal))
  (map-get? company-owners company)
)

(define-public (update-revenue (company principal) (period uint) (new-amount uint))
  (let ((statement (unwrap! (map-get? income-statements { company: company, period: period }) ERR-STATEMENT-NOT-FOUND)))
    (asserts! (is-eq (some tx-sender) (map-get? company-owners company)) ERR-NOT-AUTHORIZED)
    (ok (map-set income-statements
      { company: company, period: period }
      (merge statement { revenue: new-amount })
    ))
  )
)

(define-public (update-cost-of-goods-sold (company principal) (period uint) (new-amount uint))
  (let ((statement (unwrap! (map-get? income-statements { company: company, period: period }) ERR-STATEMENT-NOT-FOUND)))
    (asserts! (is-eq (some tx-sender) (map-get? company-owners company)) ERR-NOT-AUTHORIZED)
    (ok (map-set income-statements
      { company: company, period: period }
      (merge statement { cost-of-goods-sold: new-amount })
    ))
  )
)

(define-public (update-operating-expenses (company principal) (period uint) (new-amount uint))
  (let ((statement (unwrap! (map-get? income-statements { company: company, period: period }) ERR-STATEMENT-NOT-FOUND)))
    (asserts! (is-eq (some tx-sender) (map-get? company-owners company)) ERR-NOT-AUTHORIZED)
    (ok (map-set income-statements
      { company: company, period: period }
      (merge statement { operating-expenses: new-amount })
    ))
  )
)

(define-public (update-tax-expense (company principal) (period uint) (new-amount uint))
  (let ((statement (unwrap! (map-get? income-statements { company: company, period: period }) ERR-STATEMENT-NOT-FOUND)))
    (asserts! (is-eq (some tx-sender) (map-get? company-owners company)) ERR-NOT-AUTHORIZED)
    (ok (map-set income-statements
      { company: company, period: period }
      (merge statement { tax-expense: new-amount })
    ))
  )
)
