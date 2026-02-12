(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u200))
(define-constant ERR_INVALID_PARAMS (err u201))
(define-constant ERR_INVALID_TIMESTAMP (err u202))

(define-data-var stablecoin-address principal tx-sender)

(define-map revenue-data
  {start-time: uint, end-time: uint}
  {
    gross-revenue: uint,
    detail-1: uint,
    detail-2: uint
  }
)

(define-map cogs-data
  {start-time: uint, end-time: uint}
  {
    total-cogs: uint,
    detail-1: uint,
    detail-2: uint
  }
)

(define-map operating-expenses-data
  {start-time: uint, end-time: uint}
  {
    total-expenses: uint,
    detail-1: uint,
    detail-2: uint
  }
)

(define-map operating-income-data
  {start-time: uint, end-time: uint}
  {
    total-income: uint,
    detail-1: uint,
    detail-2: uint
  }
)

(define-map ebitda-data
  {start-time: uint, end-time: uint}
  {
    total-ebitda: uint,
    detail-1: uint,
    detail-2: uint
  }
)

(define-map other-income-expenses-data
  {start-time: uint, end-time: uint}
  {
    total-other-income: uint,
    total-other-expenses: uint,
    income-detail-1: uint,
    expense-detail-1: uint
  }
)

(define-map net-income-data
  {start-time: uint, end-time: uint}
  {
    total-net-income: uint,
    detail-1: uint,
    detail-2: uint
  }
)

(define-map eps-data
  {start-time: uint, end-time: uint}
  {
    basic-eps: uint,
    diluted-eps: uint,
    detail-1: uint,
    detail-2: uint
  }
)

(define-read-only (get-contract-hash)
  (contract-hash? .financial-statement)
)

(define-read-only (get-stablecoin-address)
  (ok (var-get stablecoin-address))
)

(define-public (set-stablecoin-address (new-address principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set stablecoin-address new-address)
    (ok true)
  )
)

(define-read-only (get-revenue (start-timestamp uint) (end-timestamp uint))
  (begin
    (asserts! (<= start-timestamp end-timestamp) ERR_INVALID_TIMESTAMP)
    (ok (default-to 
      {gross-revenue: u0, detail-1: u0, detail-2: u0}
      (map-get? revenue-data {start-time: start-timestamp, end-time: end-timestamp})
    ))
  )
)

(define-read-only (get-cogs (start-timestamp uint) (end-timestamp uint))
  (begin
    (asserts! (<= start-timestamp end-timestamp) ERR_INVALID_TIMESTAMP)
    (ok (default-to 
      {total-cogs: u0, detail-1: u0, detail-2: u0}
      (map-get? cogs-data {start-time: start-timestamp, end-time: end-timestamp})
    ))
  )
)

(define-read-only (get-operating-expenses (start-timestamp uint) (end-timestamp uint))
  (begin
    (asserts! (<= start-timestamp end-timestamp) ERR_INVALID_TIMESTAMP)
    (ok (default-to 
      {total-expenses: u0, detail-1: u0, detail-2: u0}
      (map-get? operating-expenses-data {start-time: start-timestamp, end-time: end-timestamp})
    ))
  )
)

(define-read-only (get-operating-income (start-timestamp uint) (end-timestamp uint))
  (begin
    (asserts! (<= start-timestamp end-timestamp) ERR_INVALID_TIMESTAMP)
    (ok (default-to 
      {total-income: u0, detail-1: u0, detail-2: u0}
      (map-get? operating-income-data {start-time: start-timestamp, end-time: end-timestamp})
    ))
  )
)

(define-read-only (get-ebitda (start-timestamp uint) (end-timestamp uint))
  (begin
    (asserts! (<= start-timestamp end-timestamp) ERR_INVALID_TIMESTAMP)
    (ok (default-to 
      {total-ebitda: u0, detail-1: u0, detail-2: u0}
      (map-get? ebitda-data {start-time: start-timestamp, end-time: end-timestamp})
    ))
  )
)

(define-read-only (get-other-income-expenses (start-timestamp uint) (end-timestamp uint))
  (begin
    (asserts! (<= start-timestamp end-timestamp) ERR_INVALID_TIMESTAMP)
    (ok (default-to 
      {total-other-income: u0, total-other-expenses: u0, income-detail-1: u0, expense-detail-1: u0}
      (map-get? other-income-expenses-data {start-time: start-timestamp, end-time: end-timestamp})
    ))
  )
)

(define-read-only (get-net-income (start-timestamp uint) (end-timestamp uint))
  (begin
    (asserts! (<= start-timestamp end-timestamp) ERR_INVALID_TIMESTAMP)
    (ok (default-to 
      {total-net-income: u0, detail-1: u0, detail-2: u0}
      (map-get? net-income-data {start-time: start-timestamp, end-time: end-timestamp})
    ))
  )
)

(define-read-only (get-earnings-per-share (start-timestamp uint) (end-timestamp uint))
  (begin
    (asserts! (<= start-timestamp end-timestamp) ERR_INVALID_TIMESTAMP)
    (ok (default-to 
      {basic-eps: u0, diluted-eps: u0, detail-1: u0, detail-2: u0}
      (map-get? eps-data {start-time: start-timestamp, end-time: end-timestamp})
    ))
  )
)

(define-public (update-revenue 
  (start-timestamp uint)
  (end-timestamp uint)
  (gross-revenue uint)
  (detail-1 uint)
  (detail-2 uint)
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= start-timestamp end-timestamp) ERR_INVALID_TIMESTAMP)
    (map-set revenue-data 
      {start-time: start-timestamp, end-time: end-timestamp}
      {gross-revenue: gross-revenue, detail-1: detail-1, detail-2: detail-2}
    )
    (ok true)
  )
)

(define-public (update-cogs 
  (start-timestamp uint)
  (end-timestamp uint)
  (total-cogs uint)
  (detail-1 uint)
  (detail-2 uint)
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= start-timestamp end-timestamp) ERR_INVALID_TIMESTAMP)
    (map-set cogs-data 
      {start-time: start-timestamp, end-time: end-timestamp}
      {total-cogs: total-cogs, detail-1: detail-1, detail-2: detail-2}
    )
    (ok true)
  )
)

(define-public (update-operating-expenses 
  (start-timestamp uint)
  (end-timestamp uint)
  (total-expenses uint)
  (detail-1 uint)
  (detail-2 uint)
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= start-timestamp end-timestamp) ERR_INVALID_TIMESTAMP)
    (map-set operating-expenses-data 
      {start-time: start-timestamp, end-time: end-timestamp}
      {total-expenses: total-expenses, detail-1: detail-1, detail-2: detail-2}
    )
    (ok true)
  )
)

(define-public (update-ebitda 
  (start-timestamp uint)
  (end-timestamp uint)
  (total-ebitda uint)
  (detail-1 uint)
  (detail-2 uint)
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= start-timestamp end-timestamp) ERR_INVALID_TIMESTAMP)
    (map-set ebitda-data 
      {start-time: start-timestamp, end-time: end-timestamp}
      {total-ebitda: total-ebitda, detail-1: detail-1, detail-2: detail-2}
    )
    (ok true)
  )
)

(define-public (update-eps 
  (start-timestamp uint)
  (end-timestamp uint)
  (basic-eps uint)
  (diluted-eps uint)
  (detail-1 uint)
  (detail-2 uint)
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= start-timestamp end-timestamp) ERR_INVALID_TIMESTAMP)
    (map-set eps-data 
      {start-time: start-timestamp, end-time: end-timestamp}
      {basic-eps: basic-eps, diluted-eps: diluted-eps, detail-1: detail-1, detail-2: detail-2}
    )
    (ok true)
  )
)

(define-read-only (get-block-time)
  stacks-block-time
)

(define-read-only (verify-report-signature (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (ok (secp256r1-verify message signature public-key))
)
