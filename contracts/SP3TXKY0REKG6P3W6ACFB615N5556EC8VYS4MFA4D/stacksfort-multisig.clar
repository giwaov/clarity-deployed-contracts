;; Multi-signature vault contract
;; Implements a multisig wallet for managing STX and SIP-010 tokens
;;
;; Clarity Version: 3 (local dev) / 4 (planned for mainnet)
;; Clarity 4 Features: See CLARITY4-IMPLEMENTATION-PLAN.md for planned features:
;;   - restrict-assets? (Issue #7) - Post-conditions for token transfers
;;   - block-height (Issue #15) - Transaction expiration
;;   - contract-hash? (Issue #7) - Token contract verification
;;   - to-ascii? (Issues #2, #6, #7) - Enhanced logging

;; SIP-010 trait import for token transfers
(use-trait sip-010-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; ============================================
;; ========== temp test ==========
;; Temporary counter state for testing
(define-data-var counter uint u0)

(define-public (increment-counter)
    (begin
        (var-set counter (+ (var-get counter) u1))
        (ok (var-get counter))
    )
)

(define-public (decrement-counter)
    (begin
        (if (> (var-get counter) u0)
            (var-set counter (- (var-get counter) u1))
            (var-set counter u0)
        )
        (ok (var-get counter))
    )
)

(define-read-only (get-counter)
    (ok (var-get counter))
)
;; ========== temp test ==========
;; ============================================
;; Constants
;; ============================================
(define-constant CONTRACT_OWNER 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-constant MAX_SIGNERS u100)
(define-constant MIN_SIGNATURES_REQUIRED u1)
(define-constant DEFAULT_EXPIRATION_WINDOW u1008) ;; ~7 days in blocks (144 blocks/day)

;; Transaction Types
(define-constant TX_TYPE_STX u0)
(define-constant TX_TYPE_TOKEN u1)
(define-constant TX_TYPE_CONFIG u2)

;; ============================================
;; Error Constants (Grouped & Standardized)
;; ============================================

;; Auth Errors (u100-u199)
(define-constant ERR_AUTH_OWNER_ONLY (err u100))
(define-constant ERR_AUTH_NOT_INITIALIZED (err u101))
(define-constant ERR_AUTH_NOT_SIGNER (err u102))

;; Initialization Errors (u200-u299)
(define-constant ERR_INIT_ALREADY_INITIALIZED (err u200))
(define-constant ERR_INIT_TOO_MANY_SIGNERS (err u201))
(define-constant ERR_INIT_INVALID_THRESHOLD (err u202))

;; Validation Errors (u300-u399)
(define-constant ERR_VAL_INVALID_AMOUNT (err u300))
(define-constant ERR_VAL_INVALID_TXN_TYPE (err u301))
(define-constant ERR_VAL_INVALID_TXN_ID (err u302))
(define-constant ERR_VAL_INVALID_TOKEN (err u303))
(define-constant ERR_VAL_INVALID_CONFIG (err u304))

;; Transaction State Errors (u400-u499)
(define-constant ERR_TX_ALREADY_EXECUTED (err u400))
(define-constant ERR_TX_EXPIRED (err u401))

;; Execution Errors (u500-u599)
(define-constant ERR_EXEC_INSUFFICIENT_SIGNATURES (err u500))
(define-constant ERR_EXEC_INVALID_SIGNATURE (err u501))
(define-constant ERR_EXEC_STX_TRANSFER_FAILED (err u502))
(define-constant ERR_EXEC_REENTRANCY_DETECTED (err u503))

;; ============================================
;; Data Variables
;; ============================================
(define-data-var initialized bool false)
(define-data-var signers (list 100 principal) (list))
(define-data-var threshold uint u0)
(define-data-var txn-id uint u0)
(define-data-var reentrancy-lock bool false)

;; ============================================
;; Maps
;; ============================================
(define-map transactions
  uint
  {
    type: uint,
    amount: uint,
    recipient: principal,
    token: (optional principal),
    executed: bool,
    expiration: uint,
    new-signers: (optional (list 100 principal)),
    new-threshold: (optional uint)
  }
)

(define-map txn-signers
  (tuple (txn-id uint) (signer principal))
  bool
)

;; Helpers for tracking which signers have approved a transaction
(define-private (txn-signer-key (target-id uint) (signer principal))
    (tuple (txn-id target-id) (signer signer))
)

(define-private (build-signature-accumulator (target-id uint) (hash (buff 32)))
    (tuple (txn-id target-id) (hash hash) (count u0))
)

;; ============================================
;; Public Functions
;; ============================================

;; Issue #1: Initialize the multisig contract
(define-public (initialize
    (signers-list (list 100 principal))
    (threshold-value uint)
)
    (begin
        ;; Verify contract owner
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_AUTH_OWNER_ONLY)
        ;; Check initialization status (must be false)
        (asserts! (not (var-get initialized)) ERR_INIT_ALREADY_INITIALIZED)
        ;; Validate signers list length (max 100 using MAX_SIGNERS)
        (let ((signers-count (len signers-list)))
            (asserts! (<= signers-count MAX_SIGNERS) ERR_INIT_TOO_MANY_SIGNERS)
            ;; Validate threshold (min 1 using MIN_SIGNATURES_REQUIRED, max should be <= signers count)
            (asserts! (>= threshold-value MIN_SIGNATURES_REQUIRED) ERR_INIT_INVALID_THRESHOLD)
            (asserts! (<= threshold-value signers-count) ERR_INIT_INVALID_THRESHOLD)
            ;; Set signers and threshold in storage
            (var-set signers signers-list)
            (var-set threshold threshold-value)
            ;; Mark contract as initialized (set initialized to true)
            (var-set initialized true)
            
            ;; Issue #14: Add initialization event
            (print {
                event: "initialize",
                signers: signers-list,
                threshold: threshold-value
            })
            
            (ok true)
        )
    )
)

;; Explicit deposit function to track inbound STX
;; Issue #14: Added deposit function with event
(define-public (deposit (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (print {
            event: "deposit",
            sender: tx-sender,
            amount: amount
        })
        (ok true)
    )
)

;; Issue #2: Submit a new transaction proposal
;; Issue #15: Added optional expiration parameter
(define-public (submit-txn
    (txn-type uint)
    (amount uint)
    (recipient principal)
    (token (optional principal))
    (expiration (optional uint))
)
    (begin
        ;; Verify contract is initialized
        (asserts! (var-get initialized) ERR_AUTH_NOT_INITIALIZED)
        ;; Verify caller is a signer
        (let ((caller tx-sender))
            (asserts! (is-some (index-of (var-get signers) caller)) ERR_AUTH_NOT_SIGNER)
            ;; Validate amount > 0
            (asserts! (> amount u0) ERR_VAL_INVALID_AMOUNT)
            ;; Validate transaction type (0 = STX transfer, 1 = SIP-010 transfer)
            (asserts! (or (is-eq txn-type TX_TYPE_STX) (is-eq txn-type TX_TYPE_TOKEN)) ERR_VAL_INVALID_TXN_TYPE)
            ;; For type 1 (SIP-010), validate that token contract is provided
            (if (is-eq txn-type TX_TYPE_TOKEN)
                (asserts! (is-some token) ERR_VAL_INVALID_TOKEN)
                true
            )
            ;; Get current txn-id from storage
            (let (
                (current-id (var-get txn-id))
                (expiry-time (default-to (+ block-height DEFAULT_EXPIRATION_WINDOW) expiration))
            )
                ;; Store transaction in transactions map
                (map-set transactions current-id {
                    type: txn-type,
                    amount: amount,
                    recipient: recipient,
                    token: token,
                    executed: false,
                    expiration: expiry-time,
                    new-signers: none,
                    new-threshold: none
                })
                ;; Increment txn-id by 1
                (var-set txn-id (+ current-id u1))
                ;; Issue #14: standard event format
                (print {
                    event: "submit-txn",
                    txn-id: current-id, 
                    type: txn-type, 
                    amount: amount, 
                    recipient: recipient, 
                    token: token, 
                    expiration: expiry-time
                })
                (ok current-id)
            )
        )
    )
)

;; Issue #15: Submit a management transaction to update owners/threshold
(define-public (submit-config-txn
    (new-signers-list (list 100 principal))
    (new-threshold-value uint)
    (expiration (optional uint))
)
    (begin
        (asserts! (var-get initialized) ERR_AUTH_NOT_INITIALIZED)
        (asserts! (is-some (index-of (var-get signers) tx-sender)) ERR_AUTH_NOT_SIGNER)
        
        ;; Validate new configuration
        (let ((signers-count (len new-signers-list)))
            (asserts! (<= signers-count MAX_SIGNERS) ERR_INIT_TOO_MANY_SIGNERS)
            (asserts! (>= new-threshold-value MIN_SIGNATURES_REQUIRED) ERR_VAL_INVALID_CONFIG)
            (asserts! (<= new-threshold-value signers-count) ERR_VAL_INVALID_CONFIG)

            (let (
                (current-id (var-get txn-id))
                (expiry-time (default-to (+ block-height DEFAULT_EXPIRATION_WINDOW) expiration))
            )
                (map-set transactions current-id {
                    type: TX_TYPE_CONFIG,
                    amount: u0,
                    recipient: (as-contract tx-sender),
                    token: none,
                    executed: false,
                    expiration: expiry-time,
                    new-signers: (some new-signers-list),
                    new-threshold: (some new-threshold-value)
                })
                (var-set txn-id (+ current-id u1))
                (print {
                    event: "submit-config-txn",
                    txn-id: current-id,
                    new-signers: new-signers-list,
                    new-threshold: new-threshold-value,
                    expiration: expiry-time
                })
                (ok current-id)
            )
        )
    )
)

;; Issue #3: Hash a stored transaction for signature verification
(define-read-only (hash-txn (target-id uint))
    (let (
        (txn (unwrap! (map-get? transactions target-id) ERR_VAL_INVALID_TXN_ID))
        (txn-buff (unwrap! (to-consensus-buff? txn) ERR_VAL_INVALID_TXN_ID))
    )
        (ok (sha256 txn-buff))
    )
)

;; Issue #4: Extract and verify signer from signature
(define-read-only (extract-signer
    (message-hash (buff 32))
    (signature (buff 65))
)
    (match (secp256k1-recover? message-hash signature)
        pubkey
            (match (principal-of? pubkey)
                signer
                    (if (is-some (index-of (var-get signers) signer))
                        (ok signer)
                        ERR_EXEC_INVALID_SIGNATURE
                    )
                none ERR_EXEC_INVALID_SIGNATURE
            )
        err-code ERR_EXEC_INVALID_SIGNATURE
    )
)

;; Issue #5: Count valid, unique signatures for a transaction
(define-private (count-valid-unique-signature
    (signature (buff 65))
    (accumulator (tuple (txn-id uint) (hash (buff 32)) (count uint)))
)
    (match (extract-signer (get hash accumulator) signature)
        signer
            (let ((key (txn-signer-key (get txn-id accumulator) signer)))
                (if (is-some (map-get? txn-signers key))
                    accumulator
                    (begin
                        (map-set txn-signers key true)
                        (tuple
                            (txn-id (get txn-id accumulator))
                            (hash (get hash accumulator))
                            (count (+ (get count accumulator) u1))
                        )
                    )
                )
            )
        err-code accumulator
    )
)

;; Public helper to fold over signatures in tests
(define-public (count-unique-valid-signatures
    (target-id uint)
    (signatures (list 100 (buff 65)))
)
    (let (
        (txn-hash (unwrap! (hash-txn target-id) ERR_VAL_INVALID_TXN_ID))
        (result (fold
            count-valid-unique-signature
            signatures
            (build-signature-accumulator target-id txn-hash)
        ))
    )
        (ok (get count result))
    )
)

;; Issue #6: Execute a pending STX transfer transaction
(define-public (execute-stx-transfer-txn
    (target-id uint)
    (signatures (list 100 (buff 65)))
)
    (begin
        ;; Verify contract is initialized
        (asserts! (var-get initialized) ERR_AUTH_NOT_INITIALIZED)

        ;; Reentrancy Check
        (asserts! (not (var-get reentrancy-lock)) ERR_EXEC_REENTRANCY_DETECTED)
        (var-set reentrancy-lock true)

        ;; Verify caller is a signer
        (asserts! (is-some (index-of (var-get signers) tx-sender)) ERR_AUTH_NOT_SIGNER)

        ;; Load and validate the transaction
        (let (
            (txn (unwrap! (map-get? transactions target-id) ERR_VAL_INVALID_TXN_ID))
        )
            ;; Verify transaction ID is valid (must be less than current txn-id)
            (asserts! (< target-id (var-get txn-id)) ERR_VAL_INVALID_TXN_ID)

            ;; Verify transaction type is STX (0)
            (asserts! (is-eq (get type txn) TX_TYPE_STX) ERR_VAL_INVALID_TXN_TYPE)

            ;; Verify transaction hasn't been executed
            (asserts! (not (get executed txn)) ERR_TX_ALREADY_EXECUTED)

            ;; Verify transaction has not expired
            (asserts! (< block-height (get expiration txn)) ERR_TX_EXPIRED)

            ;; Verify signatures list length >= threshold
            (asserts! (>= (len signatures) (var-get threshold)) ERR_EXEC_INSUFFICIENT_SIGNATURES)

            ;; Compute txn hash and count unique valid signatures
            (let (
                (txn-hash (unwrap! (hash-txn target-id) ERR_VAL_INVALID_TXN_ID))
                (result (fold
                    count-valid-unique-signature
                    signatures
                    (build-signature-accumulator target-id txn-hash)
                ))
                (valid-count (get count result))
            )
                ;; Verify unique valid signature count >= threshold
                (asserts! (>= valid-count (var-get threshold)) ERR_EXEC_INSUFFICIENT_SIGNATURES)

                ;; Execute STX transfer from contract to recipient using as-contract wrapper
                (let (
                    (transfer-result (as-contract (stx-transfer? (get amount txn) tx-sender (get recipient txn))))
                )
                    (match transfer-result
                        ok-value
                            (begin
                                ;; Mark transaction as executed
                                (map-set transactions target-id (merge txn { executed: true }))
                                ;; Issue #14: Standard event for execution
                                (print {
                                    event: "execute-txn",
                                    txn-id: target-id,
                                    type: "stx",
                                    amount: (get amount txn),
                                    recipient: (get recipient txn),
                                    valid-signatures: valid-count
                                })
                                (var-set reentrancy-lock false)
                                (ok true)
                            )
                        err-value 
                            (begin
                                (var-set reentrancy-lock false)
                                ERR_EXEC_STX_TRANSFER_FAILED
                            )
                    )
                )
            )
        )
    )
)

;; Issue #7: Execute a pending SIP-010 token transfer transaction
(define-public (execute-token-transfer-txn
    (target-id uint)
    (signatures (list 100 (buff 65)))
    (token-contract <sip-010-trait>)
)
    (begin
        ;; Verify contract is initialized
        (asserts! (var-get initialized) ERR_AUTH_NOT_INITIALIZED)

        ;; Reentrancy Check
        (asserts! (not (var-get reentrancy-lock)) ERR_EXEC_REENTRANCY_DETECTED)
        (var-set reentrancy-lock true)

        ;; Verify caller is a signer
        (asserts! (is-some (index-of (var-get signers) tx-sender)) ERR_AUTH_NOT_SIGNER)

        ;; Load and validate the transaction
        (let (
            (txn (unwrap! (map-get? transactions target-id) ERR_VAL_INVALID_TXN_ID))
        )
            ;; Verify transaction ID is valid (must be less than current txn-id)
            (asserts! (< target-id (var-get txn-id)) ERR_VAL_INVALID_TXN_ID)

            ;; Verify transaction type is SIP-010 (1)
            (asserts! (is-eq (get type txn) TX_TYPE_TOKEN) ERR_VAL_INVALID_TXN_TYPE)

            ;; Verify token principal is provided
            (asserts! (is-some (get token txn)) ERR_VAL_INVALID_TOKEN)

            ;; Verify token contract parameter matches the stored token principal
            (let ((stored-token (unwrap! (get token txn) ERR_VAL_INVALID_TOKEN)))
                (asserts! (is-eq (contract-of token-contract) stored-token) ERR_VAL_INVALID_TOKEN)
            )

            ;; Verify transaction hasn't been executed
            (asserts! (not (get executed txn)) ERR_TX_ALREADY_EXECUTED)

            ;; Verify transaction has not expired
            (asserts! (< block-height (get expiration txn)) ERR_TX_EXPIRED)

            ;; Verify signatures list length >= threshold
            (asserts! (>= (len signatures) (var-get threshold)) ERR_EXEC_INSUFFICIENT_SIGNATURES)

            ;; Compute txn hash and count unique valid signatures
            (let (
                (txn-hash (unwrap! (hash-txn target-id) ERR_VAL_INVALID_TXN_ID))
                (result (fold
                    count-valid-unique-signature
                    signatures
                    (build-signature-accumulator target-id txn-hash)
                ))
                (valid-count (get count result))
            )
                ;; Verify unique valid signature count >= threshold
                (asserts! (>= valid-count (var-get threshold)) ERR_EXEC_INSUFFICIENT_SIGNATURES)

                ;; Execute SIP-010 transfer from contract to recipient using as-contract wrapper
                (let (
                    (transfer-result (as-contract (contract-call? token-contract transfer 
                        (get amount txn) 
                        tx-sender 
                        (get recipient txn) 
                        none
                    )))
                )
                    (match transfer-result
                        ok-value
                            (begin
                                ;; Mark transaction as executed
                                (map-set transactions target-id (merge txn { executed: true }))
                                ;; Issue #14: Standard event for execution
                                (print {
                                    event: "execute-txn",
                                    txn-id: target-id,
                                    type: "token",
                                    amount: (get amount txn),
                                    recipient: (get recipient txn),
                                    token: (get token txn),
                                    valid-signatures: valid-count
                                })
                                (var-set reentrancy-lock false)
                                (ok true)
                            )
                        err-value 
                            (begin
                                (var-set reentrancy-lock false)
                                ERR_EXEC_STX_TRANSFER_FAILED
                            )
                    )
                )
            )
        )
    )
)

;; Issue #15: Execute a pending configuration change transaction
(define-public (execute-config-txn
    (target-id uint)
    (signatures (list 100 (buff 65)))
)
    (begin
        (asserts! (var-get initialized) ERR_AUTH_NOT_INITIALIZED)
        (asserts! (not (var-get reentrancy-lock)) ERR_EXEC_REENTRANCY_DETECTED)
        (var-set reentrancy-lock true)
        (asserts! (is-some (index-of (var-get signers) tx-sender)) ERR_AUTH_NOT_SIGNER)

        (let (
            (txn (unwrap! (map-get? transactions target-id) ERR_VAL_INVALID_TXN_ID))
        )
            (asserts! (is-eq (get type txn) TX_TYPE_CONFIG) ERR_VAL_INVALID_TXN_TYPE)
            (asserts! (not (get executed txn)) ERR_TX_ALREADY_EXECUTED)
            (asserts! (< block-height (get expiration txn)) ERR_TX_EXPIRED)

            (let (
                (txn-hash (unwrap! (hash-txn target-id) ERR_VAL_INVALID_TXN_ID))
                (result (fold
                    count-valid-unique-signature
                    signatures
                    (build-signature-accumulator target-id txn-hash)
                ))
                (valid-count (get count result))
                (new-signers-list (unwrap! (get new-signers txn) ERR_VAL_INVALID_CONFIG))
                (new-threshold-val (unwrap! (get new-threshold txn) ERR_VAL_INVALID_CONFIG))
            )
                (asserts! (>= valid-count (var-get threshold)) ERR_EXEC_INSUFFICIENT_SIGNATURES)

                ;; Apply new configuration
                (var-set signers new-signers-list)
                (var-set threshold new-threshold-val)
                
                (map-set transactions target-id (merge txn { executed: true }))

                (print {
                    event: "execute-config-txn",
                    txn-id: target-id,
                    signers: new-signers-list,
                    threshold: new-threshold-val,
                    valid-signatures: valid-count
                })
                (var-set reentrancy-lock false)
                (ok true)
            )
        )
    )
)
