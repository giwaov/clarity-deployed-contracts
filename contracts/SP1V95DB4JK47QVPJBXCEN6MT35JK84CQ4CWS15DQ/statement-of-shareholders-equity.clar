(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-STATEMENT-NOT-FOUND (err u101))
(define-constant ERR-INVALID-PERIOD (err u102))

(define-map equity-statements
  { company: principal, period: uint }
  {
    beginning-balance: uint,
    stock-issuance: uint,
    stock-repurchase: uint,
    net-income: uint,
    dividends-paid: uint,
    other-comprehensive-income: int,
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
  (beginning uint)
  (issuance uint)
  (repurchase uint)
  (net-income uint)
  (dividends uint)
  (oci int)
)
  (let (
    (ending (+ (+ (+ (- (+ beginning issuance) repurchase) net-income) (if (>= oci 0) (to-uint oci) u0)) (- dividends)))
  )
    (asserts! (is-eq (some tx-sender) (map-get? company-owners company)) ERR-NOT-AUTHORIZED)
    (ok (map-set equity-statements
      { company: company, period: period }
      {
        beginning-balance: beginning,
        stock-issuance: issuance,
        stock-repurchase: repurchase,
        net-income: net-income,
        dividends-paid: dividends,
        other-comprehensive-income: oci,
        ending-balance: ending,
        submitted-at: stacks-block-height,
        submitted-by: tx-sender
      }
    ))
  )
)

(define-read-only (get-statement (company principal) (period uint))
  (map-get? equity-statements { company: company, period: period })
)

(define-read-only (get-company-owner (company principal))
  (map-get? company-owners company)
)

(define-public (update-stock-issuance (company principal) (period uint) (new-amount uint))
  (let ((statement (unwrap! (map-get? equity-statements { company: company, period: period }) ERR-STATEMENT-NOT-FOUND)))
    (asserts! (is-eq (some tx-sender) (map-get? company-owners company)) ERR-NOT-AUTHORIZED)
    (ok (map-set equity-statements
      { company: company, period: period }
      (merge statement { stock-issuance: new-amount })
    ))
  )
)

(define-public (update-stock-repurchase (company principal) (period uint) (new-amount uint))
  (let ((statement (unwrap! (map-get? equity-statements { company: company, period: period }) ERR-STATEMENT-NOT-FOUND)))
    (asserts! (is-eq (some tx-sender) (map-get? company-owners company)) ERR-NOT-AUTHORIZED)
    (ok (map-set equity-statements
      { company: company, period: period }
      (merge statement { stock-repurchase: new-amount })
    ))
  )
)

(define-public (update-dividends-paid (company principal) (period uint) (new-amount uint))
  (let ((statement (unwrap! (map-get? equity-statements { company: company, period: period }) ERR-STATEMENT-NOT-FOUND)))
    (asserts! (is-eq (some tx-sender) (map-get? company-owners company)) ERR-NOT-AUTHORIZED)
    (ok (map-set equity-statements
      { company: company, period: period }
      (merge statement { dividends-paid: new-amount })
    ))
  )
)

(define-public (update-net-income (company principal) (period uint) (new-amount uint))
  (let ((statement (unwrap! (map-get? equity-statements { company: company, period: period }) ERR-STATEMENT-NOT-FOUND)))
    (asserts! (is-eq (some tx-sender) (map-get? company-owners company)) ERR-NOT-AUTHORIZED)
    (ok (map-set equity-statements
      { company: company, period: period }
      (merge statement { net-income: new-amount })
    ))
  )
)
