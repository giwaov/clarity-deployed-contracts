(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-SHEET-NOT-FOUND (err u101))
(define-constant ERR-INVALID-PERIOD (err u102))

(define-map balance-sheets
  { company: principal, period: uint }
  {
    current-assets: uint,
    non-current-assets: uint,
    total-assets: uint,
    current-liabilities: uint,
    non-current-liabilities: uint,
    total-liabilities: uint,
    shareholders-equity: uint,
    submitted-at: uint,
    submitted-by: principal
  }
)

(define-map company-owners principal principal)

(define-public (register-company (owner principal))
  (ok (map-set company-owners tx-sender owner))
)

(define-public (submit-sheet
  (company principal)
  (period uint)
  (current-assets uint)
  (non-current-assets uint)
  (current-liabilities uint)
  (non-current-liabilities uint)
  (equity uint)
)
  (let (
    (total-assets (+ current-assets non-current-assets))
    (total-liabilities (+ current-liabilities non-current-liabilities))
  )
    (asserts! (is-eq (some tx-sender) (map-get? company-owners company)) ERR-NOT-AUTHORIZED)
    (ok (map-set balance-sheets
      { company: company, period: period }
      {
        current-assets: current-assets,
        non-current-assets: non-current-assets,
        total-assets: total-assets,
        current-liabilities: current-liabilities,
        non-current-liabilities: non-current-liabilities,
        total-liabilities: total-liabilities,
        shareholders-equity: equity,
        submitted-at: stacks-block-height,
        submitted-by: tx-sender
      }
    ))
  )
)

(define-read-only (get-sheet (company principal) (period uint))
  (map-get? balance-sheets { company: company, period: period })
)

(define-read-only (get-company-owner (company principal))
  (map-get? company-owners company)
)

(define-public (update-current-assets (company principal) (period uint) (new-amount uint))
  (let ((sheet (unwrap! (map-get? balance-sheets { company: company, period: period }) ERR-SHEET-NOT-FOUND)))
    (asserts! (is-eq (some tx-sender) (map-get? company-owners company)) ERR-NOT-AUTHORIZED)
    (ok (map-set balance-sheets
      { company: company, period: period }
      (merge sheet { current-assets: new-amount })
    ))
  )
)

(define-public (update-non-current-assets (company principal) (period uint) (new-amount uint))
  (let ((sheet (unwrap! (map-get? balance-sheets { company: company, period: period }) ERR-SHEET-NOT-FOUND)))
    (asserts! (is-eq (some tx-sender) (map-get? company-owners company)) ERR-NOT-AUTHORIZED)
    (ok (map-set balance-sheets
      { company: company, period: period }
      (merge sheet { non-current-assets: new-amount })
    ))
  )
)

(define-public (update-current-liabilities (company principal) (period uint) (new-amount uint))
  (let ((sheet (unwrap! (map-get? balance-sheets { company: company, period: period }) ERR-SHEET-NOT-FOUND)))
    (asserts! (is-eq (some tx-sender) (map-get? company-owners company)) ERR-NOT-AUTHORIZED)
    (ok (map-set balance-sheets
      { company: company, period: period }
      (merge sheet { current-liabilities: new-amount })
    ))
  )
)

(define-public (update-shareholders-equity (company principal) (period uint) (new-amount uint))
  (let ((sheet (unwrap! (map-get? balance-sheets { company: company, period: period }) ERR-SHEET-NOT-FOUND)))
    (asserts! (is-eq (some tx-sender) (map-get? company-owners company)) ERR-NOT-AUTHORIZED)
    (ok (map-set balance-sheets
      { company: company, period: period }
      (merge sheet { shareholders-equity: new-amount })
    ))
  )
)
