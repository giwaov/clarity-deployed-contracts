(define-fungible-token refundable-token)

(define-data-var token-name (string-ascii 32) "RefundableToken")
(define-data-var token-symbol (string-ascii 10) "RFT")
(define-data-var token-decimals uint u6)
(define-data-var refund-active bool true)
(define-data-var refund-deadline uint u0)
(define-data-var refund-price uint u0)

(define-map token-balances principal uint)

(define-constant err-unauthorized (err u1))
(define-constant err-insufficient-balance (err u2))
(define-constant err-refund-inactive (err u3))
(define-constant err-invalid-amount (err u4))

(define-read-only (get-name)
  (ok (var-get token-name)))

(define-read-only (get-symbol)
  (ok (var-get token-symbol)))

(define-read-only (get-decimals)
  (ok (var-get token-decimals)))

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance refundable-token account)))

(define-read-only (get-total-supply)
  (ok (ft-get-supply refundable-token)))

(define-read-only (refund-of)
  (ok (var-get refund-price)))

(define-read-only (refund-deadline-of)
  (ok (var-get refund-deadline)))

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) err-unauthorized)
    (try! (ft-transfer? refundable-token amount sender recipient))
    (ok true)))

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-caller) err-unauthorized)
    (ft-mint? refundable-token amount recipient)))

(define-public (refund (amount uint))
  (let ((caller tx-sender))
    (asserts! (var-get refund-active) err-refund-inactive)
    (asserts! (< stacks-block-height (var-get refund-deadline)) err-refund-inactive)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= (ft-get-balance refundable-token caller) amount) err-insufficient-balance)
    (ft-burn? refundable-token amount caller)))

(define-public (refund-from (from principal) (amount uint))
  (let ((caller tx-sender))
    (asserts! (var-get refund-active) err-refund-inactive)
    (asserts! (< stacks-block-height (var-get refund-deadline)) err-refund-inactive)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= (ft-get-balance refundable-token from) amount) err-insufficient-balance)
    (ft-burn? refundable-token amount from)))

(define-public (set-refund-config (price uint) (deadline uint))
  (begin
    (asserts! (is-eq tx-sender contract-caller) err-unauthorized)
    (var-set refund-price price)
    (var-set refund-deadline deadline)
    (ok true)))
