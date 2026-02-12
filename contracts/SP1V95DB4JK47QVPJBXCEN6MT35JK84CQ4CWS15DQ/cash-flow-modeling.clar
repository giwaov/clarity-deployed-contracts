(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))

(define-data-var model-nonce uint u0)

(define-map cash-flow-models
  uint
  {
    entity: principal,
    model-type: (string-ascii 30),
    revenue-projection: uint,
    expense-projection: uint,
    operating-cash-flow: uint,
    investing-cash-flow: uint,
    financing-cash-flow: uint,
    net-cash-flow: uint,
    period-start: uint,
    period-end: uint,
    created-block: uint
  }
)

(define-map cash-entries
  {model-id: uint, entry-id: uint}
  {
    entry-type: (string-ascii 20),
    amount: uint,
    category: (string-ascii 30),
    block: uint
  }
)

(define-map entry-counter uint uint)
(define-map entity-models principal (list 50 uint))

(define-public (create-model (model-type (string-ascii 30)) (revenue uint) (expenses uint) 
                              (operating uint) (investing uint) (financing uint) (period-end uint))
  (let
    (
      (model-id (+ (var-get model-nonce) u1))
      (net-flow (- (+ operating investing) financing))
    )
    (map-set cash-flow-models model-id {
      entity: tx-sender,
      model-type: model-type,
      revenue-projection: revenue,
      expense-projection: expenses,
      operating-cash-flow: operating,
      investing-cash-flow: investing,
      financing-cash-flow: financing,
      net-cash-flow: net-flow,
      period-start: stacks-block-height,
      period-end: period-end,
      created-block: stacks-block-height
    })
    (map-set entry-counter model-id u0)
    (map-set entity-models tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? entity-models tx-sender)) model-id) u50)))
    (var-set model-nonce model-id)
    (ok model-id)
  )
)

(define-public (add-cash-entry (model-id uint) (entry-type (string-ascii 20)) 
                                (amount uint) (category (string-ascii 30)))
  (let
    (
      (model (unwrap! (map-get? cash-flow-models model-id) err-not-found))
      (entry-id (+ (default-to u0 (map-get? entry-counter model-id)) u1))
    )
    (asserts! (is-eq tx-sender (get entity model)) err-unauthorized)
    (map-set cash-entries {model-id: model-id, entry-id: entry-id} {
      entry-type: entry-type,
      amount: amount,
      category: category,
      block: stacks-block-height
    })
    (map-set entry-counter model-id entry-id)
    (ok entry-id)
  )
)

(define-public (update-projection (model-id uint) (new-revenue uint) (new-expenses uint))
  (let
    (
      (model (unwrap! (map-get? cash-flow-models model-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get entity model)) err-unauthorized)
    (map-set cash-flow-models model-id (merge model {
      revenue-projection: new-revenue,
      expense-projection: new-expenses
    }))
    (ok true)
  )
)

(define-public (finalize-model (model-id uint))
  (let
    (
      (model (unwrap! (map-get? cash-flow-models model-id) err-not-found))
      (net (calculate-net-cash-flow model-id))
    )
    (asserts! (is-eq tx-sender (get entity model)) err-unauthorized)
    (map-set cash-flow-models model-id (merge model {net-cash-flow: net}))
    (ok net)
  )
)

(define-read-only (get-model (model-id uint))
  (ok (map-get? cash-flow-models model-id))
)

(define-read-only (get-entry (model-id uint) (entry-id uint))
  (ok (map-get? cash-entries {model-id: model-id, entry-id: entry-id}))
)

(define-read-only (get-entity-models (entity principal))
  (ok (map-get? entity-models entity))
)

(define-read-only (calculate-net-cash-flow (model-id uint))
  (let
    (
      (model (unwrap-panic (map-get? cash-flow-models model-id)))
      (operating (get operating-cash-flow model))
      (investing (get investing-cash-flow model))
      (financing (get financing-cash-flow model))
    )
    (- (+ operating investing) financing)
  )
)

(define-read-only (calculate-burn-rate (model-id uint))
  (let
    (
      (model (unwrap-panic (map-get? cash-flow-models model-id)))
      (revenue (get revenue-projection model))
      (expenses (get expense-projection model))
      (period-length (- (get period-end model) (get period-start model)))
    )
    (if (> period-length u0)
      (ok (/ (- expenses revenue) period-length))
      (ok u0)
    )
  )
)

(define-read-only (calculate-runway (model-id uint) (current-cash uint))
  (let
    (
      (burn (unwrap-panic (calculate-burn-rate model-id)))
    )
    (if (> burn u0)
      (ok (/ current-cash burn))
      (ok u0)
    )
  )
)

(define-read-only (get-cash-flow-metrics (model-id uint))
  (let
    (
      (model (unwrap-panic (map-get? cash-flow-models model-id)))
    )
    (ok {
      net-flow: (get net-cash-flow model),
      operating: (get operating-cash-flow model),
      investing: (get investing-cash-flow model),
      financing: (get financing-cash-flow model)
    })
  )
)
