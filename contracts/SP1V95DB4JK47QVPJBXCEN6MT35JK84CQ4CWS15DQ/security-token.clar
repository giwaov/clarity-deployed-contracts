(define-trait security-token-trait
  ((transfer (principal principal uint) (response bool uint))
   (balance-of (principal) (response uint uint))
   (total-supply () (response uint uint))
   (mint (principal uint) (response bool uint))
   (burn (principal uint) (response bool uint))))

(define-constant token-name u"SecurityToken")
(define-constant token-symbol u"STKN")
(define-constant token-decimals u6)
(define-data-var total-supply-var uint u0)
(define-map balances principal uint)


(define-private (is-restricted) true)
(define-read-only (get-restrict-assets) (is-restricted))

(define-public (transfer (sender principal) (recipient principal) (amount uint))
  (let ((sender-balance (default-to u0 (map-get? balances sender))))
    (if (>= sender-balance amount)
        (begin
          (map-set balances sender (- sender-balance amount))
          (map-set balances recipient (+ (default-to u0 (map-get? balances recipient)) amount))
          (ok true))
        (err u100))))


(define-private (get-balance (owner principal))
  (default-to u0 (map-get? balances owner)))


(define-read-only (balance-of (owner principal))
  (ok (get-balance owner)))

(define-read-only (total-supply)
  (ok (var-get total-supply-var)))


(define-private (do-mint (recipient principal) (amount uint))
  (begin
    (var-set total-supply-var (+ (var-get total-supply-var) amount))
    (map-set balances recipient (+ (get-balance recipient) amount))
    true))

(define-public (mint (recipient principal) (amount uint))
  (begin
    (do-mint recipient amount)
    (ok true)))


(define-private (do-burn (owner principal) (amount uint))
  (begin
    (var-set total-supply-var (- (var-get total-supply-var) amount))
    (map-set balances owner (- (get-balance owner) amount))
    true))

(define-public (burn (owner principal) (amount uint))
  (let ((owner-balance (get-balance owner)))
    (if (>= owner-balance amount)
        (begin
          (do-burn owner amount)
          (ok true))
        (err u101))))



