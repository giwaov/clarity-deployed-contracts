(define-fungible-token cappable-token)

(define-constant contract-owner tx-sender)
(define-data-var max-supply uint u1000000)
(define-data-var transfer-fee uint u100)
(define-data-var total-supply uint u0)

(define-map balances principal uint)

(define-constant err-insufficient-balance (err u100))
(define-constant err-max-supply (err u101))
(define-constant err-not-owner (err u102))
(define-constant err-zero-amount (err u103))
(define-constant err-insufficient-fee (err u104))

(define-read-only (get-balance (account principal))
  (default-to u0 (map-get? balances account)))

(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

(define-read-only (get-max-supply)
  (var-get max-supply))

(define-read-only (get-transfer-fee)
  (var-get transfer-fee))

(define-read-only (get-name)
  (ok "Cappable Token"))

(define-read-only (get-symbol)
  (ok "CAP"))

(define-read-only (get-decimals)
  (ok u6))

(define-public (set-max-supply (new-max uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-owner)
    (asserts! (>= new-max (var-get total-supply)) err-max-supply)
    (var-set max-supply new-max)
    (ok true)))

(define-public (set-transfer-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-owner)
    (var-set transfer-fee new-fee)
    (ok true)))

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-owner)
    (asserts! (> amount u0) err-zero-amount)
    (asserts! (<= (+ (var-get total-supply) amount) (var-get max-supply)) err-max-supply)
    (let ((sender-bal (get-balance sender))
          (recipient-bal (get-balance recipient)))
      (map-set balances recipient (+ recipient-bal amount))
      (try! (ft-mint? cappable-token amount recipient))
      (var-set total-supply (+ (var-get total-supply) amount))
      (ok true))))

(define-public (burn (amount uint))
  (let ((sender-bal (get-balance tx-sender)))
    (asserts! (> amount u0) err-zero-amount)
    (asserts! (>= sender-bal amount) err-insufficient-balance)
    (try! (ft-burn? cappable-token amount tx-sender))
    (map-set balances tx-sender (- sender-bal amount))
    (var-set total-supply (- (var-get total-supply) amount))
    (ok true)))

(define-public (withdraw-fees (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-owner)
    (ok true)))

(define-read-only (get-contract-hash)
  (contract-hash? .cappable-token))

(define-read-only (get-block-time)
  stacks-block-time)
