;; boom-payment-hub.clar
;;
;; A payment hub contract that:
;; 1. Receives STX or SIP-010 tokens with a memo (payment intent ID)
;; 2. Forwards payment to the specified recipient (merchant)
;; 3. Emits a payment-received event for chainhook detection
;;
;; This enables scalable payment detection with a single chainhook
;; watching this contract instead of N merchant addresses.

;; SIP-010 trait for fungible tokens
(use-trait sip010-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Error codes
(define-constant ERR-INVALID-AMOUNT (err u100))
(define-constant ERR-TRANSFER-FAILED (err u101))
(define-constant ERR-EMPTY-MEMO (err u102))
(define-constant ERR-TOKEN-NOT-APPROVED (err u103))
(define-constant ERR-NOT-AUTHORIZED (err u104))

;; Contract owner for admin functions
(define-constant CONTRACT-OWNER tx-sender)

;; Approved tokens whitelist
;; Only sBTC and USDCx are allowed
(define-map approved-tokens principal bool)

;; Initialize approved tokens (sBTC and USDCx on mainnet)
;; sBTC: SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
;; USDCx: (add actual contract address)
;; Mainnet Address: SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx
;; Testnet Address: ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.usdcx
(map-set approved-tokens 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token true)
(map-set approved-tokens 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx true)


;; Read-only: Check if a token is approved
(define-read-only (is-token-approved (token-contract principal))
  (default-to false (map-get? approved-tokens token-contract))
)

;; Read-only: Get contract info
(define-read-only (get-info)
  (ok {
    name: "Boom Payment Hub",
    version: u2
  })
)

;; Admin: Add approved token
(define-public (add-approved-token (token-contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set approved-tokens token-contract true))
  )
)

;; Admin: Remove approved token
(define-public (remove-approved-token (token-contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-delete approved-tokens token-contract))
  )
)

;; Pay with STX
;; @param recipient - The merchant/seller address to receive payment
;; @param memo - The payment intent ID (format: p:{id}{hmac_tag})
(define-public (pay-stx (recipient principal) (memo (buff 34)))
  (let (
    (amount (stx-get-balance tx-sender))
  )
    ;; Validate
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> (len memo) u0) ERR-EMPTY-MEMO)

    ;; Transfer STX to recipient
    (try! (stx-transfer-memo? amount tx-sender recipient memo))

    ;; Emit payment event for chainhook
    (print {
      event: "payment-received",
      token: "STX",
      sender: tx-sender,
      recipient: recipient,
      amount: amount,
      memo: memo
    })

    (ok amount)
  )
)

;; Pay with STX - specify amount explicitly
;; @param recipient - The merchant/seller address to receive payment
;; @param amount - Amount of microSTX to send
;; @param memo - The payment intent ID
(define-public (pay-stx-amount (recipient principal) (amount uint) (memo (buff 34)))
  (begin
    ;; Validate
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> (len memo) u0) ERR-EMPTY-MEMO)

    ;; Transfer STX to recipient
    (try! (stx-transfer-memo? amount tx-sender recipient memo))

    ;; Emit payment event for chainhook
    (print {
      event: "payment-received",
      token: "STX",
      sender: tx-sender,
      recipient: recipient,
      amount: amount,
      memo: memo
    })

    (ok amount)
  )
)

;; Pay with SIP-010 token (sBTC, USDCx only)
;; @param token - The SIP-010 token contract (must be whitelisted)
;; @param recipient - The merchant/seller address to receive payment
;; @param amount - Amount of tokens to send (in base units)
;; @param memo - The payment intent ID
(define-public (pay-sip010
  (token <sip010-trait>)
  (recipient principal)
  (amount uint)
  (memo (buff 34))
)
  (let (
    (token-contract (contract-of token))
  )
    ;; Validate token is whitelisted
    (asserts! (is-token-approved token-contract) ERR-TOKEN-NOT-APPROVED)

    ;; Validate amount and memo
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> (len memo) u0) ERR-EMPTY-MEMO)

    ;; Transfer tokens to recipient (with memo in token transfer)
    (try! (contract-call? token transfer amount tx-sender recipient (some memo)))

    ;; Emit payment event for chainhook
    (print {
      event: "payment-received",
      token: token-contract,
      sender: tx-sender,
      recipient: recipient,
      amount: amount,
      memo: memo
    })

    (ok amount)
  )
)

