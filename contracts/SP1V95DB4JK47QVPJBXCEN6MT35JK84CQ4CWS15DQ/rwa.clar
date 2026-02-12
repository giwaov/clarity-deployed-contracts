(define-fungible-token rwa)

(define-data-var total-supply uint u0)

(define-map balances principal uint)
(define-map frozen-tokens principal uint)
(define-map can-transact-list principal bool)

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-cannot-transact (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-frozen (err u103))

(define-read-only (get-balance (account principal))
  (default-to u0 (map-get? balances account)))

(define-read-only (get-frozen-tokens (account principal))
  (default-to u0 (map-get? frozen-tokens account)))

(define-read-only (can-transact (account principal))
  (default-to true (map-get? can-transact-list account)))

(define-read-only (can-transfer (from principal) (to principal) (amount uint))
  (let ((from-balance (get-balance from))
        (frozen (get-frozen-tokens from)))
    (and (can-transact from)
         (can-transact to)
         (>= (- from-balance frozen) amount))))

(define-public (mint (account principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-owner)
    (try! (ft-mint? rwa amount account))
    (map-set balances account (+ (get-balance account) amount))
    (var-set total-supply (+ (var-get total-supply) amount))
    (ok true)))

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (let ((sender-balance (get-balance sender))
        (frozen (get-frozen-tokens sender)))
    (asserts! (is-eq tx-sender sender) err-not-owner)
    (asserts! (can-transfer sender recipient amount) err-cannot-transact)
    (asserts! (>= (- sender-balance frozen) amount) err-frozen)
    (try! (ft-transfer? rwa amount sender recipient))
    (map-set balances sender (- sender-balance amount))
    (map-set balances recipient (+ (get-balance recipient) amount))
    (ok true)))

(define-public (forced-transfer (from principal) (to principal) (amount uint))
  (let ((from-balance (get-balance from)))
    (asserts! (is-eq tx-sender contract-owner) err-not-owner)
    (try! (ft-transfer? rwa amount from to))
    (map-set balances from (- from-balance amount))
    (map-set balances to (+ (get-balance to) amount))
    (ok true)))

(define-public (set-frozen-tokens (account principal) (amount uint) (frozen-status bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-owner)
    (if frozen-status
      (map-set frozen-tokens account amount)
      (map-delete frozen-tokens account))
    (ok true)))

(define-public (set-can-transact (account principal) (status bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-owner)
    (map-set can-transact-list account status)
    (ok true)))

(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

(define-read-only (get-name)
  (ok "Real World Asset"))

(define-read-only (get-symbol)
  (ok "RWA"))

(define-read-only (get-decimals)
  (ok u6))

(define-read-only (get-contract-hash)
  (contract-hash? .rwa))

(define-read-only (get-block-time)
  stacks-block-time)
