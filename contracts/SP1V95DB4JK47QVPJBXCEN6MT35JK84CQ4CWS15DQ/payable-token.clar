(define-trait payable-token-trait
  ((transfer (uint principal principal uint) (response bool uint))
   (approve (principal uint) (response bool uint))
   (transfer-from (principal principal uint) (response bool uint))
   (allowance (principal principal) (response uint uint))
   (balance-of (principal) (response uint uint))
   (total-supply () (response uint uint))
   (on-transfer-received (principal principal uint (optional (buff 34))) (response bool uint))
   (on-approval-received (principal uint (optional (buff 34))) (response bool uint))))

(define-constant token-name u"PayableToken")
(define-constant token-symbol u"PAYT")
(define-constant token-decimals u6)
(define-data-var total-supply-var uint u0)
(define-map balances principal uint)
(define-map allowances {owner: principal, spender: principal} uint)


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

(define-public (approve (spender principal) (amount uint))
  (let ((owner tx-sender))
    (map-set allowances {owner: owner, spender: spender} amount)
    (ok true)))

(define-public (transfer-from (owner principal) (recipient principal) (amount uint))
  (let ((allow (default-to u0 (map-get? allowances {owner: owner, spender: tx-sender})))
        (owner-balance (default-to u0 (map-get? balances owner))))
    (if (and (>= allow amount) (>= owner-balance amount))
        (begin
          (map-set allowances {owner: owner, spender: tx-sender} (- allow amount))
          (map-set balances owner (- owner-balance amount))
          (map-set balances recipient (+ (default-to u0 (map-get? balances recipient)) amount))
          (ok true))
        (err u101))))


(define-private (get-allowance (owner principal) (spender principal))
  (default-to u0 (map-get? allowances {owner: owner, spender: spender})))

(define-private (get-balance (owner principal))
  (default-to u0 (map-get? balances owner)))


(define-read-only (allowance (owner principal) (spender principal))
  (ok (get-allowance owner spender)))

(define-read-only (balance-of (owner principal))
  (ok (get-balance owner)))


(define-read-only (total-supply)
  (ok (var-get total-supply-var)))

(define-public (on-transfer-received (operator principal) (from principal) (amount uint) (data (optional (buff 34))))
  (ok true))

(define-public (on-approval-received (owner principal) (amount uint) (data (optional (buff 34))))
  (ok true))



(define-private (do-mint (recipient principal) (amount uint))
  (begin
    (var-set total-supply-var (+ (var-get total-supply-var) amount))
    (map-set balances recipient (+ (get-balance recipient) amount))
    true))

(define-public (mint (recipient principal) (amount uint))
  (begin
    (do-mint recipient amount)
    (ok true)))



