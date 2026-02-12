;; token-minter-v-0-1

(use-trait sip-010-trait .sip-010-trait-ft-standard-v-0-0.sip-010-trait)

(define-constant ERR_USER_ALREADY_MINTED (err u9000))
(define-constant ERR_NOT_AUTHORIZED (err u9001))
(define-constant ERR_TOKEN_MINT_AMOUNT_NOT_SET (err u9002))

(define-constant CONTRACT_DEPLOYER tx-sender)

(define-map token-mint-amount principal uint)

(define-map user-minted principal bool)

(define-read-only (get-token-mint-amount (token-trait <sip-010-trait>))
  (ok (default-to u0 (map-get? token-mint-amount (contract-of token-trait))))
)

(define-read-only (get-user-minted (user principal))
  (ok (default-to false (map-get? user-minted user)))
)

(define-public (set-token-mint-amount (token-trait <sip-010-trait>) (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_DEPLOYER) ERR_NOT_AUTHORIZED)
    (map-set token-mint-amount (contract-of token-trait) amount)
    (ok true)
  )
)

(define-public (set-user-minted (user principal) (minted bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_DEPLOYER) ERR_NOT_AUTHORIZED)
    (map-set user-minted user minted)
    (ok true)
  )
)

(define-public (mint (token-trait <sip-010-trait>))
  (let (
    (mint-amount (default-to u0 (map-get? token-mint-amount (contract-of token-trait))))
    (caller tx-sender)
  )
    (begin
      (asserts! (is-none (map-get? user-minted caller)) ERR_USER_ALREADY_MINTED)
      (asserts! (> mint-amount u0) ERR_TOKEN_MINT_AMOUNT_NOT_SET)
      (map-set user-minted caller true)
      (try! (as-contract (contract-call? token-trait transfer mint-amount tx-sender caller none)))
      (ok true)
    )
  )
)

(define-public (set-token-mint-amount-multi (token-traits (list 120 <sip-010-trait>)) (amounts (list 120 uint)))
  (ok (map set-token-mint-amount token-traits amounts))
)

(define-public (set-user-minted-multi (users (list 120 principal)) (minted (list 120 bool)))
  (ok (map set-user-minted users minted))
)

(try! (set-token-mint-amount .token-tstx-v-0-2 u100000000000))
(try! (set-token-mint-amount .token-tusdc-v-0-2 u100000000000))
(try! (set-token-mint-amount .token-tbtc-v-0-2 u10000000))
(try! (set-token-mint-amount .token-tdog-v-0-2 u88980600000))
(try! (set-token-mint-amount .token-tusdh-v-0-1 u100000000000))