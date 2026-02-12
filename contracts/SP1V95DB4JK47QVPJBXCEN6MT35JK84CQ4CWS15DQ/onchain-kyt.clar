(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-TRANSACTION-NOT-FOUND (err u101))
(define-constant ERR-FLAGGED (err u102))

(define-map transaction-records
  { tx-id: (string-ascii 100) }
  {
    sender: principal,
    recipient: principal,
    amount: uint,
    timestamp: uint,
    risk-score: uint,
    flagged: bool,
    analyst: principal,
    notes: (string-ascii 200)
  }
)

(define-map risk-alerts
  { tx-id: (string-ascii 100), alert-id: uint }
  {
    alert-type: (string-ascii 50),
    severity: uint,
    description: (string-ascii 200),
    created-at: uint,
    resolved: bool
  }
)

(define-data-var compliance-officer principal tx-sender)

(define-public (record-transaction
  (tx-id (string-ascii 100))
  (sender principal)
  (recipient principal)
  (amount uint)
  (risk-score uint)
)
  (ok (map-set transaction-records
    { tx-id: tx-id }
    {
      sender: sender,
      recipient: recipient,
      amount: amount,
      timestamp: stacks-block-height,
      risk-score: risk-score,
      flagged: false,
      analyst: tx-sender,
      notes: ""
    }
  ))
)

(define-public (flag-transaction (tx-id (string-ascii 100)) (reason (string-ascii 200)))
  (let ((tx-record (unwrap! (map-get? transaction-records { tx-id: tx-id }) ERR-TRANSACTION-NOT-FOUND)))
    (asserts! (is-eq tx-sender (var-get compliance-officer)) ERR-NOT-AUTHORIZED)
    (ok (map-set transaction-records
      { tx-id: tx-id }
      (merge tx-record { flagged: true, notes: reason })
    ))
  )
)

(define-public (create-risk-alert
  (tx-id (string-ascii 100))
  (alert-id uint)
  (alert-type (string-ascii 50))
  (severity uint)
  (description (string-ascii 200))
)
  (begin
    (asserts! (is-eq tx-sender (var-get compliance-officer)) ERR-NOT-AUTHORIZED)
    (ok (map-set risk-alerts
      { tx-id: tx-id, alert-id: alert-id }
      {
        alert-type: alert-type,
        severity: severity,
        description: description,
        created-at: stacks-block-height,
        resolved: false
      }
    ))
  )
)

(define-public (resolve-alert (tx-id (string-ascii 100)) (alert-id uint))
  (let ((alert (unwrap! (map-get? risk-alerts { tx-id: tx-id, alert-id: alert-id }) ERR-TRANSACTION-NOT-FOUND)))
    (asserts! (is-eq tx-sender (var-get compliance-officer)) ERR-NOT-AUTHORIZED)
    (ok (map-set risk-alerts
      { tx-id: tx-id, alert-id: alert-id }
      (merge alert { resolved: true })
    ))
  )
)

(define-read-only (get-transaction-info (tx-id (string-ascii 100)))
  (map-get? transaction-records { tx-id: tx-id })
)

(define-read-only (get-alert-info (tx-id (string-ascii 100)) (alert-id uint))
  (map-get? risk-alerts { tx-id: tx-id, alert-id: alert-id })
)

(define-public (update-risk-score (tx-id (string-ascii 100)) (new-score uint))
  (let ((tx-record (unwrap! (map-get? transaction-records { tx-id: tx-id }) ERR-TRANSACTION-NOT-FOUND)))
    (asserts! (is-eq tx-sender (var-get compliance-officer)) ERR-NOT-AUTHORIZED)
    (ok (map-set transaction-records
      { tx-id: tx-id }
      (merge tx-record { risk-score: new-score })
    ))
  )
)
