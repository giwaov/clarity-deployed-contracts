;; Minimal sBTC Pool - Ultra-simplified AMM
;; No as-contract complexity, basic constant product AMM

(use-trait sip-010-trait .sip-010-trait.sip-010-trait)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant SBTC_CONTRACT .test-token)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_ALREADY_INITIALIZED (err u402))
(define-constant ERR_NOT_INITIALIZED (err u403))
(define-constant ERR_ZERO_AMOUNT (err u404))
(define-constant ERR_SLIPPAGE (err u405))
(define-constant ERR_INSUFFICIENT_BALANCE (err u406))

;; Data variables
(define-data-var initialized bool false)
(define-data-var reserve-stx uint u0)
(define-data-var reserve-sbtc uint u0)
(define-data-var total-lp-supply uint u0)

;; Data maps
(define-map lp-balances principal uint)

;; Initialize pool
(define-public (initialize)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (not (var-get initialized)) ERR_ALREADY_INITIALIZED)
    (var-set initialized true)
    (ok true)
  )
)

;; Add liquidity
(define-public (add-liquidity (stx-amount uint) (sbtc-amount uint) (min-lp uint))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (> stx-amount u0) ERR_ZERO_AMOUNT)
    (asserts! (> sbtc-amount u0) ERR_ZERO_AMOUNT)

    (let (
      (current-stx (var-get reserve-stx))
      (current-sbtc (var-get reserve-sbtc))
      (current-supply (var-get total-lp-supply))
      (lp-tokens (if (is-eq current-supply u0)
                   ;; First liquidity: simple sum
                   (+ stx-amount sbtc-amount)
                   ;; Subsequent: proportional to smaller ratio
                   (let (
                     (lp-from-stx (/ (* stx-amount current-supply) current-stx))
                     (lp-from-sbtc (/ (* sbtc-amount current-supply) current-sbtc))
                   )
                     (if (<= lp-from-stx lp-from-sbtc) lp-from-stx lp-from-sbtc)
                   )))
    )
      (asserts! (>= lp-tokens min-lp) ERR_SLIPPAGE)

      ;; Transfer tokens to pool (user sends to this contract)
      (try! (stx-transfer? stx-amount tx-sender (as-contract tx-sender)))
      (try! (contract-call? SBTC_CONTRACT transfer sbtc-amount tx-sender (as-contract tx-sender) none))

      ;; Update state
      (var-set reserve-stx (+ current-stx stx-amount))
      (var-set reserve-sbtc (+ current-sbtc sbtc-amount))
      (var-set total-lp-supply (+ current-supply lp-tokens))
      (map-set lp-balances tx-sender (+ (default-to u0 (map-get? lp-balances tx-sender)) lp-tokens))

      (ok lp-tokens)
    )
  )
)

;; Remove liquidity
(define-public (remove-liquidity (lp-amount uint) (min-stx uint) (min-sbtc uint))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (> lp-amount u0) ERR_ZERO_AMOUNT)

    (let (
      (user-balance (default-to u0 (map-get? lp-balances tx-sender)))
      (current-stx (var-get reserve-stx))
      (current-sbtc (var-get reserve-sbtc))
      (current-supply (var-get total-lp-supply))
      (stx-out (/ (* lp-amount current-stx) current-supply))
      (sbtc-out (/ (* lp-amount current-sbtc) current-supply))
    )
      (asserts! (>= user-balance lp-amount) ERR_INSUFFICIENT_BALANCE)
      (asserts! (>= stx-out min-stx) ERR_SLIPPAGE)
      (asserts! (>= sbtc-out min-sbtc) ERR_SLIPPAGE)

      ;; Update state first
      (var-set reserve-stx (- current-stx stx-out))
      (var-set reserve-sbtc (- current-sbtc sbtc-out))
      (var-set total-lp-supply (- current-supply lp-amount))
      (map-set lp-balances tx-sender (- user-balance lp-amount))

      ;; Transfer tokens back to user
      (try! (as-contract (stx-transfer? stx-out tx-sender tx-sender)))
      (try! (as-contract (contract-call? SBTC_CONTRACT transfer sbtc-out tx-sender tx-sender none)))

      (ok {stx: stx-out, sbtc: sbtc-out})
    )
  )
)

;; Swap STX for sBTC
(define-public (swap-stx-for-sbtc (stx-in uint) (min-sbtc-out uint))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (> stx-in u0) ERR_ZERO_AMOUNT)

    (let (
      (current-stx (var-get reserve-stx))
      (current-sbtc (var-get reserve-sbtc))
      ;; 0.3% fee: multiply by 997, divide by 1000
      (stx-after-fee (/ (* stx-in u997) u1000))
      (sbtc-out (/ (* stx-after-fee current-sbtc) (+ current-stx stx-after-fee)))
    )
      (asserts! (>= sbtc-out min-sbtc-out) ERR_SLIPPAGE)

      ;; Transfer STX in
      (try! (stx-transfer? stx-in tx-sender (as-contract tx-sender)))

      ;; Update reserves
      (var-set reserve-stx (+ current-stx stx-in))
      (var-set reserve-sbtc (- current-sbtc sbtc-out))

      ;; Transfer sBTC out
      (try! (as-contract (contract-call? SBTC_CONTRACT transfer sbtc-out tx-sender tx-sender none)))

      (ok sbtc-out)
    )
  )
)

;; Swap sBTC for STX
(define-public (swap-sbtc-for-stx (sbtc-in uint) (min-stx-out uint))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (> sbtc-in u0) ERR_ZERO_AMOUNT)

    (let (
      (current-stx (var-get reserve-stx))
      (current-sbtc (var-get reserve-sbtc))
      ;; 0.3% fee
      (sbtc-after-fee (/ (* sbtc-in u997) u1000))
      (stx-out (/ (* sbtc-after-fee current-stx) (+ current-sbtc sbtc-after-fee)))
    )
      (asserts! (>= stx-out min-stx-out) ERR_SLIPPAGE)

      ;; Transfer sBTC in
      (try! (contract-call? SBTC_CONTRACT transfer sbtc-in tx-sender (as-contract tx-sender) none))

      ;; Update reserves
      (var-set reserve-sbtc (+ current-sbtc sbtc-in))
      (var-set reserve-stx (- current-stx stx-out))

      ;; Transfer STX out
      (try! (as-contract (stx-transfer? stx-out tx-sender tx-sender)))

      (ok stx-out)
    )
  )
)

;; Read-only functions
(define-read-only (get-reserves)
  {
    stx: (var-get reserve-stx),
    sbtc: (var-get reserve-sbtc),
    lp-supply: (var-get total-lp-supply)
  }
)

(define-read-only (get-lp-balance (account principal))
  (default-to u0 (map-get? lp-balances account))
)

(define-read-only (is-initialized)
  (var-get initialized)
)
