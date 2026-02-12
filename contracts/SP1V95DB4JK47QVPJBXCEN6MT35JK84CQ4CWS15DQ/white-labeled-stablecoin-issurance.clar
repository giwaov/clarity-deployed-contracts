(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))

(define-data-var contract-owner principal tx-sender)

(define-map stablecoin-issuers principal {issuer-name: (string-ascii 100), licensed: bool, total-issued: uint, collateral-ratio: uint, active: bool})
(define-map token-balances {issuer: principal, holder: principal} uint)
(define-map reserve-assets {issuer: principal, asset-type: (string-ascii 30)} {amount: uint, last-updated: uint})
(define-map compliance-records {issuer: principal, period: uint} {audited: bool, compliant: bool, audit-hash: (buff 32)})

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-issuer (issuer-id principal))
  (map-get? stablecoin-issuers issuer-id))

(define-read-only (get-balance (issuer principal) (holder principal))
  (default-to u0 (map-get? token-balances {issuer: issuer, holder: holder})))

(define-read-only (get-reserve (issuer principal) (asset-type (string-ascii 30)))
  (map-get? reserve-assets {issuer: issuer, asset-type: asset-type}))

(define-read-only (get-compliance (issuer principal) (period uint))
  (map-get? compliance-records {issuer: issuer, period: period}))

(define-public (register-issuer (issuer-name (string-ascii 100)) (collateral-ratio uint))
  (begin
    (asserts! (is-none (map-get? stablecoin-issuers tx-sender)) ERR_ALREADY_EXISTS)
    (asserts! (>= collateral-ratio u100) ERR_INVALID_PARAMS)
    (ok (map-set stablecoin-issuers tx-sender {issuer-name: issuer-name, licensed: false, total-issued: u0, collateral-ratio: collateral-ratio, active: true}))))

(define-public (license-issuer (issuer principal))
  (let ((issuer-data (unwrap! (map-get? stablecoin-issuers issuer) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set stablecoin-issuers issuer (merge issuer-data {licensed: true})))))

(define-public (mint-stablecoin (amount uint) (recipient principal))
  (let ((issuer-data (unwrap! (map-get? stablecoin-issuers tx-sender) ERR_UNAUTHORIZED))
        (current-balance (get-balance tx-sender recipient)))
    (asserts! (get licensed issuer-data) ERR_UNAUTHORIZED)
    (asserts! (get active issuer-data) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_PARAMS)
    (map-set token-balances {issuer: tx-sender, holder: recipient} (+ current-balance amount))
    (ok (map-set stablecoin-issuers tx-sender (merge issuer-data {total-issued: (+ (get total-issued issuer-data) amount)})))))

(define-public (burn-stablecoin (issuer principal) (amount uint))
  (let ((issuer-data (unwrap! (map-get? stablecoin-issuers issuer) ERR_NOT_FOUND))
        (current-balance (get-balance issuer tx-sender)))
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (> amount u0) ERR_INVALID_PARAMS)
    (map-set token-balances {issuer: issuer, holder: tx-sender} (- current-balance amount))
    (ok (map-set stablecoin-issuers issuer (merge issuer-data {total-issued: (- (get total-issued issuer-data) amount)})))))

(define-public (transfer-stablecoin (issuer principal) (amount uint) (recipient principal))
  (let ((sender-balance (get-balance issuer tx-sender))
        (recipient-balance (get-balance issuer recipient)))
    (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (> amount u0) ERR_INVALID_PARAMS)
    (map-set token-balances {issuer: issuer, holder: tx-sender} (- sender-balance amount))
    (ok (map-set token-balances {issuer: issuer, holder: recipient} (+ recipient-balance amount)))))

(define-public (deposit-reserve (asset-type (string-ascii 30)) (amount uint))
  (let ((reserve (default-to {amount: u0, last-updated: u0} (map-get? reserve-assets {issuer: tx-sender, asset-type: asset-type}))))
    (asserts! (is-some (map-get? stablecoin-issuers tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_PARAMS)
    (ok (map-set reserve-assets {issuer: tx-sender, asset-type: asset-type} {amount: (+ (get amount reserve) amount), last-updated: stacks-block-height}))))

(define-public (record-compliance (period uint) (audit-hash (buff 32)) (compliant bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set compliance-records {issuer: tx-sender, period: period} {audited: true, compliant: compliant, audit-hash: audit-hash}))))

(define-public (deactivate-issuer (issuer principal))
  (let ((issuer-data (unwrap! (map-get? stablecoin-issuers issuer) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set stablecoin-issuers issuer (merge issuer-data {active: false})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
