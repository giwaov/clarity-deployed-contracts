;; token-tusdc-v-0-2

(impl-trait .sip-010-trait-ft-standard-v-0-0.sip-010-trait)

(define-fungible-token tUSDC)

(define-constant ERR_USER_ALREADY_MINTED (err u9000))
(define-constant ERR_NOT_AUTHORIZED (err u9001))

(define-constant CONTRACT_DEPLOYER tx-sender)

(define-constant DEPLOY_MINT_AMOUNT u2000000000000)

(define-data-var user-mint-amount uint u100000000000)

(define-map user-minted principal bool)

(define-read-only (get-name)
  (ok "Test USDC Token")
)

(define-read-only (get-symbol)
  (ok "tUSDC")
)

(define-read-only (get-decimals)
  (ok u6)
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance tUSDC account))
)

(define-read-only (get-balance-simple (account principal))
  (ft-get-balance tUSDC account)
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply tUSDC))
)

(define-read-only (get-token-uri)
  (ok (some u""))
)

(define-read-only (get-user-mint-amount)
  (ok (var-get user-mint-amount))
)

(define-read-only (get-user-minted (account principal))
  (ok (default-to false (map-get? user-minted account)))
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err u1001))

    (match (ft-transfer? tUSDC amount sender recipient)
      response (begin
        (print memo)
        (ok response)
      )
      error (err error)
    )
  )
)

(define-public (set-user-mint-amount (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_DEPLOYER) ERR_NOT_AUTHORIZED)
    (var-set user-mint-amount amount)
    (ok true)
  )
)

(define-public (mint)
  (begin
    (asserts! (is-none (map-get? user-minted tx-sender)) ERR_USER_ALREADY_MINTED)
    (map-set user-minted tx-sender true)
    (ft-mint? tUSDC (var-get user-mint-amount) tx-sender)
  )
)

(define-public (admin-mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_DEPLOYER) ERR_NOT_AUTHORIZED)
    (ft-mint? tUSDC amount recipient)
  )
)

(define-public (burn (amount uint))
  (begin
    (ft-burn? tUSDC amount tx-sender)
  )
)

(ft-mint? tUSDC DEPLOY_MINT_AMOUNT CONTRACT_DEPLOYER)