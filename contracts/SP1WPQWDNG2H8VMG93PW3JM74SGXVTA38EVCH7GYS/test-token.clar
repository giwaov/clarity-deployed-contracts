;; Test Token Contract
;; Implements SIP-010 fungible token standard for development and testing
;; Version: 1.0.0

(impl-trait .sip-010-trait.sip-010-trait)

;; Token Definition
(define-fungible-token test-token)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_OWNER (err u7001))
(define-constant ERR_INSUFFICIENT_BALANCE (err u7002))
(define-constant ERR_NOT_AUTHORIZED (err u7003))
(define-constant ERR_INVALID_AMOUNT (err u7004))

;; Data Variables
(define-data-var token-name (string-ascii 32) "Test Token")
(define-data-var token-symbol (string-ascii 10) "TEST")
(define-data-var token-decimals uint u6)
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var contract-owner principal CONTRACT_OWNER)

;; Ownership Functions

(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_OWNER)
    (var-set contract-owner new-owner)
    (ok true)))

(define-read-only (get-owner)
  (ok (var-get contract-owner)))

;; Mint Function - Owner Only (for testing)
(define-public (mint (amount uint) (recipient principal))
  (begin
    ;; Check caller is owner
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_OWNER)
    ;; Check amount is valid
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    ;; Mint tokens to recipient
    (ft-mint? test-token amount recipient)))

;; Burn Function - Any holder can burn their own tokens
(define-public (burn (amount uint))
  (begin
    ;; Check amount is valid
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    ;; Check caller has sufficient balance
    (asserts! (>= (ft-get-balance test-token tx-sender) amount) ERR_INSUFFICIENT_BALANCE)
    ;; Burn tokens from caller
    (ft-burn? test-token amount tx-sender)))

;; SIP-010 Transfer Function
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    ;; Check amount is valid
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    ;; Sender must be tx-sender
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    ;; Check sender has sufficient balance
    (asserts! (>= (ft-get-balance test-token sender) amount) ERR_INSUFFICIENT_BALANCE)
    ;; Perform transfer
    (match (ft-transfer? test-token amount sender recipient)
      success (begin
        ;; Print transfer event
        (print {
          type: "sip010-transfer",
          sender: sender,
          recipient: recipient,
          amount: amount,
          memo: memo
        })
        (ok success))
      error (err error))))

;; SIP-010 Read-Only Functions

(define-read-only (get-name)
  (ok (var-get token-name)))

(define-read-only (get-symbol)
  (ok (var-get token-symbol)))

(define-read-only (get-decimals)
  (ok (var-get token-decimals)))

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance test-token account)))

(define-read-only (get-total-supply)
  (ok (ft-get-supply test-token)))

(define-read-only (get-token-uri)
  (ok (var-get token-uri)))

;; Additional Helper Functions

(define-public (set-token-uri (uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_OWNER)
    (var-set token-uri uri)
    (ok true)))

;; Batch Operations (useful for testing)

(define-public (mint-many (recipients (list 10 {to: principal, amount: uint})))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_OWNER)
    (ok (map mint-many-iter recipients))))

(define-private (mint-many-iter (recipient {to: principal, amount: uint}))
  (ft-mint? test-token (get amount recipient) (get to recipient)))

;; Initial Supply Distribution (optional, called once)
(define-public (initialize-supply (initial-holders (list 5 {to: principal, amount: uint})))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_OWNER)
    ;; Can only initialize once (when supply is 0)
    (asserts! (is-eq (ft-get-supply test-token) u0) ERR_NOT_AUTHORIZED)
    (ok (map mint-many-iter initial-holders))))

;; Get contract info
(define-read-only (get-contract-info)
  {
    name: (var-get token-name),
    symbol: (var-get token-symbol),
    decimals: (var-get token-decimals),
    total-supply: (ft-get-supply test-token),
    owner: (var-get contract-owner),
    uri: (var-get token-uri)
  })