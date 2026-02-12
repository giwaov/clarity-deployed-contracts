---
title: "Trait cf-vault-stacks-labs-v1-67536"
draft: true
---
```
;; This is a vault contract. It is the only contract needed per client per chain & is
;; therefore used as a universal address. It functions by allow a batch of verified
;; signatures to execute a transaction or transfer by checking against a policy.
;; A transaction is a contract call meant for protocol interactions.
;; A transfer is strictly a sip10 token transfer from the vault to a recipient.

;; cons
(define-constant SIP018_MSG_PREFIX 0x534950303138)
(define-constant CLIENT 0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81)
(use-trait wrapper-trait 'SP51N7RK1H0YS0N7SHZ6TXD5MP03DMWH9YQBJSJK.cf-traits-v0.wrapper-trait)
(use-trait token-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; errs
(define-constant ERR_INACTIVE_POLICY (err u101))
(define-constant ERR_THRESHOLD_NOT_MET (err u103))
(define-constant ERR_INVALID_TYPE (err u104))
(define-constant ERR_AMOUNT_EXCEEDS_POLICY (err u105))
(define-constant ERR_INVALID_USER (err u106))
(define-constant ERR_INACTIVE_USER (err u107))
(define-constant ERR_INVALID_POLICY (err u108))
(define-constant ERR_INVALID_SIGNATURE (err u109))
(define-constant ERR_INVALID_SIGNER (err u110))
(define-constant ERR_AUTH_ID_REPLAY (err u111))
(define-constant ERR_DUPLICATE_SIGNATURE (err u114))
(define-constant ERR_INVALID_CALLER (err u115))
(define-constant ERR_INVALID_TOKEN (err u116))
(define-constant ERR_INVALID_WRAPPER (err u117))
(define-constant ERR_INVALID_FUNCTION (err u118))
(define-constant ERR_INVALID_PUBKEY (err u119))

;; Fee calculation constant
(define-constant FEE_DIVISOR u10000)

;; calculate-fee
;; Calculates the fee amount for a transfer based on the client's subscription tier.
;; Fee calculation: fee = (amount * fee_bps) / 10,000
;; Special cases:
;; - If client has 0% tier (BUSINESS): returns 0 immediately
;; - If fee would round to 0 but should exist: returns minimum of 1 unit
(define-private (calculate-fee (amount uint))
    (let (
            (fee-bps (contract-call? 'SP51N7RK1H0YS0N7SHZ6TXD5MP03DMWH9YQBJSJK.cf-helpers-state-v0 get-client-fee-bps CLIENT))
            (raw-fee (/ (* amount fee-bps) FEE_DIVISOR))
        )
        (if (is-eq fee-bps u0)
            u0
            (if (and (> (* amount fee-bps) u0) (is-eq raw-fee u0))
                u1
                raw-fee
            )
        )
    )
)

;; caller guards

(define-private (assert-valid-caller)
    (let ((user (contract-call? 'SP51N7RK1H0YS0N7SHZ6TXD5MP03DMWH9YQBJSJK.cf-helpers-state-v0 get-user-id-by-address tx-sender)))
        (asserts!
            (or
                (contract-call? 'SP51N7RK1H0YS0N7SHZ6TXD5MP03DMWH9YQBJSJK.cf-helpers-state-v0 is-cofund-admin tx-sender)
                (is-eq (default-to 0x (get client-id user)) CLIENT)
            )
            ERR_INVALID_CALLER
        )
        (ok true)
    )
)

;; execute-transaction
;; This function executes a transfer out of this contract based on an enforced policy & a list of signatures.
;; If the transaction (not transfer), the serialized tuple/params buff should appended to the message.
(define-public (execute-transaction
        (user-id (string-ascii 64))
        (contract <wrapper-trait>)
        (name (string-ascii 32))
        (instructions (buff 4096))
        (policy-id (string-ascii 64))
        (auth-id (string-ascii 64))
        (type (string-ascii 32))
        (signed-data (list 35 {
            signer: (buff 33),
            signature: (buff 65),
        }))
    )
    (begin
        (try! (assert-valid-caller))
        (let (
                ;; Fetch & check for valid policy
                (policy (unwrap!
                    (contract-call? 'SP51N7RK1H0YS0N7SHZ6TXD5MP03DMWH9YQBJSJK.cf-helpers-state-v0 get-policy CLIENT
                        policy-id
                    )
                    ERR_INVALID_POLICY
                ))
                ;; Unwrap transaction properties
                (transaction-policy (unwrap! (get transaction policy) ERR_INVALID_TYPE))
            )
            ;; Check that policy is active
            (asserts! (get active policy) ERR_INACTIVE_POLICY)
            ;; Check that wrapper matches the policy's authorized wrapper
            (asserts!
                (is-eq (contract-of contract) (get wrapper transaction-policy))
                ERR_INVALID_WRAPPER
            )
            ;; Check that function matches the policy's authorized function
            (asserts! (is-eq name (get function transaction-policy))
                ERR_INVALID_FUNCTION
            )
            ;; Check that all signatures are valid & all signers are in the policy
            (try! (verify-transaction-signature policy-id (get signers policy) type
                (contract-of contract) name auth-id instructions signed-data
            ))
            ;; Check that signing threshold is met
            (asserts! (>= (len signed-data) (get threshold policy))
                ERR_THRESHOLD_NOT_MET
            )
            ;; Cofund wrapper generic contract call
            (try! (as-contract (contract-call? contract router-wrapper name instructions)))
            (print {
                topic: "Transaction Executed",
                policy-id: policy-id,
                type: type,
                function: name,
                wrapper: (contract-of contract),
                auth-id: auth-id,
            })
            (ok true)
        )
    )
)

;; execute-transaction
;; This function executes a transfer out of this contract based on an enforced policy & a list of signatures.
(define-public (execute-transfer
        (user-id (string-ascii 64))
        (policy-id (string-ascii 64))
        (amount uint)
        (token <token-trait>)
        (recipient principal)
        (auth-id (string-ascii 64))
        (signed-data (list 35 {
            signer: (buff 33),
            signature: (buff 65),
        }))
    )
    (begin
        (try! (assert-valid-caller))
        (let (
                ;; Fetch & check for user
                ;; Fetch & check for valid policy
                (policy (unwrap!
                    (contract-call? 'SP51N7RK1H0YS0N7SHZ6TXD5MP03DMWH9YQBJSJK.cf-helpers-state-v0 get-policy CLIENT
                        policy-id
                    )
                    ERR_INVALID_POLICY
                ))
                ;; Unwrap transfer properties
                (transfer-policy (unwrap! (get transfer policy) ERR_INVALID_TYPE))
            )
            ;; Check that policy is active
            (asserts! (get active policy) ERR_INACTIVE_POLICY)
            ;; Check that token matches the policy's authorized token
            (asserts! (is-eq (contract-of token) (get token transfer-policy))
                ERR_INVALID_TOKEN
            )
            ;; Check that all signatures are valid & all signers are in the policy
            (try! (verify-transfer-signature policy-id (get signers policy)
                (get type policy) amount (contract-of token) recipient
                auth-id signed-data
            ))
            ;; Check that signing threshold is met
            (asserts! (>= (len signed-data) (get threshold policy))
                ERR_THRESHOLD_NOT_MET
            )
            ;; Check that amount is less than max-amount
            (asserts! (<= amount (get max-amount transfer-policy))
                ERR_AMOUNT_EXCEEDS_POLICY
            )
            ;; Calculate fee and get fee recipient
            (let (
                    (fee-amount (calculate-fee amount))
                    (fee-recipient (contract-call? 'SP51N7RK1H0YS0N7SHZ6TXD5MP03DMWH9YQBJSJK.cf-helpers-state-v0
                        get-fee-recipient-address
                    ))
                )
                ;; Transfer fee FIRST to fee recipient (if applicable)
                (if (> fee-amount u0)
                    (try! (as-contract (contract-call? token transfer fee-amount tx-sender
                        fee-recipient none
                    )))
                    true
                )
                ;; Transfer FULL amount to recipient (fee is additive, not deducted)
                (try! (as-contract (contract-call? token transfer amount tx-sender recipient none)))
                (print {
                    topic: "Transfer Executed",
                    policy-id: policy-id,
                    type: (get type policy),
                    amount: amount,
                    fee: fee-amount,
                    token: token,
                    recipient: recipient,
                    auth-id: auth-id,
                })
            )
            (ok true)
        )
    )
)

;; execute-deposit
;; This function executes a transfer in (aka deposit | on-ramp) based on an enforced policy & a list of signatures.
;; verify-transaction
;; The following functions verify batched transaction signatures
;; Meant for interacting with on-chain contracts
;; verify-transaction-signature
(define-private (verify-transaction-signature
        (policy-id (string-ascii 64))
        (policy-signers (list 35 (buff 33)))
        (type (string-ascii 32))
        (wrapper principal)
        (function (string-ascii 32))
        (auth-id (string-ascii 64))
        (instructions (buff 4096))
        (signed-data (list 35 {
            signer: (buff 33),
            signature: (buff 65),
        }))
    )
    (begin
        ;; verify fresh auth-id
        (asserts!
            (is-none (contract-call? 'SP51N7RK1H0YS0N7SHZ6TXD5MP03DMWH9YQBJSJK.cf-helpers-state-v0 get-used-auth-ids CLIENT auth-id))
            ERR_AUTH_ID_REPLAY
        )
        ;; Prevent duplicate signer entries in a batch
        (try! (ensure-unique-transaction-signers signed-data))
        ;; Check that all signatures are valid & all signers are in the policy
        (try! (fold verify-transaction-signature-helper signed-data
            (ok {
                type: type,
                wrapper: wrapper,
                function: function,
                auth-id: auth-id,
                policy-id: policy-id,
                policy-signers: policy-signers,
                instructions: instructions,
            })
        ))
        ;; update auth-id
        (unwrap!
            (contract-call? 'SP51N7RK1H0YS0N7SHZ6TXD5MP03DMWH9YQBJSJK.cf-helpers-state-v0 set-auth-id CLIENT "vault"
                auth-id
            )
            ERR_AUTH_ID_REPLAY
        )
        (ok true)
    )
)

;; ensure-unique-transaction-signers
;; Guard against duplicate signers in a batch of transaction signatures
(define-private (ensure-unique-transaction-signers (signed-data (list 35 {
    signer: (buff 33),
    signature: (buff 65),
})))
    (fold ensure-unique-transaction-signers-helper signed-data (ok (list)))
)

(define-private (ensure-unique-transaction-signers-helper
        (signed-entry {
            signer: (buff 33),
            signature: (buff 65),
        })
        (seen-response (response (list 35 (buff 33)) uint))
    )
    (match seen-response
        seen-ok (begin
            ;; duplicate if signer already recorded
            (asserts! (is-none (index-of? seen-ok (get signer signed-entry)))
                ERR_DUPLICATE_SIGNATURE
            )
            (ok (unwrap! (as-max-len? (append seen-ok (get signer signed-entry)) u35)
                ERR_DUPLICATE_SIGNATURE
            ))
        )
        err-response (err err-response)
    )
)

;; verify-transaction-signature-helper
;; This function verifies signature & checks that the signer is in the policy signer set.
(define-private (verify-transaction-signature-helper
        (signed-data {
            signer: (buff 33),
            signature: (buff 65),
        })
        (signed-response (response {
            type: (string-ascii 32),
            wrapper: principal,
            function: (string-ascii 32),
            auth-id: (string-ascii 64),
            policy-id: (string-ascii 64),
            policy-signers: (list 35 (buff 33)),
            instructions: (buff 4096),
        }
            uint
        ))
    )
    (match signed-response
        ok-response (let (
                (address-version (if is-in-mainnet
                    0x16
                    0x1a
                ))
                (signer-pubkey (get signer signed-data))
                (signer-address (unwrap! (principal-construct? address-version (hash160 signer-pubkey))
                    ERR_INVALID_PUBKEY
                ))
                (user-id (get user-id
                    (unwrap!
                        (contract-call? 'SP51N7RK1H0YS0N7SHZ6TXD5MP03DMWH9YQBJSJK.cf-helpers-state-v0
                            get-user-id-by-address signer-address
                        )
                        ERR_INVALID_USER
                    )))
                (user (unwrap!
                    (contract-call? 'SP51N7RK1H0YS0N7SHZ6TXD5MP03DMWH9YQBJSJK.cf-helpers-state-v0 get-user CLIENT user-id)
                    ERR_INVALID_USER
                ))
            )
            (asserts! (get active user) ERR_INACTIVE_USER)
            ;; verify signature
            (asserts!
                (read-valid-transaction-signature (get policy-id ok-response)
                    (get type ok-response) (get wrapper ok-response)
                    (get function ok-response) (get auth-id ok-response)
                    (get instructions ok-response)
                    (get signature signed-data) (get signer signed-data)
                )
                ERR_INVALID_SIGNATURE
            )
            ;; verify signer in policy signer set
            (unwrap!
                (index-of? (get policy-signers ok-response)
                    (get signer signed-data)
                )
                ERR_INVALID_SIGNER
            )
            (ok ok-response)
        )
        err-response (err err-response)
    )
)

;; read-valid-transaction-signature
;; Verify one signature from the list of signatures for an attempted transaction.
;; See `get-signer-key-message-hash` for details on the message hash.
(define-read-only (read-valid-transaction-signature
        (policy-id (string-ascii 64))
        (type (string-ascii 32))
        (wrapper principal)
        (function (string-ascii 32))
        (auth-id (string-ascii 64))
        (instructions (buff 4096))
        (signature (buff 65))
        (signer-key (buff 33))
    )
    (secp256k1-verify
        (get-transaction-signature-message-hash policy-id type wrapper function
            auth-id instructions
        )
        signature signer-key
    )
)

;; get-transaction-signature-message-hash
;; Generate a transaction message hash following SIP018 for signing structured data.
;; The domain is `{ name: "cofund-signer", version: "1.0.0", chain-id: u1 }`.
;; Includes instructions buffer.
(define-read-only (get-transaction-signature-message-hash
        (policy-id (string-ascii 64))
        (type (string-ascii 32))
        (wrapper principal)
        (function (string-ascii 32))
        (auth-id (string-ascii 64))
        (instructions (buff 4096))
    )
    (sha256 (concat SIP018_MSG_PREFIX
        (concat
            (sha256 (unwrap-panic (to-consensus-buff? {
                name: "cofund-signer",
                version: "1.0.0",
                chain-id: u1,
            })))
            (sha256 (unwrap-panic (to-consensus-buff? {
                auth-id: auth-id,
                function: function,
                instructions: instructions,
                policy-id: policy-id,
                type: type,
                wrapper: wrapper,
            })))
        )))
)

;; verify-transfer
;; the following functions verify batched transfer signatures
;; verify-transfer-signature
(define-private (verify-transfer-signature
        (policy-id (string-ascii 64))
        (policy-signers (list 35 (buff 33)))
        (type (string-ascii 128))
        (amount uint)
        (token principal)
        (recipient principal)
        (auth-id (string-ascii 64))
        (signed-data (list 35 {
            signer: (buff 33),
            signature: (buff 65),
        }))
    )
    (begin
        ;; verify fresh auth-id
        (asserts!
            (is-none (contract-call? 'SP51N7RK1H0YS0N7SHZ6TXD5MP03DMWH9YQBJSJK.cf-helpers-state-v0 get-used-auth-ids CLIENT auth-id))
            ERR_AUTH_ID_REPLAY
        )
        ;; Prevent duplicate signer entries in a batch
        (try! (ensure-unique-transfer-signers signed-data))
        ;; Check that all signatures are valid & all signers are in the policy
        (try! (fold verify-transfer-signature-helper signed-data
            (ok {
                type: type,
                amount: amount,
                token: token,
                recipient: recipient,
                auth-id: auth-id,
                policy-id: policy-id,
                policy-signers: policy-signers,
            })
        ))
        ;; update auth-id
        (unwrap!
            (contract-call? 'SP51N7RK1H0YS0N7SHZ6TXD5MP03DMWH9YQBJSJK.cf-helpers-state-v0 set-auth-id CLIENT "vault"
                auth-id
            )
            ERR_AUTH_ID_REPLAY
        )
        (ok true)
    )
)
;; ensure-unique-transfer-signers
;; Guard against duplicate signers in a batch of signatures
(define-private (ensure-unique-transfer-signers (signed-data (list 35 {
    signer: (buff 33),
    signature: (buff 65),
})))
    (fold ensure-unique-transfer-signers-helper signed-data (ok (list)))
)

(define-private (ensure-unique-transfer-signers-helper
        (signed-entry {
            signer: (buff 33),
            signature: (buff 65),
        })
        (seen-response (response (list 35 (buff 33)) uint))
    )
    (match seen-response
        seen-ok (begin
            ;; duplicate if signer already recorded
            (asserts! (is-none (index-of? seen-ok (get signer signed-entry)))
                ERR_DUPLICATE_SIGNATURE
            )
            (ok (unwrap! (as-max-len? (append seen-ok (get signer signed-entry)) u35)
                ERR_DUPLICATE_SIGNATURE
            ))
        )
        err-response (err err-response)
    )
)
;; verify-transfer-signature
;; This function verifies signature & checks that the signer is in the policy signer set.
(define-private (verify-transfer-signature-helper
        (signed-data {
            signer: (buff 33),
            signature: (buff 65),
        })
        (signed-response (response {
            type: (string-ascii 128),
            amount: uint,
            token: principal,
            recipient: principal,
            auth-id: (string-ascii 64),
            policy-id: (string-ascii 64),
            policy-signers: (list 35 (buff 33)),
        }
            uint
        ))
    )
    (match signed-response
        ok-response (let (
                (address-version (if is-in-mainnet
                    0x16
                    0x1a
                ))
                (signer-pubkey (get signer signed-data))
                (signer-address (unwrap! (principal-construct? address-version (hash160 signer-pubkey))
                    ERR_INVALID_PUBKEY
                ))
                (user-id (get user-id
                    (unwrap!
                        (contract-call? 'SP51N7RK1H0YS0N7SHZ6TXD5MP03DMWH9YQBJSJK.cf-helpers-state-v0
                            get-user-id-by-address signer-address
                        )
                        ERR_INVALID_USER
                    )))
                (user (unwrap!
                    (contract-call? 'SP51N7RK1H0YS0N7SHZ6TXD5MP03DMWH9YQBJSJK.cf-helpers-state-v0 get-user CLIENT user-id)
                    ERR_INVALID_USER
                ))
            )
            (asserts! (get active user) ERR_INACTIVE_USER)

            ;; verify signature
            (asserts!
                (read-valid-transfer-signature (get policy-id ok-response)
                    (get type ok-response) (get amount ok-response)
                    (get token ok-response) (get recipient ok-response)
                    (get auth-id ok-response) (get signature signed-data)
                    (get signer signed-data)
                )
                ERR_INVALID_SIGNATURE
            )
            ;; verify signer in policy signer set
            (unwrap!
                (index-of? (get policy-signers ok-response)
                    (get signer signed-data)
                )
                ERR_INVALID_SIGNER
            )
            (ok ok-response)
        )
        err-response (err err-response)
    )
)
;; read-valid-transfer-signature
;; Verify one signature from the list of signatures for an attempted transaction.
;; See `get-signer-key-message-hash` for details on the message hash.
(define-read-only (read-valid-transfer-signature
        (policy-id (string-ascii 64))
        (type (string-ascii 128))
        (amount uint)
        (token principal)
        (recipient principal)
        (auth-id (string-ascii 64))
        (signature (buff 65))
        (signer-key (buff 33))
    )
    (secp256k1-verify
        (get-transfer-signature-message-hash policy-id type amount token
            recipient auth-id
        )
        signature signer-key
    )
)
;; get-transfer-signature-message-hash
;; Generate a transfer message hash following SIP018 for signing structured data.
;; The domain is `{ name: "cofund-signer", version: "1.0.0", chain-id: chain-id }`.
(define-read-only (get-transfer-signature-message-hash
        (policy-id (string-ascii 64))
        (type (string-ascii 128))
        (amount uint)
        (token principal)
        (recipient principal)
        (auth-id (string-ascii 64))
    )
    (sha256 (concat SIP018_MSG_PREFIX
        (concat
            (sha256 (unwrap-panic (to-consensus-buff? {
                name: "cofund-signer",
                version: "1.0.0",
                chain-id: u1,
            })))
            (sha256 (unwrap-panic (to-consensus-buff? {
                amount: amount,
                auth-id: auth-id,
                policy-id: policy-id,
                recipient: recipient,
                token: token,
                type: type,
            })))
        )))
)

(contract-call? 'SP51N7RK1H0YS0N7SHZ6TXD5MP03DMWH9YQBJSJK.cf-helpers-state-v0 new-client CLIENT 0x4ff8f00ad0b92a21de3785c473a59caec625fff18f29bc80446b1f170420d6e3 "314bba3e-c725-4604-8cdd-032e6712a14f" "BUSINESS")

```
