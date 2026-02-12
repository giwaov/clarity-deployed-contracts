(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-amount (err u103))

(define-fungible-token etf-token)

(define-map asset-weights principal uint)
(define-map total-assets-held principal uint)
(define-data-var total-supply uint u0)
(define-data-var management-fee uint u100)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance etf-token account)))

(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

(define-read-only (get-asset-weight (asset principal))
  (ok (default-to u0 (map-get? asset-weights asset))))

(define-public (set-asset-weight (asset principal) (weight uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set asset-weights asset weight))))

(define-public (mint (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (try! (ft-mint? etf-token amount tx-sender))
    (var-set total-supply (+ (var-get total-supply) amount))
    (ok true)))

(define-public (burn (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (try! (ft-burn? etf-token amount tx-sender))
    (var-set total-supply (- (var-get total-supply) amount))
    (ok true)))

(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-owner-only)
    (ft-transfer? etf-token amount sender recipient)))

(define-public (rebalance (asset principal) (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set total-assets-held asset new-amount))))
