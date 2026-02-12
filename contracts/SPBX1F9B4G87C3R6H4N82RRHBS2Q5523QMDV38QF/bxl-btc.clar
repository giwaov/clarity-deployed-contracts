(define-constant err-unauthorized (err u401))
(define-constant err-forbidden (err u403))
(define-constant err-too-much (err u500))

(define-fungible-token bxl-btc)
(define-fungible-token bxl-btc-transit)

(define-data-var vault (optional principal) none)

(define-public (transfer
    (amount uint)
    (sender principal)
    (recipient principal)
    (memo (optional (buff 34)))
  )
  (if false
    (ok true)
    err-forbidden
  )
)

(define-read-only (get-name)
  (ok "Dao Brussels Bitcoin")
)

(define-read-only (get-symbol)
  (ok "bxlBTC")
)

(define-read-only (get-decimals)
  (ok u8)
)

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance bxl-btc who))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply bxl-btc))
)

(define-read-only (get-token-uri)
  (ok none)
)

(define-public (mint (amount uint))
  (begin
    (asserts! (is-vault-calling) err-unauthorized)
    (try! (ft-mint? bxl-btc amount tx-sender))
    (ok true)
  )
)

(define-public (lock (amount uint))
  (begin
    (asserts! (is-vault-calling) err-unauthorized)
    (try! (ft-burn? bxl-btc amount tx-sender))
    ;; mint to contract first for better post conditions
    (try! (ft-mint? bxl-btc-transit amount current-contract))
    (try! (ft-transfer? bxl-btc-transit amount current-contract tx-sender))
    (ok true)
  )
)

(define-public (unlock (amount uint))
  (begin
    (asserts! (is-vault-calling) err-unauthorized)
    (try! (ft-burn? bxl-btc-transit amount tx-sender))
    ;; mint to contract first for better post conditions
    (try! (ft-mint? bxl-btc amount current-contract))
    (try! (ft-transfer? bxl-btc amount current-contract tx-sender))
    (ok true)
  )
)

(define-public (burn
    (amount uint)
    (user principal)
  )
  (begin
    (asserts! (is-vault-calling) err-unauthorized)
    (try! (ft-burn? bxl-btc-transit amount user))
    (ok true)
  )
)

(define-private (is-vault-calling)
  (is-eq contract-caller (unwrap! (var-get vault) false))
)

;; can be called only once
(define-public (set-vault (blx-vault principal))
  (begin
    (asserts! (is-none (var-get vault)) err-forbidden)
    (var-set vault (some blx-vault))
    (ok true)
  )
)
