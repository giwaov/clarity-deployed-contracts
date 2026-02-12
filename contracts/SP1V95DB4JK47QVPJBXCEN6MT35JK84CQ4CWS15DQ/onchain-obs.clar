(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-SCREENING-NOT-FOUND (err u101))
(define-constant ERR-MATCH-FOUND (err u102))

(define-map sanctions-screenings
  { entity-id: (string-ascii 100) }
  {
    entity-name: (string-ascii 100),
    entity-type: (string-ascii 30),
    screening-date: uint,
    risk-level: (string-ascii 20),
    match-found: bool,
    screener: principal,
    notes: (string-ascii 200)
  }
)

(define-map screening-matches
  { entity-id: (string-ascii 100), match-id: uint }
  {
    list-name: (string-ascii 100),
    match-confidence: uint,
    details: (string-ascii 200),
    reported-at: uint,
    resolved: bool
  }
)

(define-data-var compliance-officer principal tx-sender)

(define-public (screen-entity
  (entity-id (string-ascii 100))
  (entity-name (string-ascii 100))
  (entity-type (string-ascii 30))
  (risk-level (string-ascii 20))
  (has-match bool)
)
  (ok (map-set sanctions-screenings
    { entity-id: entity-id }
    {
      entity-name: entity-name,
      entity-type: entity-type,
      screening-date: stacks-block-height,
      risk-level: risk-level,
      match-found: has-match,
      screener: tx-sender,
      notes: ""
    }
  ))
)

(define-public (record-match
  (entity-id (string-ascii 100))
  (match-id uint)
  (list-name (string-ascii 100))
  (confidence uint)
  (details (string-ascii 200))
)
  (begin
    (asserts! (is-eq tx-sender (var-get compliance-officer)) ERR-NOT-AUTHORIZED)
    (ok (map-set screening-matches
      { entity-id: entity-id, match-id: match-id }
      {
        list-name: list-name,
        match-confidence: confidence,
        details: details,
        reported-at: stacks-block-height,
        resolved: false
      }
    ))
  )
)

(define-public (resolve-match (entity-id (string-ascii 100)) (match-id uint))
  (let ((match (unwrap! (map-get? screening-matches { entity-id: entity-id, match-id: match-id }) ERR-SCREENING-NOT-FOUND)))
    (asserts! (is-eq tx-sender (var-get compliance-officer)) ERR-NOT-AUTHORIZED)
    (ok (map-set screening-matches
      { entity-id: entity-id, match-id: match-id }
      (merge match { resolved: true })
    ))
  )
)

(define-public (update-risk-level (entity-id (string-ascii 100)) (new-level (string-ascii 20)))
  (let ((screening (unwrap! (map-get? sanctions-screenings { entity-id: entity-id }) ERR-SCREENING-NOT-FOUND)))
    (asserts! (is-eq tx-sender (var-get compliance-officer)) ERR-NOT-AUTHORIZED)
    (ok (map-set sanctions-screenings
      { entity-id: entity-id }
      (merge screening { risk-level: new-level })
    ))
  )
)

(define-read-only (get-screening-info (entity-id (string-ascii 100)))
  (map-get? sanctions-screenings { entity-id: entity-id })
)

(define-read-only (get-match-info (entity-id (string-ascii 100)) (match-id uint))
  (map-get? screening-matches { entity-id: entity-id, match-id: match-id })
)

(define-public (add-screening-notes (entity-id (string-ascii 100)) (notes (string-ascii 200)))
  (let ((screening (unwrap! (map-get? sanctions-screenings { entity-id: entity-id }) ERR-SCREENING-NOT-FOUND)))
    (asserts! (is-eq tx-sender (var-get compliance-officer)) ERR-NOT-AUTHORIZED)
    (ok (map-set sanctions-screenings
      { entity-id: entity-id }
      (merge screening { notes: notes })
    ))
  )
)
