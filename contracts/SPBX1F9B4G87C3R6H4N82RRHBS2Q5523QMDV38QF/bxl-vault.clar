(define-constant err-unauthorized (err u401))
(define-constant err-forbidden (err u403))
(define-constant err-not-found (err u404))
(define-constant err-invalid-amount (err u500))
(define-constant err-no-balance (err u501))
(define-constant max-stacking-amount u1000000000000000)

(define-map admins
  principal
  bool
)
(map-set admins tx-sender true)

(define-data-var last-request-id uint u0)
(define-map withdrawal-requests
  uint
  {
    user: principal,
    amount: uint,
    opens-at: uint,
  }
)
(define-map withdrawal-requests-by-user
  principal
  uint
)

(define-public (deposit (amount uint))
  (begin
    (try! (send-sbtc-to-vault amount))
    (try! (contract-call? .bxl-btc mint amount))
    (ok true)
  )
)

(define-public (withdraw-request
    (amount uint)
    (delay uint)
  )
  (let ((request-id (+ (var-get last-request-id) u1)))
    (asserts! (> amount u0) err-invalid-amount)
    (try! (contract-call? .bxl-btc lock amount))
    (map-set withdrawal-requests request-id {
      user: tx-sender,
      amount: amount,
      opens-at: (+ burn-block-height
        (if (< delay u1000)
          u1000
          delay
        )),
    })
    ;; ensure only one active request per user
    (asserts! (map-insert withdrawal-requests-by-user tx-sender request-id)
      err-forbidden
    )
    (var-set last-request-id request-id)
    (ok request-id)
  )
)

(define-public (withdraw-update
    (request-id uint)
    (amount uint)
    (delay uint)
  )
  (let (
      (details (unwrap! (map-get? withdrawal-requests request-id) err-not-found))
      (user (get user details))
    )
    (asserts! (is-eq user tx-sender) err-unauthorized)
    ;; unlock previous amount for tx-sender
    (try! (contract-call? .bxl-btc unlock (get amount details)))
    (if (is-eq amount u0)
      (begin
        (map-delete withdrawal-requests-by-user user)
        (map-delete withdrawal-requests request-id)
      )
      (begin
        ;; lock new amount for tx-sender
        (try! (contract-call? .bxl-btc lock amount))
        (map-set withdrawal-requests request-id {
          user: tx-sender,
          amount: amount,
          opens-at: (+ burn-block-height
            (if (< delay u1000)
              u1000
              delay
            )),
        })
      )
    )
    (ok request-id)
  )
)

(define-public (withdraw-finalize (request-id uint))
  (let (
      (details (unwrap! (map-get? withdrawal-requests request-id) err-not-found))
      (amount (get amount details))
      (user (get user details))
    )
    (asserts!
      (or
        (is-admin-calling)
        (> burn-block-height (get opens-at details))
      )
      err-unauthorized
    )
    (try! (contract-call? .bxl-btc burn amount user))
    (try! (send-sbtc-from-vault amount user))
    (map-delete withdrawal-requests-by-user user)
    (ok amount)
  )
)

(define-public (deposit-stx (amount uint))
  (begin
    (try! (send-stx-to-vault amount))
    (try! (contract-call? .bxl-stx mint amount))
    (ok true)
  )
)

(define-public (withdraw-stx (amount uint))
  (begin
    (try! (contract-call? .bxl-stx burn amount))
    (try! (send-stx-from-vault amount tx-sender))
    (ok true)
  )
)

(define-public (admin-sbtc-transfer
    (amount uint)
    (recipient principal)
  )
  (let (
      (sbtc-balance (unwrap!
        (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
          get-balance current-contract
        )
        err-no-balance
      ))
      (bxl-btc-supply (unwrap! (contract-call? .bxl-btc get-total-supply) err-no-balance))
    )
    (asserts! (is-admin-calling) err-unauthorized)
    (asserts! (>= sbtc-balance (+ amount bxl-btc-supply)) err-invalid-amount)
    (try! (send-sbtc-from-vault amount recipient))
    (ok true)
  )
)

(define-public (admin-stx-transfer
    (amount uint)
    (recipient principal)
  )
  (let (
      (stx-balance (stx-get-balance current-contract))
      (bxl-stx-supply (unwrap! (contract-call? .bxl-stx get-total-supply) err-no-balance))
    )
    (asserts! (is-admin-calling) err-unauthorized)
    (asserts! (>= stx-balance (+ amount bxl-stx-supply)) err-invalid-amount)
    (try! (send-stx-from-vault amount recipient))
    (ok true)
  )
)

(define-public (admin-set-admin
    (admin principal)
    (enable bool)
  )
  (begin
    (asserts! (is-admin-calling) err-unauthorized)
    (asserts! (not (is-eq admin tx-sender)) err-forbidden)
    (map-set admins admin enable)
    (ok true)
  )
)

;; Dual Stacking

;; sbtc rewards go to this vault
(define-public (enroll)
  (as-contract? ()
    (try! (contract-call? 'SP1HFCRKEJ8BYW4D0E3FAWHFDX8A25PPAA83HWWZ9.dual-stacking-v1
      enroll none
    ))
  )
)

(define-public (delegate-stx)
  (begin
    (asserts! (is-admin-calling) err-unauthorized)
    (as-contract? ((with-stacking max-stacking-amount))
      (try! (contract-call?
        'SPMPMA1V6P430M8C91QS1G9XJ95S59JS1TZFZ4Q4.pox4-multi-pool-v1
        delegate-stx max-stacking-amount
        (unwrap-panic (to-consensus-buff? {
          v: u1,
          c: "sbtc",
          s: "bxl-vault",
        }))
      ))
    )
  )
)

(define-public (revoke-delegate-stx)
  (begin
    (asserts! (is-admin-calling) err-unauthorized)
    (as-contract? ()
      (try! (match (contract-call? 'SP000000000000000000002Q6VF78.pox-4 revoke-delegate-stx)
        success (ok success)
        failure (err (to-uint failure))
      ))
    )
  )
)

;; private functions

(define-private (is-admin-calling)
  (default-to false (map-get? admins tx-sender))
)

(define-private (send-sbtc-to-vault (amount uint))
  (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer
    amount tx-sender current-contract none
  )
)

(define-private (send-sbtc-from-vault
    (amount uint)
    (recipient principal)
  )
  (as-contract?
    ((with-ft 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token "sbtc-token"
      amount
    ))
    (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      transfer amount tx-sender recipient none
    ))
  )
)

(define-private (send-stx-to-vault (amount uint))
  (stx-transfer? amount tx-sender current-contract)
)

(define-private (send-stx-from-vault
    (amount uint)
    (recipient principal)
  )
  (as-contract? ((with-stx amount))
    (try! (stx-transfer? amount current-contract recipient))
  )
)

;; initialize the bxl-btc and bxl-stx contracts to point to this vault
(try! (contract-call? .bxl-btc set-vault current-contract))
(try! (contract-call? .bxl-stx set-vault current-contract))

;; allow fast pool v2
(try! (as-contract? ()
  (try! (contract-call? 'SP000000000000000000002Q6VF78.pox-4 allow-contract-caller
    'SPMPMA1V6P430M8C91QS1G9XJ95S59JS1TZFZ4Q4.pox4-multi-pool-v1 none
  ))
))
