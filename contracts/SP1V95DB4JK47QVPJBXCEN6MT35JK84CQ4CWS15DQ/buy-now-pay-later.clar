(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))

(define-data-var contract-owner principal tx-sender)

(define-map users principal {verified: bool, credit-score: uint, total-borrowed: uint, total-repaid: uint, active: bool})
(define-map purchases uint {buyer: principal, merchant: principal, amount: uint, installments: uint, paid-installments: uint, interest-rate: uint, created-at: uint, status: (string-ascii 20)})
(define-map installment-payments {purchase-id: uint, installment-number: uint} {amount: uint, due-date: uint, paid: bool, paid-at: uint})
(define-map merchants principal {merchant-name: (string-ascii 100), commission-rate: uint, verified: bool, active: bool})
(define-data-var purchase-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-user (user-id principal))
  (map-get? users user-id))

(define-read-only (get-purchase (purchase-id uint))
  (map-get? purchases purchase-id))

(define-read-only (get-installment (purchase-id uint) (installment-number uint))
  (map-get? installment-payments {purchase-id: purchase-id, installment-number: installment-number}))

(define-read-only (get-merchant (merchant-id principal))
  (map-get? merchants merchant-id))

(define-public (register-user (credit-score uint))
  (begin
    (asserts! (is-none (map-get? users tx-sender)) ERR_ALREADY_EXISTS)
    (asserts! (<= credit-score u850) ERR_INVALID_PARAMS)
    (ok (map-set users tx-sender {verified: false, credit-score: credit-score, total-borrowed: u0, total-repaid: u0, active: true}))))

(define-public (verify-user (user principal))
  (let ((user-data (unwrap! (map-get? users user) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set users user (merge user-data {verified: true})))))

(define-public (register-merchant (merchant-name (string-ascii 100)) (commission-rate uint))
  (begin
    (asserts! (is-none (map-get? merchants tx-sender)) ERR_ALREADY_EXISTS)
    (asserts! (<= commission-rate u20) ERR_INVALID_PARAMS)
    (ok (map-set merchants tx-sender {merchant-name: merchant-name, commission-rate: commission-rate, verified: false, active: true}))))

(define-public (verify-merchant (merchant principal))
  (let ((merchant-data (unwrap! (map-get? merchants merchant) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set merchants merchant (merge merchant-data {verified: true})))))

(define-public (create-purchase (merchant principal) (amount uint) (installments uint) (interest-rate uint))
  (let ((purchase-id (+ (var-get purchase-count) u1))
        (user-data (unwrap! (map-get? users tx-sender) ERR_UNAUTHORIZED))
        (merchant-data (unwrap! (map-get? merchants merchant) ERR_NOT_FOUND)))
    (asserts! (get verified user-data) ERR_UNAUTHORIZED)
    (asserts! (get active user-data) ERR_UNAUTHORIZED)
    (asserts! (get verified merchant-data) ERR_NOT_FOUND)
    (asserts! (and (> amount u0) (> installments u0) (<= installments u24)) ERR_INVALID_PARAMS)
    (map-set purchases purchase-id {buyer: tx-sender, merchant: merchant, amount: amount, installments: installments, paid-installments: u0, interest-rate: interest-rate, created-at: stacks-block-height, status: "active"})
    (map-set users tx-sender (merge user-data {total-borrowed: (+ (get total-borrowed user-data) amount)}))
    (var-set purchase-count purchase-id)
    (ok purchase-id)))

(define-public (pay-installment (purchase-id uint) (installment-number uint))
  (let ((purchase (unwrap! (map-get? purchases purchase-id) ERR_NOT_FOUND))
        (user-data (unwrap! (map-get? users tx-sender) ERR_NOT_FOUND))
        (installment-amount (/ (get amount purchase) (get installments purchase))))
    (asserts! (is-eq tx-sender (get buyer purchase)) ERR_UNAUTHORIZED)
    (asserts! (<= installment-number (get installments purchase)) ERR_INVALID_PARAMS)
    (let ((installment (default-to {amount: installment-amount, due-date: (+ (get created-at purchase) (* installment-number u144)), paid: false, paid-at: u0} 
                                    (map-get? installment-payments {purchase-id: purchase-id, installment-number: installment-number}))))
      (asserts! (not (get paid installment)) ERR_ALREADY_EXISTS)
      (map-set installment-payments {purchase-id: purchase-id, installment-number: installment-number} (merge installment {paid: true, paid-at: stacks-block-height}))
      (map-set purchases purchase-id (merge purchase {paid-installments: (+ (get paid-installments purchase) u1)}))
      (ok (map-set users tx-sender (merge user-data {total-repaid: (+ (get total-repaid user-data) installment-amount)}))))))

(define-public (update-purchase-status (purchase-id uint) (new-status (string-ascii 20)))
  (let ((purchase (unwrap! (map-get? purchases purchase-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set purchases purchase-id (merge purchase {status: new-status})))))

(define-public (update-credit-score (user principal) (new-score uint))
  (let ((user-data (unwrap! (map-get? users user) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (<= new-score u850) ERR_INVALID_PARAMS)
    (ok (map-set users user (merge user-data {credit-score: new-score})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
