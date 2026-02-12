(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1500))
(define-constant ERR_INSUFFICIENT_RESERVE (err u1501))
(define-constant ERR_INVALID_RATIO (err u1502))

(define-fungible-token fractional-reserve-token)

(define-data-var required-reserve-ratio uint u50)
(define-data-var total-reserve uint u0)
(define-data-var total-borrowed uint u0)

(define-map segregated-balances
  principal
  {normal-balance: uint, borrowed-balance: uint}
)

(define-map reserve-deposits
  principal
  uint
)

(define-read-only (get-contract-hash)
  (contract-hash? .fractional-reserve-fungible-token)
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance fractional-reserve-token account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply fractional-reserve-token))
)

(define-read-only (get-required-reserve-ratio)
  (ok (var-get required-reserve-ratio))
)

(define-read-only (get-segregated-balance (account principal))
  (ok (default-to {normal-balance: u0, borrowed-balance: u0} (map-get? segregated-balances account)))
)

(define-public (set-reserve-ratio (new-ratio uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-ratio u100) ERR_INVALID_RATIO)
    (var-set required-reserve-ratio new-ratio)
    (ok true)
  )
)

(define-public (fractional-reserve-mint (amount uint) (recipient principal))
  (let
    (
      (current-reserve (var-get total-reserve))
      (required-reserve (/ (* amount (var-get required-reserve-ratio)) u100))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (>= current-reserve required-reserve) ERR_INSUFFICIENT_RESERVE)
    (try! (ft-mint? fractional-reserve-token amount recipient))
    (let
      (
        (account-data (default-to {normal-balance: u0, borrowed-balance: u0} (map-get? segregated-balances recipient)))
      )
      (map-set segregated-balances recipient (merge account-data {
        normal-balance: (+ (get normal-balance account-data) amount)
      }))
    )
    (ok true)
  )
)

(define-public (fractional-reserve-burn (amount uint))
  (let
    (
      (account-data (default-to {normal-balance: u0, borrowed-balance: u0} (map-get? segregated-balances tx-sender)))
    )
    (asserts! (>= (ft-get-balance fractional-reserve-token tx-sender) amount) ERR_INSUFFICIENT_RESERVE)
    (try! (ft-burn? fractional-reserve-token amount tx-sender))
    (map-set segregated-balances tx-sender (merge account-data {
      normal-balance: (if (>= (get normal-balance account-data) amount)
        (- (get normal-balance account-data) amount)
        u0)
    }))
    (ok true)
  )
)

(define-public (deposit-reserve (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender CONTRACT_OWNER))
    (var-set total-reserve (+ (var-get total-reserve) amount))
    (map-set reserve-deposits tx-sender 
      (+ (default-to u0 (map-get? reserve-deposits tx-sender)) amount)
    )
    (ok true)
  )
)

(define-public (withdraw-reserve (amount uint))
  (let
    (
      (deposited (default-to u0 (map-get? reserve-deposits tx-sender)))
    )
    (asserts! (>= deposited amount) ERR_INSUFFICIENT_RESERVE)
    (try! (stx-transfer? amount CONTRACT_OWNER tx-sender))
    (var-set total-reserve (- (var-get total-reserve) amount))
    (map-set reserve-deposits tx-sender (- deposited amount))
    (ok true)
  )
)

(define-public (mint-borrowed (amount uint) (recipient principal))
  (let
    (
      (current-reserve (var-get total-reserve))
      (required-reserve (/ (* amount (var-get required-reserve-ratio)) u100))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (>= current-reserve required-reserve) ERR_INSUFFICIENT_RESERVE)
    (try! (ft-mint? fractional-reserve-token amount recipient))
    (var-set total-borrowed (+ (var-get total-borrowed) amount))
    (let
      (
        (account-data (default-to {normal-balance: u0, borrowed-balance: u0} (map-get? segregated-balances recipient)))
      )
      (map-set segregated-balances recipient (merge account-data {
        borrowed-balance: (+ (get borrowed-balance account-data) amount)
      }))
    )
    (ok true)
  )
)

(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    (ft-transfer? fractional-reserve-token amount sender recipient)
  )
)

(define-read-only (verify-secp256r1-signature (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (ok (secp256r1-verify message signature public-key))
)

(define-read-only (get-block-time)
  stacks-block-time
)

(define-read-only (asset-check)
  (ok (is-ok (contract-hash? .fractional-reserve-fungible-token)))
)
