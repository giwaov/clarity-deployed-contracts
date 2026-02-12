(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)
(define-data-var ceo principal tx-sender)
(define-data-var ceo-appointed-at uint u0)

(define-map strategic-decisions uint {title: (string-utf8 300), decision-type: (string-ascii 30), approved-by-ceo: bool, created-at: uint, executed: bool})
(define-map department-heads principal {department: (string-ascii 50), approved-by-ceo: bool, appointed-at: uint})
(define-map budget-allocations {department: (string-ascii 50), fiscal-year: uint} {amount: uint, approved: bool})
(define-data-var decision-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-ceo) (var-get ceo))

(define-read-only (get-ceo-appointed-at) (var-get ceo-appointed-at))

(define-read-only (get-strategic-decision (decision-id uint))
  (map-get? strategic-decisions decision-id))

(define-read-only (get-department-head (head principal))
  (map-get? department-heads head))

(define-read-only (get-budget-allocation (department (string-ascii 50)) (fiscal-year uint))
  (map-get? budget-allocations {department: department, fiscal-year: fiscal-year}))

(define-public (appoint-ceo (new-ceo principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set ceo new-ceo)
    (var-set ceo-appointed-at stacks-block-height)
    (ok true)))

(define-public (create-strategic-decision (title (string-utf8 300)) (decision-type (string-ascii 30)))
  (let ((decision-id (+ (var-get decision-count) u1)))
    (asserts! (is-eq tx-sender (var-get ceo)) ERR_UNAUTHORIZED)
    (map-set strategic-decisions decision-id {title: title, decision-type: decision-type, approved-by-ceo: true, created-at: stacks-block-height, executed: false})
    (var-set decision-count decision-id)
    (ok decision-id)))

(define-public (execute-strategic-decision (decision-id uint))
  (let ((decision (unwrap! (map-get? strategic-decisions decision-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get ceo)) ERR_UNAUTHORIZED)
    (asserts! (get approved-by-ceo decision) ERR_INVALID_PARAMS)
    (asserts! (not (get executed decision)) ERR_ALREADY_EXISTS)
    (ok (map-set strategic-decisions decision-id (merge decision {executed: true})))))

(define-public (appoint-department-head (head principal) (department (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender (var-get ceo)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? department-heads head)) ERR_ALREADY_EXISTS)
    (ok (map-set department-heads head {department: department, approved-by-ceo: true, appointed-at: stacks-block-height}))))

(define-public (remove-department-head (head principal))
  (begin
    (asserts! (is-eq tx-sender (var-get ceo)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? department-heads head)) ERR_NOT_FOUND)
    (ok (map-delete department-heads head))))

(define-public (allocate-budget (department (string-ascii 50)) (fiscal-year uint) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get ceo)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_PARAMS)
    (ok (map-set budget-allocations {department: department, fiscal-year: fiscal-year} {amount: amount, approved: true}))))

(define-public (approve-budget (department (string-ascii 50)) (fiscal-year uint))
  (let ((budget (unwrap! (map-get? budget-allocations {department: department, fiscal-year: fiscal-year}) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get ceo)) ERR_UNAUTHORIZED)
    (ok (map-set budget-allocations {department: department, fiscal-year: fiscal-year} (merge budget {approved: true})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
