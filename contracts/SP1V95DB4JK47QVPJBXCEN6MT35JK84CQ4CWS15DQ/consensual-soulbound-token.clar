(define-trait soulbound-token-trait
  ((mint (principal uint) (response bool uint))
   (burn (principal) (response bool uint))
   (owner-of (uint) (response (optional principal) uint))
   (balance-of (principal) (response uint uint))))

(define-constant token-name u"ConsensualSoulboundToken")
(define-constant token-symbol u"CSBT")
(define-constant token-decimals u0)
(define-data-var total-supply-var uint u0)
(define-map balances principal uint)
(define-map owners uint principal)


(define-private (is-restricted) true)
(define-read-only (get-restrict-assets) (is-restricted))


(define-private (get-owner (token-id uint))
  (map-get? owners token-id))

(define-private (get-balance (owner principal))
  (default-to u0 (map-get? balances owner)))

(define-private (do-mint (recipient principal) (token-id uint))
  (begin
    (map-set owners token-id recipient)
    (map-set balances recipient (+ (get-balance recipient) u1))
    (var-set total-supply-var (+ (var-get total-supply-var) u1))
    true))

(define-public (mint (recipient principal) (token-id uint))
  (if (is-none (get-owner token-id))
      (begin
        (do-mint recipient token-id)
        (ok true))
      (err u100)))


(define-private (do-burn (owner-principal principal) (token-id uint))
  (begin
    (map-delete owners token-id)
    (map-set balances owner-principal (- (get-balance owner-principal) u1))
    (var-set total-supply-var (- (var-get total-supply-var) u1))
    true))

(define-public (burn (token-id uint))
  (let ((owner (get-owner token-id)))
    (if (is-some owner)
        (let ((owner-principal (unwrap! owner (err u101))))
          (do-burn owner-principal token-id)
          (ok true))
        (err u102))))


(define-read-only (owner-of (token-id uint))
  (ok (get-owner token-id)))

(define-read-only (balance-of (owner principal))
  (ok (get-balance owner)))



