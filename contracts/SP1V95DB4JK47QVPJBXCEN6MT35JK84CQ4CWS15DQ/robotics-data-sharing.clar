(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-DATA-NOT-FOUND (err u101))
(define-constant ERR-ACCESS-DENIED (err u102))

(define-map process-data
  { data-id: uint }
  {
    robot-id: (string-ascii 30),
    process-type: (string-ascii 50),
    parameters: (string-ascii 200),
    timestamp: uint,
    efficiency-score: uint,
    provider: principal,
    public-access: bool
  }
)

(define-map data-access-grants
  { data-id: uint, requestor: principal }
  bool
)

(define-data-var data-nonce uint u0)

(define-public (submit-process-data
  (robot-id (string-ascii 30))
  (process-type (string-ascii 50))
  (parameters (string-ascii 200))
  (efficiency uint)
  (is-public bool)
)
  (let ((data-id (var-get data-nonce)))
    (map-set process-data
      { data-id: data-id }
      {
        robot-id: robot-id,
        process-type: process-type,
        parameters: parameters,
        timestamp: stacks-block-height,
        efficiency-score: efficiency,
        provider: tx-sender,
        public-access: is-public
      }
    )
    (var-set data-nonce (+ data-id u1))
    (ok data-id)
  )
)

(define-public (grant-access (data-id uint) (requestor principal))
  (let ((data (unwrap! (map-get? process-data { data-id: data-id }) ERR-DATA-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get provider data)) ERR-NOT-AUTHORIZED)
    (ok (map-set data-access-grants { data-id: data-id, requestor: requestor } true))
  )
)

(define-public (revoke-access (data-id uint) (requestor principal))
  (let ((data (unwrap! (map-get? process-data { data-id: data-id }) ERR-DATA-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get provider data)) ERR-NOT-AUTHORIZED)
    (ok (map-delete data-access-grants { data-id: data-id, requestor: requestor }))
  )
)

(define-read-only (get-data (data-id uint))
  (let ((data (unwrap! (map-get? process-data { data-id: data-id }) ERR-DATA-NOT-FOUND)))
    (if (or (get public-access data) (is-eq tx-sender (get provider data)))
      (ok data)
      (if (default-to false (map-get? data-access-grants { data-id: data-id, requestor: tx-sender }))
        (ok data)
        ERR-ACCESS-DENIED
      )
    )
  )
)

(define-public (update-efficiency (data-id uint) (new-efficiency uint))
  (let ((data (unwrap! (map-get? process-data { data-id: data-id }) ERR-DATA-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get provider data)) ERR-NOT-AUTHORIZED)
    (ok (map-set process-data
      { data-id: data-id }
      (merge data { efficiency-score: new-efficiency })
    ))
  )
)

(define-public (toggle-public-access (data-id uint))
  (let ((data (unwrap! (map-get? process-data { data-id: data-id }) ERR-DATA-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get provider data)) ERR-NOT-AUTHORIZED)
    (ok (map-set process-data
      { data-id: data-id }
      (merge data { public-access: (not (get public-access data)) })
    ))
  )
)
