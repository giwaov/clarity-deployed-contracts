;; keeper-5-k3l1cze8a-v-1-1

;; Use all required traits
(use-trait ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait keeper-action-trait 'SP3ESW1QCNQPVXJDGQWT7E45RDCH38QBK9HEJSX4X.keeper-action-trait-v-1-3.keeper-action-trait)
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)
(use-trait xyk-staking-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-staking-trait-v-1-2.xyk-staking-trait)
(use-trait xyk-emissions-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-emissions-trait-v-1-2.xyk-emissions-trait)
(use-trait stableswap-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-2.stableswap-pool-trait)
(use-trait stableswap-staking-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-staking-trait-v-1-2.stableswap-staking-trait)
(use-trait stableswap-emissions-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-emissions-trait-v-1-2.stableswap-emissions-trait)
(use-trait dlmm-pool-trait 'SP3ESW1QCNQPVXJDGQWT7E45RDCH38QBK9HEJSX4X.dlmm-pool-trait-v-0-1.dlmm-pool-trait)
(use-trait dlmm-staking-trait 'SP3ESW1QCNQPVXJDGQWT7E45RDCH38QBK9HEJSX4X.dlmm-staking-trait-v-0-1.dlmm-staking-trait)

;; Error constants
(define-constant ERR_NOT_AUTHORIZED (err u8001))
(define-constant ERR_INVALID_AMOUNT (err u8002))
(define-constant ERR_INVALID_PRINCIPAL (err u8003))
(define-constant ERR_KEEPER_STATUS (err u8004))
(define-constant ERR_INVALID_HELPER_DATA (err u8005))
(define-constant ERR_ACTION_NOT_APPROVED (err u8006))
(define-constant ERR_INVALID_MAX_ACTION_FEE (err u8007))
(define-constant ERR_INVALID_MAX_FEE (err u8008))

;; Maximum BPS
(define-constant BPS u10000)

;; Owner address authorized to interact with this contract
(define-data-var owner-address principal 'SP228WEAEMYX21RW0TT5T38THPNDYPPGGVW2RP570)

;; Bitcoin address authorized to receive bridged rune tokens and bitcoin
(define-data-var bitcoin-address (buff 64) 0x)

;; Keeper address authorized to interact with this contract
(define-data-var keeper-address principal 'SP16BPKS1DN5AYQ5MDHFEYXTSP352QG6JS2E0N8YP)

;; Data var used to enable or disable keeper authorization
(define-data-var keeper-authorized bool true)

;; Data var used to enable or disable approval for all keeper action traits
(define-data-var all-actions-approved bool true)

;; Default max percent fee for all keeper action traits
(define-data-var default-max-action-fee uint u1000)

;; Define max action fees map
(define-map max-action-fees principal uint)

;; Define approved actions map
(define-map approved-actions principal bool)

;; Get owner address
(define-read-only (get-owner-address)
  (ok (var-get owner-address))
)

;; Get Bitcoin address
(define-read-only (get-bitcoin-address)
  (ok (var-get bitcoin-address))
)

;; Get keeper address
(define-read-only (get-keeper-address)
  (ok (var-get keeper-address))
)

;; Get keeper authorization status
(define-read-only (get-keeper-authorized)
  (ok (var-get keeper-authorized))
)

;; Get default max keeper action fee
(define-read-only (get-default-max-action-fee)
  (ok (var-get default-max-action-fee))
)

;; Get max fee for keeper action trait
(define-read-only (get-max-action-fee (action-trait <keeper-action-trait>))
  (ok (default-to (var-get default-max-action-fee) (map-get? max-action-fees (contract-of action-trait))))
)

;; Get approval status for all keeper action traits
(define-read-only (get-all-actions-approved)
  (ok (var-get all-actions-approved))
)

;; Get approval status for keeper action trait
(define-read-only (get-action-approved (action-trait <keeper-action-trait>))
  (ok (or (default-to false (map-get? approved-actions (contract-of action-trait))) (var-get all-actions-approved)))
)

;; Execute action using provided action-trait
(define-public (execute-action-a
    (action-trait <keeper-action-trait>)
    (amount uint) (min-received uint)
    (fee-recipient principal)
    (token-list (optional (list 1000 <ft-trait>)))
    (xyk-pool-list (optional (list 1000 <xyk-pool-trait>)))
    (xyk-staking-list (optional (list 1000 <xyk-staking-trait>)))
    (xyk-emissions-list (optional (list 1000 <xyk-emissions-trait>)))
    (stableswap-pool-list (optional (list 1000 <stableswap-pool-trait>)))
    (stableswap-staking-list (optional (list 1000 <stableswap-staking-trait>)))
    (stableswap-emissions-list (optional (list 1000 <stableswap-emissions-trait>)))
    (dlmm-pool-list (optional (list 1000 <dlmm-pool-trait>)))
    (dlmm-staking-list (optional (list 1000 <dlmm-staking-trait>)))
    (uint-list (optional (list 1000 uint)))
    (bool-list (optional (list 1000 bool)))
    (principal-list (optional (list 1000 principal)))
  )
  (let (
    ;; Get owner, bitcoin, and keeper addresses
    (owner-addr (var-get owner-address))
    (bitcoin-addr (var-get bitcoin-address))
    (keeper-addr (var-get keeper-address))

    ;; Assert contract-caller is authorized keeper or owner
    (authorization-check (asserts! (is-keeper-or-owner) ERR_NOT_AUTHORIZED))

    ;; Get authorization data from helper contract
    (authorization-data (unwrap! (contract-call? 'SP3ESW1QCNQPVXJDGQWT7E45RDCH38QBK9HEJSX4X.keeper-5-helper-v-1-2 get-authorization-data action-trait) ERR_INVALID_HELPER_DATA))
    
    ;; Assert keeper status is enabled and action trait is approved by helper contract
    (keeper-check (asserts! (get keeper-status authorization-data) ERR_KEEPER_STATUS))
    (action-check-a (asserts! (get action-approved authorization-data) ERR_ACTION_NOT_APPROVED))

    ;; Assert keeper action trait is approved by owner
    (action-check-b (asserts! (unwrap-panic (get-action-approved action-trait)) ERR_ACTION_NOT_APPROVED))

    ;; Assert action fee is less than or equal to max action fee
    (action-fee (get action-fee authorization-data))
    (max-action-fee (unwrap-panic (get-max-action-fee action-trait)))
    (max-action-fee-check (asserts! (<= action-fee max-action-fee) ERR_INVALID_MAX_ACTION_FEE))

    ;; Assert amount is greater than 0
    (amount-check (asserts! (> amount u0) ERR_INVALID_AMOUNT))

    ;; Assert fee-recipient is standard principal
    (fee-recipient-check (asserts! (is-standard fee-recipient) ERR_INVALID_PRINCIPAL))

    ;; Execute action from keeper action trait
    (execute-keeper-action (try! (as-contract (contract-call? action-trait execute-action
                                              amount min-received
                                              fee-recipient owner-addr bitcoin-addr keeper-addr
                                              token-list
                                              xyk-pool-list xyk-staking-list xyk-emissions-list
                                              stableswap-pool-list stableswap-staking-list stableswap-emissions-list
                                              dlmm-pool-list dlmm-staking-list
                                              uint-list bool-list principal-list))))
    (caller contract-caller)
  )
    (begin
      ;; Print action data and return true
      (print {
        action: "execute-action-a",
        contract: (as-contract tx-sender),
        caller: caller,
        data: {
          action-contract: (contract-of action-trait),
          amount: amount,
          min-received: min-received,
          fee-recipient: fee-recipient,
          owner-address: owner-addr,
          bitcoin-address: bitcoin-addr,
          keeper-address: keeper-addr,
          token-list: token-list,
          uint-list: uint-list,
          bool-list: bool-list,
          principal-list: principal-list,
          action-fee: action-fee,
          max-action-fee: max-action-fee,
          execute-keeper-action: execute-keeper-action
        }
      })
      (print {
        action: "execute-action-a",
        contract: (as-contract tx-sender),
        caller: caller,
        data: {
          action-contract: (contract-of action-trait),
          xyk-pool-list: xyk-pool-list,
          xyk-staking-list: xyk-staking-list,
          xyk-emissions-list: xyk-emissions-list
        }
      })
      (print {
        action: "execute-action-a",
        contract: (as-contract tx-sender),
        caller: caller,
        data: {
          action-contract: (contract-of action-trait),
          stableswap-pool-list: stableswap-pool-list,
          stableswap-staking-list: stableswap-staking-list,
          stableswap-emissions-list: stableswap-emissions-list
        }
      })
      (print {
        action: "execute-action-a",
        contract: (as-contract tx-sender),
        caller: caller,
        data: {
          action-contract: (contract-of action-trait),
          dlmm-staking-list: dlmm-staking-list,
          dlmm-pool-list: dlmm-pool-list
        }
      })
      (ok execute-keeper-action)
    )
  )
)

;; Withdraw tokens from this keeper contract
(define-public (withdraw-tokens (token-trait <ft-trait>) (amount uint) (recipient principal))
  (let (
    (token-contract (contract-of token-trait))
    (caller contract-caller)
  )
    (begin
      ;; Assert caller is owner
      (asserts! (is-eq caller (var-get owner-address)) ERR_NOT_AUTHORIZED)

      ;; Assert amount is greater than 0
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)

      ;; Assert recipient is standard principal
      (asserts! (is-standard recipient) ERR_INVALID_PRINCIPAL)

      ;; Transfer tokens from the contract to recipient
      (try! (as-contract (contract-call? token-trait transfer amount tx-sender recipient none)))

      ;; Print withdraw data and return true
      (print {
        action: "withdraw-tokens",
        caller: caller,
        data: {
          token-contract: token-contract,
          amount: amount,
          recipient: recipient
        }
      })
      (ok true)
    )
  )
)

;; Set owner address authorized to interact with this contract
(define-public (set-owner-address (address principal))
  (let (
    (caller contract-caller)
  )
    (begin
      ;; Assert caller is owner
      (asserts! (is-eq caller (var-get owner-address)) ERR_NOT_AUTHORIZED)

      ;; Assert address is standard principal
      (asserts! (is-standard address) ERR_INVALID_PRINCIPAL)

      ;; Set owner-address to address
      (var-set owner-address address)

      ;; Print function data and return true
      (print {action: "set-owner-address", caller: caller, data: {address: address}})
      (ok true)
    )
  )
)

;; Set Bitcoin address authorized to receive bridged rune tokens and bitcoin
(define-public (set-bitcoin-address (address (buff 64)))
  (let (
    (caller contract-caller)
  )
    (begin
      ;; Assert caller is owner
      (asserts! (is-eq caller (var-get owner-address)) ERR_NOT_AUTHORIZED)

      ;; Set bitcoin-address to address
      (var-set bitcoin-address address)

      ;; Print function data and return true
      (print {action: "set-bitcoin-address", caller: caller, data: {address: address}})
      (ok true)
    )
  )
)

;; Set keeper address authorized to interact with this contract
(define-public (set-keeper-address (address principal))
  (let (
    (caller contract-caller)
  )
    (begin
      ;; Assert contract-caller is authorized keeper or owner
      (asserts! (is-keeper-or-owner) ERR_NOT_AUTHORIZED)

      ;; Assert address is standard principal
      (asserts! (is-standard address) ERR_INVALID_PRINCIPAL)

      ;; Set keeper-address to address
      (var-set keeper-address address)

      ;; Print function data and return true
      (print {action: "set-keeper-address", caller: caller, data: {address: address}})
      (ok true)
    )
  )
)

;; Enable or disable keeper authorization
(define-public (set-keeper-authorized (authorized bool))
  (let (
    (caller contract-caller)
  )
    (begin
      ;; Assert caller is owner
      (asserts! (is-eq caller (var-get owner-address)) ERR_NOT_AUTHORIZED)

      ;; Set keeper-authorized to authorized
      (var-set keeper-authorized authorized)

      ;; Print function data and return true
      (print {action: "set-keeper-authorized", caller: caller, data: {authorized: authorized}})
      (ok true)
    )
  )
)

;; Set default max percent fee for all keeper action traits
(define-public (set-default-max-action-fee (max-fee uint))
  (let (
    (caller contract-caller)
  )
    (begin
      ;; Assert caller is owner
      (asserts! (is-eq caller (var-get owner-address)) ERR_NOT_AUTHORIZED)

      ;; Assert max-fee is less than maximum BPS
      (asserts! (< max-fee BPS) ERR_INVALID_MAX_FEE)

      ;; Set default-max-action-fee to max-fee
      (var-set default-max-action-fee max-fee)

      ;; Print function data and return true
      (print {action: "set-default-max-action-fee", caller: caller, data: {max-fee: max-fee}})
      (ok true)
    )
  )
)

;; Set max percent fee for keeper action trait
(define-public (set-max-action-fee (action-trait <keeper-action-trait>) (max-fee uint))
  (let (
    (action-contract (contract-of action-trait))
    (caller contract-caller)
  )
    (begin
      ;; Assert caller is owner
      (asserts! (is-eq caller (var-get owner-address)) ERR_NOT_AUTHORIZED)

      ;; Assert max-fee is less than maximum BPS
      (asserts! (< max-fee BPS) ERR_INVALID_MAX_FEE)

      ;; Set max fee for keeper action trait in max-action-fees map
      (map-set max-action-fees action-contract max-fee)

      ;; Print function data and return true
      (print {
        action: "set-max-action-fee",
        caller: caller,
        data: {
          action-contract: action-contract,
          max-fee: max-fee
        }
      })
      (ok true)
    )
  )
)

;; Enable or disable approval for all keeper action traits
(define-public (set-all-actions-approved (approved bool))
  (let (
    (caller contract-caller)
  )
    (begin
      ;; Assert caller is owner
      (asserts! (is-eq caller (var-get owner-address)) ERR_NOT_AUTHORIZED)

      ;; Set all-actions-approved to approved
      (var-set all-actions-approved approved)

      ;; Print function data and return true
      (print {action: "set-all-actions-approved", caller: caller, data: {approved: approved}})
      (ok true)
    )
  )
)

;; Set approval status for keeper action trait
(define-public (set-action-approved (action-trait <keeper-action-trait>) (approved bool))
  (let (
    (action-contract (contract-of action-trait))
    (caller contract-caller)
  )
    (begin
      ;; Assert caller is owner
      (asserts! (is-eq caller (var-get owner-address)) ERR_NOT_AUTHORIZED)

      ;; Set approval status for keeper action trait in approved-actions map
      (map-set approved-actions action-contract approved)

      ;; Print function data and return true
      (print {
        action: "set-action-approved",
        caller: caller,
        data: {
          action-contract: action-contract,
          approved: approved
        }
      })
      (ok true)
    )
  )
)

;; Check if contract-caller is authorized keeper or owner
(define-private (is-keeper-or-owner)
  (or
    (and (is-eq contract-caller (var-get keeper-address)) (var-get keeper-authorized))
    (is-eq contract-caller (var-get owner-address))
  )
)