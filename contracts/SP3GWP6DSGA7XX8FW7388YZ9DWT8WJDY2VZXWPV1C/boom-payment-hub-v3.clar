;; boom-payment-hub.clar
;;
;; A payment hub contract that:
;; 1. Receives STX or SIP-010 tokens with payment metadata
;; 2. Enforces platform fees on-chain by payment type
;; 3. Splits payment between recipient and Boom treasury
;; 4. Emits standardized payment events for chainhook detection

;; SIP-010 trait for fungible tokens
(use-trait sip010-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; ============================================
;; Constants
;; ============================================

;; Contract owner for admin functions
(define-constant CONTRACT_OWNER tx-sender)

;; Boom treasury for fee collection
;; TODO: Update to actual treasury principal before mainnet deployment
(define-constant BOOM_TREASURY 'SP3GWP6DSGA7XX8FW7388YZ9DWT8WJDY2VZXWPV1C)

;; Max payment amount to prevent overflow in fee calculation
;; (uint max / 10000 to ensure fee-bps multiplication is safe)
(define-constant MAX_PAYMENT_AMOUNT u34028236692093846346337460743176821)

;; Error codes
(define-constant ERR_INVALID_AMOUNT (err u100))
(define-constant ERR_TRANSFER_FAILED (err u101))
(define-constant ERR_TOKEN_NOT_APPROVED (err u103))
(define-constant ERR_NOT_AUTHORIZED (err u104))
(define-constant ERR_UNKNOWN_PAYMENT_TYPE (err u105))
(define-constant ERR_INVALID_FEE_RATE (err u106))
(define-constant ERR_INVALID_PAYMENT_TYPE (err u107))
(define-constant ERR_AMOUNT_TOO_LARGE (err u108))

;; ============================================
;; Data Maps
;; ============================================

;; Approved tokens whitelist (sBTC, USDCx, etc.)
(define-map ApprovedTokens principal bool)

;; Fee rates by payment type (in basis points, 100 = 1%)
;; Enforced on-chain - callers cannot override
(define-map FeeRates 
  { paymentType: (string-ascii 20) }
  { feeBps: uint }
)

;; ============================================
;; Initialize Data
;; ============================================

;; Approved tokens
(map-set ApprovedTokens 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token true)
(map-set ApprovedTokens 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx true)

;; Fee rates by payment type
;; name: 0% (100% to Boom treasury as recipient)
;; nft_purchase: 2.5% to Boom, rest to seller
;; nft_mint: 2.5% to Boom, rest to creator
;; tip: 1% to Boom, rest to recipient
;; goods: 3% to Boom, rest to merchant
;; digital: 2.5% to Boom, rest to creator
(map-set FeeRates { paymentType: "name" } { feeBps: u0 })
(map-set FeeRates { paymentType: "nft_purchase" } { feeBps: u250 })
(map-set FeeRates { paymentType: "nft_mint" } { feeBps: u250 })
(map-set FeeRates { paymentType: "tip" } { feeBps: u100 })
(map-set FeeRates { paymentType: "goods" } { feeBps: u300 })
(map-set FeeRates { paymentType: "digital" } { feeBps: u250 })

;; ============================================
;; Read-Only Functions
;; ============================================

;; Get contract info
(define-read-only (get-info)
  (ok {
    name: "Boom Payment Hub",
    version: u3,
    treasury: BOOM_TREASURY,
    maxPaymentAmount: MAX_PAYMENT_AMOUNT
  })
)

;; Check if a token is approved
(define-read-only (is-token-approved (tokenContract principal))
  (default-to false (map-get? ApprovedTokens tokenContract))
)

;; Get fee rate for a payment type (returns 0 if not found)
(define-read-only (get-fee-rate (paymentType (string-ascii 20)))
  (get feeBps (default-to { feeBps: u0 } (map-get? FeeRates { paymentType: paymentType })))
)

;; Check if payment type exists
(define-read-only (is-valid-payment-type (paymentType (string-ascii 20)))
  (is-some (map-get? FeeRates { paymentType: paymentType }))
)

;; Calculate fee and net amounts for a given payment
(define-read-only (calculate-split (amount uint) (paymentType (string-ascii 20)))
  (let (
    (feeBps (get-fee-rate paymentType))
    (fee (/ (* amount feeBps) u10000))
    (net (- amount fee))
  )
    { fee: fee, net: net, feeBps: feeBps }
  )
)

;; ============================================
;; Admin Functions
;; ============================================

;; Add or update fee rate for a payment type
;; Uses tx-sender (not contract-caller) to ensure only the original
;; signer can modify, preventing force contract-call attacks
(define-public (set-fee-rate (paymentType (string-ascii 20)) (feeBps uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= feeBps u10000) ERR_INVALID_FEE_RATE) ;; Max 100%
    (asserts! (> (len paymentType) u0) ERR_INVALID_PAYMENT_TYPE)
    (ok (map-set FeeRates { paymentType: paymentType } { feeBps: feeBps }))
  )
)

;; Add approved token
(define-public (add-approved-token (tokenContract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-set ApprovedTokens tokenContract true))
  )
)

;; Remove approved token
(define-public (remove-approved-token (tokenContract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-delete ApprovedTokens tokenContract))
  )
)

;; ============================================
;; Payment Functions
;; ============================================

;; Pay with STX
;; Fee is determined on-chain by paymentType - cannot be manipulated by caller
;; 
;; @param recipient - The merchant/seller address to receive net payment
;; @param amount - Total amount in microSTX (fee will be deducted)
;; @param paymentType - Type of payment (determines fee rate)
;; @param reference - Domain-specific ID (name, listing ID, etc.)
(define-public (pay-stx 
    (recipient principal)
    (amount uint)
    (paymentType (string-ascii 20))
    (reference (string-ascii 64))
)
  (let (
    (feeBps (get-fee-rate paymentType))
    (fee (/ (* amount feeBps) u10000))
    (net (- amount fee))
  )
    ;; Validate
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= amount MAX_PAYMENT_AMOUNT) ERR_AMOUNT_TOO_LARGE)
    (asserts! (is-valid-payment-type paymentType) ERR_UNKNOWN_PAYMENT_TYPE)

    ;; Transfer fee to Boom treasury (if any)
    (if (> fee u0)
      (try! (stx-transfer? fee tx-sender BOOM_TREASURY))
      true
    )

    ;; Transfer net to recipient
    (try! (stx-transfer? net tx-sender recipient))

    ;; Emit payment event for chainhook
    (print {
      event: "payment",
      version: u3,
      token: "STX",
      paymentType: paymentType,
      reference: reference,
      sender: tx-sender,
      recipient: recipient,
      treasury: BOOM_TREASURY,
      amount: amount,
      feeBps: feeBps,
      fee: fee,
      net: net
    })

    (ok { amount: amount, fee: fee, net: net })
  )
)

;; Pay with SIP-010 token (sBTC, USDCx)
;; Fee is determined on-chain by paymentType - cannot be manipulated by caller
;;
;; @param token - The SIP-010 token contract (must be whitelisted)
;; @param recipient - The merchant/seller address to receive net payment
;; @param amount - Total amount in token base units (fee will be deducted)
;; @param paymentType - Type of payment (determines fee rate)
;; @param reference - Domain-specific ID
(define-public (pay-sip010
    (token <sip010-trait>)
    (recipient principal)
    (amount uint)
    (paymentType (string-ascii 20))
    (reference (string-ascii 64))
)
  (let (
    (tokenContract (contract-of token))
    (feeBps (get-fee-rate paymentType))
    (fee (/ (* amount feeBps) u10000))
    (net (- amount fee))
  )
    ;; Validate token is whitelisted
    (asserts! (is-token-approved tokenContract) ERR_TOKEN_NOT_APPROVED)
    
    ;; Validate amount and payment type
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= amount MAX_PAYMENT_AMOUNT) ERR_AMOUNT_TOO_LARGE)
    (asserts! (is-valid-payment-type paymentType) ERR_UNKNOWN_PAYMENT_TYPE)

    ;; Transfer fee to Boom treasury (if any)
    (if (> fee u0)
      (try! (contract-call? token transfer fee tx-sender BOOM_TREASURY none))
      true
    )

    ;; Transfer net to recipient
    (try! (contract-call? token transfer net tx-sender recipient none))

    ;; Emit payment event for chainhook
    (print {
      event: "payment",
      version: u3,
      token: tokenContract,
      paymentType: paymentType,
      reference: reference,
      sender: tx-sender,
      recipient: recipient,
      treasury: BOOM_TREASURY,
      amount: amount,
      feeBps: feeBps,
      fee: fee,
      net: net
    })

    (ok { amount: amount, fee: fee, net: net })
  )
)

