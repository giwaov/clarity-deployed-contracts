(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_PARAMS (err u101))
(define-constant ERR_COMPANY_NOT_FOUND (err u102))
(define-constant ERR_EMPLOYEE_NOT_FOUND (err u103))
(define-constant ERR_CONTRACT_NOT_FOUND (err u104))
(define-constant ERR_INSUFFICIENT_FUNDS (err u105))
(define-constant ERR_DISPUTE_ACTIVE (err u106))

(define-data-var next-company-id uint u1)
(define-data-var next-employee-token-id uint u1)
(define-data-var next-contract-id uint u1)

(define-map companies
  uint
  {
    name: (string-ascii 256),
    industry: (string-ascii 256),
    owner: principal,
    employee-count: uint
  }
)

(define-map employee-tokens
  uint
  {
    employee: principal,
    metadata-uri: (string-ascii 512),
    created-at: uint
  }
)

(define-map employment-history
  uint
  (list 100 uint)
)

(define-map labor-contracts
  uint
  {
    company-id: uint,
    employee-token-id: uint,
    salary: uint,
    duration: uint,
    responsibilities: (string-ascii 512),
    termination-conditions: (string-ascii 512),
    status: (string-ascii 64),
    executed: bool,
    escrow-balance: uint,
    dispute-active: bool
  }
)

(define-map contract-reviews
  uint
  (list 10 {
    rating: uint,
    comments: (string-ascii 512),
    reviewer: principal
  })
)

(define-read-only (get-contract-hash)
  (contract-hash? .employment-system)
)

(define-read-only (get-company (company-id uint))
  (ok (unwrap! (map-get? companies company-id) ERR_COMPANY_NOT_FOUND))
)

(define-read-only (get-employment-history (employee-token-id uint))
  (ok (default-to (list) (map-get? employment-history employee-token-id)))
)

(define-read-only (get-contract (contract-id uint))
  (ok (unwrap! (map-get? labor-contracts contract-id) ERR_CONTRACT_NOT_FOUND))
)

(define-read-only (get-employee-token (token-id uint))
  (ok (unwrap! (map-get? employee-tokens token-id) ERR_EMPLOYEE_NOT_FOUND))
)

(define-public (register-company (name (string-ascii 256)) (industry (string-ascii 256)))
  (let
    (
      (company-id (var-get next-company-id))
    )
    (asserts! (> (len name) u0) ERR_INVALID_PARAMS)
    (map-set companies company-id {
      name: name,
      industry: industry,
      owner: tx-sender,
      employee-count: u0
    })
    (var-set next-company-id (+ company-id u1))
    (ok company-id)
  )
)

(define-public (mint-employee-token (employee principal) (metadata-uri (string-ascii 512)))
  (let
    (
      (token-id (var-get next-employee-token-id))
    )
    (map-set employee-tokens token-id {
      employee: employee,
      metadata-uri: metadata-uri,
      created-at: stacks-block-time
    })
    (var-set next-employee-token-id (+ token-id u1))
    (ok token-id)
  )
)

(define-public (create-contract 
  (company-id uint)
  (employee-token-id uint)
  (salary uint)
  (duration uint)
  (responsibilities (string-ascii 512))
  (termination-conditions (string-ascii 512))
)
  (let
    (
      (contract-id (var-get next-contract-id))
      (company-data (unwrap! (map-get? companies company-id) ERR_COMPANY_NOT_FOUND))
      (employee-data (unwrap! (map-get? employee-tokens employee-token-id) ERR_EMPLOYEE_NOT_FOUND))
    )
    (asserts! (is-eq (get owner company-data) tx-sender) ERR_NOT_AUTHORIZED)
    (map-set labor-contracts contract-id {
      company-id: company-id,
      employee-token-id: employee-token-id,
      salary: salary,
      duration: duration,
      responsibilities: responsibilities,
      termination-conditions: termination-conditions,
      status: "Created",
      executed: false,
      escrow-balance: u0,
      dispute-active: false
    })
    (var-set next-contract-id (+ contract-id u1))
    (ok contract-id)
  )
)

(define-public (execute-contract (contract-id uint))
  (let
    (
      (contract-data (unwrap! (map-get? labor-contracts contract-id) ERR_CONTRACT_NOT_FOUND))
    )
    (asserts! (not (get executed contract-data)) ERR_INVALID_PARAMS)
    (map-set labor-contracts contract-id (merge contract-data {
      status: "Active",
      executed: true
    }))
    (let
      (
        (history (default-to (list) (map-get? employment-history (get employee-token-id contract-data))))
      )
      (map-set employment-history (get employee-token-id contract-data) (unwrap-panic (as-max-len? (append history contract-id) u100)))
    )
    (ok true)
  )
)

(define-public (deposit-salary (contract-id uint))
  (let
    (
      (contract-data (unwrap! (map-get? labor-contracts contract-id) ERR_CONTRACT_NOT_FOUND))
    )
    (asserts! (>= (stx-get-balance tx-sender) (get salary contract-data)) ERR_INSUFFICIENT_FUNDS)
    (try! (stx-transfer? (get salary contract-data) tx-sender CONTRACT_OWNER))
    (map-set labor-contracts contract-id (merge contract-data {
      escrow-balance: (+ (get escrow-balance contract-data) (get salary contract-data))
    }))
    (ok true)
  )
)

(define-public (release-salary (contract-id uint))
  (let
    (
      (contract-data (unwrap! (map-get? labor-contracts contract-id) ERR_CONTRACT_NOT_FOUND))
      (employee-data (unwrap! (map-get? employee-tokens (get employee-token-id contract-data)) ERR_EMPLOYEE_NOT_FOUND))
    )
    (asserts! (> (get escrow-balance contract-data) u0) ERR_INSUFFICIENT_FUNDS)
    (try! (stx-transfer? (get escrow-balance contract-data) CONTRACT_OWNER (get employee employee-data)))
    (map-set labor-contracts contract-id (merge contract-data {
      escrow-balance: u0
    }))
    (ok true)
  )
)

(define-public (raise-dispute (contract-id uint))
  (let
    (
      (contract-data (unwrap! (map-get? labor-contracts contract-id) ERR_CONTRACT_NOT_FOUND))
    )
    (map-set labor-contracts contract-id (merge contract-data {
      dispute-active: true
    }))
    (ok true)
  )
)

(define-public (resolve-dispute (contract-id uint) (decision-for-employee bool))
  (let
    (
      (contract-data (unwrap! (map-get? labor-contracts contract-id) ERR_CONTRACT_NOT_FOUND))
      (employee-data (unwrap! (map-get? employee-tokens (get employee-token-id contract-data)) ERR_EMPLOYEE_NOT_FOUND))
    )
    (asserts! (get dispute-active contract-data) ERR_DISPUTE_ACTIVE)
    (if decision-for-employee
      (begin
        (try! (stx-transfer? (get escrow-balance contract-data) CONTRACT_OWNER (get employee employee-data)))
        (map-set labor-contracts contract-id (merge contract-data {
          dispute-active: false,
          escrow-balance: u0
        }))
      )
      (map-set labor-contracts contract-id (merge contract-data {
        dispute-active: false
      }))
    )
    (ok true)
  )
)

(define-public (terminate-contract (contract-id uint) (reason (string-ascii 512)))
  (let
    (
      (contract-data (unwrap! (map-get? labor-contracts contract-id) ERR_CONTRACT_NOT_FOUND))
      (company-data (unwrap! (map-get? companies (get company-id contract-data)) ERR_COMPANY_NOT_FOUND))
    )
    (asserts! (is-eq (get owner company-data) tx-sender) ERR_NOT_AUTHORIZED)
    (map-set labor-contracts contract-id (merge contract-data {
      status: "Terminated"
    }))
    (ok true)
  )
)

(define-public (submit-review (contract-id uint) (rating uint) (comments (string-ascii 512)))
  (let
    (
      (contract-data (unwrap! (map-get? labor-contracts contract-id) ERR_CONTRACT_NOT_FOUND))
      (existing-reviews (default-to (list) (map-get? contract-reviews contract-id)))
      (new-review {rating: rating, comments: comments, reviewer: tx-sender})
    )
    (map-set contract-reviews contract-id (unwrap-panic (as-max-len? (append existing-reviews new-review) u10)))
    (ok true)
  )
)

(define-read-only (get-reviews (contract-id uint))
  (ok (default-to (list) (map-get? contract-reviews contract-id)))
)

(define-read-only (verify-contract-signature (message (buff 32)) (signature (buff 64)))
  (let ((hash-bytes (unwrap-panic (contract-hash? .employment-system)))
        (dummy-pk 0x020000000000000000000000000000000000000000000000000000000000000000))
    (ok (secp256r1-verify message signature dummy-pk))
  )
)
