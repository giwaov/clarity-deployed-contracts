(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-STATEMENT-NOT-FOUND (err u101))
(define-constant ERR-INVALID-PERIOD (err u102))

(define-map cashflow-statements
  { company: principal, period: uint }
  {
    operating-activities: int,
    investing-activities: int,
    financing-activities: int,
    net-cash-change: int,
    beginning-balance: uint,
    ending-balance: uint,
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
  (operating int)
  (investing int)
  (financing int)
  (beginning uint)
  (ending uint)
)
  (let ((net-change (+ (+ operating investing) financing)))
    (asserts! (is-eq (some tx-sender) (map-get? company-owners company)) ERR-NOT-AUTHORIZED)
    (ok (map-set cashflow-statements
      { company: company, period: period }
      {
        operating-activities: operating,
        investing-activities: investing,
        financing-activities: financing,
        net-cash-change: net-change,
        beginning-balance: beginning,
        ending-balance: ending,
        submitted-at: stacks-block-height,
        submitted-by: tx-sender
      }
    ))
  )
)

(define-read-only (get-statement (company principal) (period uint))
  (map-get? cashflow-statements { company: company, period: period })
)

(define-read-only (get-company-owner (company principal))
  (map-get? company-owners company)
)

(define-public (update-operating-activities (company principal) (period uint) (new-amount int))
  (let ((statement (unwrap! (map-get? cashflow-statements { company: company, period: period }) ERR-STATEMENT-NOT-FOUND)))
    (asserts! (is-eq (some tx-sender) (map-get? company-owners company)) ERR-NOT-AUTHORIZED)
    (ok (map-set cashflow-statements
      { company: company, period: period }
      (merge statement { operating-activities: new-amount })
    ))
  )
)

(define-public (update-investing-activities (company principal) (period uint) (new-amount int))
  (let ((statement (unwrap! (map-get? cashflow-statements { company: company, period: period }) ERR-STATEMENT-NOT-FOUND)))
    (asserts! (is-eq (some tx-sender) (map-get? company-owners company)) ERR-NOT-AUTHORIZED)
    (ok (map-set cashflow-statements
      { company: company, period: period }
      (merge statement { investing-activities: new-amount })
    ))
  )
)

(define-public (update-financing-activities (company principal) (period uint) (new-amount int))
  (let ((statement (unwrap! (map-get? cashflow-statements { company: company, period: period }) ERR-STATEMENT-NOT-FOUND)))
    (asserts! (is-eq (some tx-sender) (map-get? company-owners company)) ERR-NOT-AUTHORIZED)
    (ok (map-set cashflow-statements
      { company: company, period: period }
      (merge statement { financing-activities: new-amount })
    ))
  )
)
