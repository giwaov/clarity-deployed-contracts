(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map curated-tokens uint {token-contract: principal, symbol: (string-ascii 10), curator: principal, rating: uint, category: (string-ascii 50), curated-at: uint, active: bool})
(define-map curators principal {curator-name: (string-ascii 100), reputation: uint, tokens-curated: uint, verified: bool})
(define-map curator-votes {token-id: uint, curator: principal} {vote: bool, weight: uint, voted-at: uint})
(define-map token-metrics {token-id: uint, metric-type: (string-ascii 30)} uint)
(define-data-var token-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-curated-token (token-id uint))
  (map-get? curated-tokens token-id))

(define-read-only (get-curator (curator-id principal))
  (map-get? curators curator-id))

(define-read-only (get-curator-vote (token-id uint) (curator principal))
  (map-get? curator-votes {token-id: token-id, curator: curator}))

(define-read-only (get-token-metric (token-id uint) (metric-type (string-ascii 30)))
  (map-get? token-metrics {token-id: token-id, metric-type: metric-type}))

(define-public (register-curator (curator-name (string-ascii 100)))
  (begin
    (asserts! (is-none (map-get? curators tx-sender)) ERR_ALREADY_EXISTS)
    (ok (map-set curators tx-sender {curator-name: curator-name, reputation: u50, tokens-curated: u0, verified: false}))))

(define-public (verify-curator (curator principal))
  (let ((curator-data (unwrap! (map-get? curators curator) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set curators curator (merge curator-data {verified: true})))))

(define-public (curate-token (token-contract principal) (symbol (string-ascii 10)) (rating uint) (category (string-ascii 50)))
  (let ((token-id (+ (var-get token-count) u1))
        (curator-data (unwrap! (map-get? curators tx-sender) ERR_UNAUTHORIZED)))
    (asserts! (get verified curator-data) ERR_UNAUTHORIZED)
    (asserts! (<= rating u100) ERR_INVALID_PARAMS)
    (map-set curated-tokens token-id {token-contract: token-contract, symbol: symbol, curator: tx-sender, rating: rating, category: category, curated-at: stacks-block-height, active: true})
    (map-set curators tx-sender (merge curator-data {tokens-curated: (+ (get tokens-curated curator-data) u1)}))
    (var-set token-count token-id)
    (ok token-id)))

(define-public (vote-on-token (token-id uint) (vote bool) (weight uint))
  (let ((curator-data (unwrap! (map-get? curators tx-sender) ERR_UNAUTHORIZED))
        (token (unwrap! (map-get? curated-tokens token-id) ERR_NOT_FOUND)))
    (asserts! (get verified curator-data) ERR_UNAUTHORIZED)
    (asserts! (get active token) ERR_INVALID_PARAMS)
    (asserts! (is-none (map-get? curator-votes {token-id: token-id, curator: tx-sender})) ERR_ALREADY_EXISTS)
    (asserts! (<= weight u10) ERR_INVALID_PARAMS)
    (ok (map-set curator-votes {token-id: token-id, curator: tx-sender} {vote: vote, weight: weight, voted-at: stacks-block-height}))))

(define-public (update-token-rating (token-id uint) (new-rating uint))
  (let ((token (unwrap! (map-get? curated-tokens token-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get curator token)) ERR_UNAUTHORIZED)
    (asserts! (<= new-rating u100) ERR_INVALID_PARAMS)
    (ok (map-set curated-tokens token-id (merge token {rating: new-rating})))))

(define-public (record-metric (token-id uint) (metric-type (string-ascii 30)) (value uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? curated-tokens token-id)) ERR_NOT_FOUND)
    (ok (map-set token-metrics {token-id: token-id, metric-type: metric-type} value))))

(define-public (update-curator-reputation (curator principal) (new-reputation uint))
  (let ((curator-data (unwrap! (map-get? curators curator) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (<= new-reputation u100) ERR_INVALID_PARAMS)
    (ok (map-set curators curator (merge curator-data {reputation: new-reputation})))))

(define-public (delist-token (token-id uint))
  (let ((token (unwrap! (map-get? curated-tokens token-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set curated-tokens token-id (merge token {active: false})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
