;; token-minter-v-0-1

(use-trait sip-010-trait .sip-010-trait-ft-standard-v-0-0.sip-010-trait)

(define-constant ERR_USER_ALREADY_MINTED (err u9000))
(define-constant ERR_NOT_AUTHORIZED (err u9001))
(define-constant ERR_TOKEN_MINT_AMOUNT_NOT_SET (err u9002))

(define-constant CONTRACT_DEPLOYER tx-sender)

(define-map token-mint-amount principal uint)

(define-map user-minted {user: principal, token-trait: principal} bool)

(define-read-only (get-token-mint-amount (token-trait <sip-010-trait>))
  (ok (default-to u0 (map-get? token-mint-amount (contract-of token-trait))))
)

(define-read-only (get-user-minted (user principal) (token-trait <sip-010-trait>))
  (ok (default-to false (map-get? user-minted {user: user, token-trait: (contract-of token-trait)})))
)

(define-public (set-token-mint-amount (token-trait <sip-010-trait>) (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_DEPLOYER) ERR_NOT_AUTHORIZED)
    (map-set token-mint-amount (contract-of token-trait) amount)
    (ok true)
  )
)

(define-public (set-user-minted (user principal) (token-trait <sip-010-trait>) (minted bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_DEPLOYER) ERR_NOT_AUTHORIZED)
    (map-set user-minted {user: user, token-trait: (contract-of token-trait)} minted)
    (ok true)
  )
)

(define-public (mint (token-trait <sip-010-trait>))
  (let (
    (token-contract (contract-of token-trait))
    (mint-amount (default-to u0 (map-get? token-mint-amount token-contract)))
    (caller tx-sender)
  )
    (begin
      (asserts! (is-none (map-get? user-minted {user: caller, token-trait: token-contract})) ERR_USER_ALREADY_MINTED)
      (asserts! (> mint-amount u0) ERR_TOKEN_MINT_AMOUNT_NOT_SET)
      (map-set user-minted {user: caller, token-trait: token-contract} true)
      (try! (as-contract (contract-call? token-trait transfer mint-amount tx-sender caller none)))
      (ok true)
    )
  )
)

(define-public (set-token-mint-amount-multi (token-traits (list 120 <sip-010-trait>)) (amounts (list 120 uint)))
  (ok (map set-token-mint-amount token-traits amounts))
)

(define-public (set-user-minted-multi (users (list 120 principal)) (token-traits (list 120 <sip-010-trait>)) (minted (list 120 bool)))
  (ok (map set-user-minted users token-traits minted))
)

(try! (set-token-mint-amount .token-tstx-v-0-2 u100000000000))
(try! (set-token-mint-amount .token-tusdc-v-0-2 u100000000000))
(try! (set-token-mint-amount .token-tbtc-v-0-2 u10000000))
(try! (set-token-mint-amount .token-tdog-v-0-2 u88980600000))
(try! (set-token-mint-amount .token-tusdh-v-0-1 u100000000000))