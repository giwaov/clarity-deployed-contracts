(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-funds (err u102))
(define-constant err-deal-closed (err u103))

(define-map mbo-deals
  uint
  {
    company: (string-ascii 128),
    management-team: (list 10 principal),
    purchase-price: uint,
    equity-stake: uint,
    debt-financing: uint,
    seller: principal,
    status: (string-ascii 32),
    closing-block: uint,
    completed: bool
  })

(define-map investor-commitments
  {deal-id: uint, investor: principal}
  {amount-committed: uint, equity-received: uint, paid: bool})

(define-map management-equity
  {deal-id: uint, manager: principal}
  {equity-percentage: uint, vesting-blocks: uint, vested: bool})

(define-data-var next-deal-id uint u0)

(define-read-only (get-mbo-deal (deal-id uint))
  (ok (map-get? mbo-deals deal-id)))

(define-read-only (get-commitment (deal-id uint) (investor principal))
  (ok (map-get? investor-commitments {deal-id: deal-id, investor: investor})))

(define-public (initiate-mbo (company (string-ascii 128)) (mgmt-team (list 10 principal)) (price uint) (equity uint) (debt uint) (seller principal) (closing uint))
  (let ((deal-id (var-get next-deal-id)))
    (map-set mbo-deals deal-id
      {company: company, management-team: mgmt-team, purchase-price: price,
       equity-stake: equity, debt-financing: debt, seller: seller,
       status: "proposed", closing-block: closing, completed: false})
    (var-set next-deal-id (+ deal-id u1))
    (ok deal-id)))

(define-public (commit-investment (deal-id uint) (amount uint) (equity uint))
  (let ((deal (unwrap! (map-get? mbo-deals deal-id) err-not-found)))
    (asserts! (not (get completed deal)) err-deal-closed)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (ok (map-set investor-commitments {deal-id: deal-id, investor: tx-sender}
      {amount-committed: amount, equity-received: equity, paid: true}))))

(define-public (allocate-management-equity (deal-id uint) (manager principal) (equity-pct uint) (vesting uint))
  (let ((deal (unwrap! (map-get? mbo-deals deal-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set management-equity {deal-id: deal-id, manager: manager}
      {equity-percentage: equity-pct, vesting-blocks: vesting, vested: false}))))

(define-public (close-mbo (deal-id uint))
  (let ((deal (unwrap! (map-get? mbo-deals deal-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (>= stacks-block-height (get closing-block deal)) err-deal-closed)
    (try! (as-contract (stx-transfer? (get purchase-price deal) tx-sender (get seller deal))))
    (ok (map-set mbo-deals deal-id (merge deal {status: "closed", completed: true})))))
