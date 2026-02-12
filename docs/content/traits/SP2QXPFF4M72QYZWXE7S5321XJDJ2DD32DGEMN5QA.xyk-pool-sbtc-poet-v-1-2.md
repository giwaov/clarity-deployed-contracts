---
title: "Trait xyk-pool-sbtc-poet-v-1-2"
draft: true
---
```
;; SP2QXPFF4M72QYZWXE7S5321XJDJ2DD32DGEMN5QA.xyk-pool-sbtc-poet-v-1-2
;; PoetAI XYK Pool - Full implementation

(impl-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)
(use-trait sip-010-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)

(define-fungible-token pool-token)

(define-constant ERR_NOT_AUTHORIZED_SIP_010 (err u4))
(define-constant ERR_INVALID_PRINCIPAL_SIP_010 (err u5))
(define-constant ERR_NOT_AUTHORIZED (err u3001))
(define-constant ERR_INVALID_AMOUNT (err u3002))
(define-constant ERR_INVALID_PRINCIPAL (err u3003))
(define-constant ERR_POOL_NOT_CREATED (err u3004))
(define-constant ERR_POOL_DISABLED (err u3005))
(define-constant ERR_NOT_POOL_CONTRACT_DEPLOYER (err u3006))

(define-constant CORE_ADDRESS 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2)
(define-constant CONTRACT_DEPLOYER 'SP2QXPFF4M72QYZWXE7S5321XJDJ2DD32DGEMN5QA.poet-faktory-dex-v2)

(define-data-var pool-id uint u0)
(define-data-var pool-name (string-ascii 32) "")
(define-data-var pool-symbol (string-ascii 32) "")
(define-data-var pool-uri (string-utf8 256) u"")
(define-data-var pool-created bool false)
(define-data-var creation-height uint u0)
(define-data-var pool-status bool false)
(define-data-var fee-address principal tx-sender)
(define-data-var x-token principal tx-sender)
(define-data-var y-token principal tx-sender)
(define-data-var x-balance uint u0)
(define-data-var y-balance uint u0)
(define-data-var x-protocol-fee uint u0)
(define-data-var x-provider-fee uint u0)
(define-data-var y-protocol-fee uint u0)
(define-data-var y-provider-fee uint u0)

(define-read-only (get-name) (ok (var-get pool-name)))
(define-read-only (get-symbol) (ok (var-get pool-symbol)))
(define-read-only (get-decimals) (ok u6))
(define-read-only (get-token-uri) (ok (some (var-get pool-uri))))
(define-read-only (get-total-supply) (ok (ft-get-supply pool-token)))
(define-read-only (get-balance (address principal)) (ok (ft-get-balance pool-token address)))

(define-read-only (get-pool)
  (ok {
    pool-id: (var-get pool-id),
    pool-name: (var-get pool-name),
    pool-symbol: (var-get pool-symbol),
    pool-uri: (var-get pool-uri),
    pool-created: (var-get pool-created),
    creation-height: (var-get creation-height),
    pool-status: (var-get pool-status),
    core-address: CORE_ADDRESS,
    fee-address: (var-get fee-address),
    x-token: (var-get x-token),
    y-token: (var-get y-token),
    pool-token: (as-contract tx-sender),
    x-balance: (var-get x-balance),
    y-balance: (var-get y-balance),
    total-shares: (ft-get-supply pool-token),
    x-protocol-fee: (var-get x-protocol-fee),
    x-provider-fee: (var-get x-provider-fee),
    y-protocol-fee: (var-get y-protocol-fee),
    y-provider-fee: (var-get y-provider-fee)
  }))

(define-public (set-pool-uri (uri (string-utf8 256)))
  (begin
    (asserts! (is-eq contract-caller CORE_ADDRESS) ERR_NOT_AUTHORIZED)
    (var-set pool-uri uri)
    (ok true)))

(define-public (set-pool-status (status bool))
  (begin
    (asserts! (is-eq contract-caller CORE_ADDRESS) ERR_NOT_AUTHORIZED)
    (var-set pool-status status)
    (ok true)))

(define-public (set-fee-address (address principal))
  (begin
    (asserts! (is-eq contract-caller CORE_ADDRESS) ERR_NOT_AUTHORIZED)
    (var-set fee-address address)
    (ok true)))

(define-public (set-x-fees (protocol-fee uint) (provider-fee uint))
  (begin
    (asserts! (is-eq contract-caller CORE_ADDRESS) ERR_NOT_AUTHORIZED)
    (var-set x-protocol-fee protocol-fee)
    (var-set x-provider-fee provider-fee)
    (ok true)))

(define-public (set-y-fees (protocol-fee uint) (provider-fee uint))
  (begin
    (asserts! (is-eq contract-caller CORE_ADDRESS) ERR_NOT_AUTHORIZED)
    (var-set y-protocol-fee protocol-fee)
    (var-set y-provider-fee provider-fee)
    (ok true)))

(define-public (update-pool-balances (x-bal uint) (y-bal uint))
  (begin
    (asserts! (is-eq contract-caller CORE_ADDRESS) ERR_NOT_AUTHORIZED)
    (var-set x-balance x-bal)
    (var-set y-balance y-bal)
    (ok true)))

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED_SIP_010)
    (asserts! (is-standard sender) ERR_INVALID_PRINCIPAL_SIP_010)
    (asserts! (is-standard recipient) ERR_INVALID_PRINCIPAL_SIP_010)
    (try! (ft-transfer? pool-token amount sender recipient))
    (match memo m (print m) 0x)
    (ok true)))

(define-public (pool-transfer (token-trait <sip-010-trait>) (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq contract-caller CORE_ADDRESS) ERR_NOT_AUTHORIZED)
    (asserts! (is-standard (contract-of token-trait)) ERR_INVALID_PRINCIPAL)
    (asserts! (is-standard recipient) ERR_INVALID_PRINCIPAL)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (as-contract (contract-call? token-trait transfer amount tx-sender recipient none)))
    (ok true)))

(define-public (pool-mint (amount uint) (address principal))
  (begin
    (asserts! (is-eq contract-caller CORE_ADDRESS) ERR_NOT_AUTHORIZED)
    (asserts! (is-standard address) ERR_INVALID_PRINCIPAL)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (ft-mint? pool-token amount address))
    (ok true)))

(define-public (pool-burn (amount uint) (address principal))
  (begin
    (asserts! (is-eq contract-caller CORE_ADDRESS) ERR_NOT_AUTHORIZED)
    (asserts! (is-standard address) ERR_INVALID_PRINCIPAL)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (ft-burn? pool-token amount address))
    (ok true)))

(define-public (create-pool
    (x-token-contract principal) (y-token-contract principal)
    (fee-addr principal) (core-caller principal)
    (id uint)
    (name (string-ascii 32)) (symbol (string-ascii 32))
    (uri (string-utf8 256))
    (status bool))
  (begin
    (asserts! (is-eq contract-caller CORE_ADDRESS) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq core-caller CONTRACT_DEPLOYER) ERR_NOT_POOL_CONTRACT_DEPLOYER)
    (var-set pool-id id)
    (var-set pool-name name)
    (var-set pool-symbol symbol)
    (var-set pool-uri uri)
    (var-set pool-created true)
    (var-set creation-height burn-block-height)
    (var-set pool-status status)
    (var-set x-token x-token-contract)
    (var-set y-token y-token-contract)
    (var-set fee-address fee-addr)
    (ok true)))
```
