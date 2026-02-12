(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u500))
(define-constant ERR_INSUFFICIENT_BALANCE (err u501))
(define-constant ERR_TOKEN_NOT_FOUND (err u502))
(define-constant ERR_MAX_TOKENS_REACHED (err u503))

(define-fungible-token revenue-token)

(define-data-var max-token-rewards uint u10)
(define-data-var token-count uint u0)

(define-map reward-tokens
  uint
  principal
)

(define-map reward-per-share
  principal
  uint
)

(define-map user-information
  {token: principal, account: principal}
  {in-reward: uint, out-reward: uint, withdraw: uint}
)

(define-map token-exists
  principal
  bool
)

(define-read-only (get-contract-hash)
  (contract-hash? .revenue-sharing)
)

(define-read-only (max-token-reward)
  (ok (var-get max-token-rewards))
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance revenue-token account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply revenue-token))
)

(define-read-only (information-of (token principal) (account principal))
  (ok (default-to 
    {in-reward: u0, out-reward: u0, withdraw: u0}
    (map-get? user-information {token: token, account: account})
  ))
)

(define-read-only (token-reward)
  (let
    (
      (count (var-get token-count))
    )
    (ok (map get-reward-token-at (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9)))
  )
)

(define-private (get-reward-token-at (index uint))
  (default-to tx-sender (map-get? reward-tokens index))
)

(define-read-only (get-reward-per-share (token principal))
  (ok (default-to u0 (map-get? reward-per-share token)))
)

(define-read-only (exists-token-reward (token principal))
  (ok (default-to false (map-get? token-exists token)))
)

(define-public (add-reward-token (token principal))
  (let
    (
      (current-count (var-get token-count))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (< current-count (var-get max-token-rewards)) ERR_MAX_TOKENS_REACHED)
    (asserts! (not (unwrap-panic (exists-token-reward token))) ERR_TOKEN_NOT_FOUND)
    (map-set reward-tokens current-count token)
    (map-set token-exists token true)
    (var-set token-count (+ current-count u1))
    (ok true)
  )
)

(define-public (update-reward (tokens (list 10 principal)) (amounts (list 10 uint)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (len tokens) (len amounts)) ERR_NOT_AUTHORIZED)
    (ok (map update-single-reward tokens amounts))
  )
)

(define-private (update-single-reward (token principal) (amount uint))
  (let
    (
      (total-supply (unwrap-panic (get-total-supply)))
      (current-rps (default-to u0 (map-get? reward-per-share token)))
    )
    (if (> total-supply u0)
      (begin
        (map-set reward-per-share token 
          (+ current-rps (/ amount total-supply))
        )
        true
      )
      false
    )
  )
)

(define-read-only (view-reward (account principal))
  (let
    (
      (count (var-get token-count))
    )
    (ok (map calculate-reward-for-token (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9)))
  )
)

(define-private (calculate-reward-for-token (index uint))
  (let
    (
      (token (default-to tx-sender (map-get? reward-tokens index)))
    )
    u0
  )
)

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ft-mint? revenue-token amount recipient)
  )
)

(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    (ft-transfer? revenue-token amount sender recipient)
  )
)

(define-read-only (verify-signature (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (ok (secp256r1-verify message signature public-key))
)

(define-read-only (get-block-timestamp)
  stacks-block-time
)
