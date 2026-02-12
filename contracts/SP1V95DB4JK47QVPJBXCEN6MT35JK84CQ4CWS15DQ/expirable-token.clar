(define-fungible-token expirable-token)

(define-constant contract-owner tx-sender)
(define-constant epoch-length u1000)
(define-constant validity-duration u5)

(define-data-var total-supply uint u0)
(define-map epoch-balances {epoch: uint, account: principal} uint)
(define-map epoch-start uint uint)

(define-constant err-insufficient-balance (err u100))
(define-constant err-expired-epoch (err u101))
(define-constant err-zero-amount (err u102))

(define-read-only (get-current-epoch)
  (/ stacks-block-time epoch-length))

(define-read-only (is-epoch-expired (epoch uint))
  (> (get-current-epoch) (+ epoch validity-duration)))

(define-read-only (get-balance-at-epoch (epoch uint) (account principal))
  (if (is-epoch-expired epoch)
    u0
    (default-to u0 (map-get? epoch-balances {epoch: epoch, account: account}))))

(define-read-only (get-balance (account principal))
  (let ((current (get-current-epoch)))
    (fold + (map get-valid-epoch-balance 
      (list (- current u0) (- current u1) (- current u2) (- current u3) (- current u4))) u0)))

(define-private (get-valid-epoch-balance (offset uint))
  (let ((current (get-current-epoch)))
    (if (<= offset current)
      (get-balance-at-epoch (- current offset) tx-sender)
      u0)))

(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

(define-read-only (get-epoch-length)
  epoch-length)

(define-read-only (get-validity-duration)
  validity-duration)

(define-read-only (get-epoch-type)
  "TIME_BASED")

(define-public (mint (amount uint) (recipient principal))
  (let ((current-epoch (get-current-epoch))
        (current-balance (default-to u0 (map-get? epoch-balances {epoch: current-epoch, account: recipient}))))
    (asserts! (> amount u0) err-zero-amount)
    (try! (ft-mint? expirable-token amount recipient))
    (map-set epoch-balances {epoch: current-epoch, account: recipient} (+ current-balance amount))
    (var-set total-supply (+ (var-get total-supply) amount))
    (ok true)))

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (let ((current-epoch (get-current-epoch)))
    (asserts! (is-eq tx-sender sender) err-insufficient-balance)
    (asserts! (>= (get-balance sender) amount) err-insufficient-balance)
    (try! (transfer-at-epoch current-epoch amount sender recipient))
    (ok true)))

(define-public (transfer-at-epoch (epoch uint) (amount uint) (sender principal) (recipient principal))
  (let ((sender-balance (get-balance-at-epoch epoch sender))
        (recipient-balance (get-balance-at-epoch epoch recipient)))
    (asserts! (is-eq tx-sender sender) err-insufficient-balance)
    (asserts! (not (is-epoch-expired epoch)) err-expired-epoch)
    (asserts! (>= sender-balance amount) err-insufficient-balance)
    (map-set epoch-balances {epoch: epoch, account: sender} (- sender-balance amount))
    (map-set epoch-balances {epoch: epoch, account: recipient} (+ recipient-balance amount))
    (ok true)))

(define-read-only (get-contract-hash)
  (contract-hash? .expirable-token))

(define-read-only (get-block-time)
  stacks-block-time)
