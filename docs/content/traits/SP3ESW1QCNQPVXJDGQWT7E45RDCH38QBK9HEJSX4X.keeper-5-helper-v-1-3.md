---
title: "Trait keeper-5-helper-v-1-3"
draft: true
---
```
;; keeper-5-helper-v-1-3

;; Use all required traits
(use-trait ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait keeper-action-trait .keeper-action-trait-v-1-3.keeper-action-trait)
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)
(use-trait xyk-staking-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-staking-trait-v-1-2.xyk-staking-trait)
(use-trait xyk-emissions-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-emissions-trait-v-1-2.xyk-emissions-trait)
(use-trait stableswap-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-2.stableswap-pool-trait)
(use-trait stableswap-staking-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-staking-trait-v-1-2.stableswap-staking-trait)
(use-trait stableswap-emissions-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-emissions-trait-v-1-2.stableswap-emissions-trait)
(use-trait dlmm-pool-trait .dlmm-pool-trait-v-0-1.dlmm-pool-trait)
(use-trait dlmm-staking-trait .dlmm-staking-trait-v-0-1.dlmm-staking-trait)

;; Error constants
(define-constant ERR_NOT_AUTHORIZED (err u9001))
(define-constant ERR_INVALID_AMOUNT (err u9002))
(define-constant ERR_ALREADY_ADMIN (err u9003))
(define-constant ERR_ADMIN_LIMIT_REACHED (err u9004))
(define-constant ERR_ADMIN_NOT_IN_LIST (err u9005))
(define-constant ERR_CANNOT_REMOVE_CONTRACT_DEPLOYER (err u9006))
(define-constant ERR_KEEPER_STATUS (err u9007))
(define-constant ERR_ACTION_NOT_APPROVED (err u9008))
(define-constant ERR_INVALID_FEE (err u9009))

;; Contract deployer address
(define-constant CONTRACT_DEPLOYER tx-sender)

;; Maximum BPS
(define-constant BPS u10000)

;; Admins list and helper var used to remove admins
(define-data-var admins (list 5 principal) (list tx-sender))
(define-data-var admin-helper principal tx-sender)

;; Data var used to enable or disable keeper status
(define-data-var keeper-status bool true)

;; Data var used to enable or disable approval for all keeper action traits
(define-data-var all-actions-approved bool false)

;; Default percent fee for all keeper action traits
(define-data-var default-action-fee uint u0)

;; Define action fees map
(define-map action-fees principal uint)

;; Define approved actions map
(define-map approved-actions principal bool)

;; Get admins list
(define-read-only (get-admins)
  (ok (var-get admins))
)

;; Get admin helper var
(define-read-only (get-admin-helper)
  (ok (var-get admin-helper))
)

;; Get keeper status
(define-read-only (get-keeper-status)
  (ok (var-get keeper-status))
)

;; Get default keeper action fee
(define-read-only (get-default-action-fee)
  (ok (var-get default-action-fee))
)

;; Get fee for keeper action trait
(define-read-only (get-action-fee (action-contract principal))
  (ok (default-to (var-get default-action-fee) (map-get? action-fees action-contract)))
)

;; Get fee given keeper action trait and amount
(define-read-only (get-action-fee-amount (action-contract principal) (amount uint))
  (ok (/ (* amount (default-to (var-get default-action-fee) (map-get? action-fees action-contract))) BPS))
)

;; Get approval status for all keeper action traits
(define-read-only (get-all-actions-approved)
  (ok (var-get all-actions-approved))
)

;; Get approval status for keeper action trait
(define-read-only (get-action-approved (action-contract principal))
  (ok (or (default-to false (map-get? approved-actions action-contract)) (var-get all-actions-approved)))
)

;; Get authorization data for keeper and keeper action trait
(define-read-only (get-authorization-data (action-contract principal))
  (ok {
    keeper-status: (var-get keeper-status),
    action-approved: (or (default-to false (map-get? approved-actions action-contract)) (var-get all-actions-approved)),
    action-fee: (default-to (var-get default-action-fee) (map-get? action-fees action-contract))
  })
)

;; Get output for execute-action-a function
(define-public (get-action-a
    (action-trait <keeper-action-trait>)
    (amount uint)
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
    ;; Assert keeper status is enabled
    (keeper-check (asserts! (var-get keeper-status) ERR_KEEPER_STATUS))

    ;; Assert keeper action trait is approved
    (action-check (asserts! (unwrap-panic (get-action-approved (contract-of action-trait))) ERR_ACTION_NOT_APPROVED))

    ;; Assert amount is greater than 0
    (amount-check (asserts! (> amount u0) ERR_INVALID_AMOUNT))

    ;; Get action data from keeper action trait
    (keeper-output-result (try! (as-contract? ((with-all-assets-unsafe)) (try! (contract-call? action-trait get-output
                                                                               amount u0
                                                                               tx-sender tx-sender 0x tx-sender
                                                                               token-list
                                                                               xyk-pool-list xyk-staking-list xyk-emissions-list
                                                                               stableswap-pool-list stableswap-staking-list stableswap-emissions-list
                                                                               dlmm-pool-list dlmm-staking-list
                                                                               uint-list bool-list principal-list)))))
  )
    ;; Return keeper-output-result
    (ok keeper-output-result)
  )
)

;; Add an admin to the admins list
(define-public (add-admin (admin principal))
  (let (
    (admins-list (var-get admins))
    (caller tx-sender)
  )
    (begin
      ;; Assert caller is an existing admin and new admin is not in admins-list
      (asserts! (is-some (index-of admins-list caller)) ERR_NOT_AUTHORIZED)
      (asserts! (is-none (index-of admins-list admin)) ERR_ALREADY_ADMIN)

      ;; Add admin to list with max length of 5
      (var-set admins (unwrap! (as-max-len? (append admins-list admin) u5) ERR_ADMIN_LIMIT_REACHED))

      ;; Print add admin data and return true
      (print {action: "add-admin", caller: caller, data: {admin: admin}})
      (ok true)
    )
  )
)

;; Remove an admin from the admins list
(define-public (remove-admin (admin principal))
  (let (
    (admins-list (var-get admins))
    (caller tx-sender)
  )
    (begin
      ;; Assert caller is an existing admin and admin to remove is in admins-list
      (asserts! (is-some (index-of admins-list caller)) ERR_NOT_AUTHORIZED)
      (asserts! (is-some (index-of admins-list admin)) ERR_ADMIN_NOT_IN_LIST)

      ;; Assert contract deployer cannot be removed
      (asserts! (not (is-eq admin CONTRACT_DEPLOYER)) ERR_CANNOT_REMOVE_CONTRACT_DEPLOYER)

      ;; Set admin-helper to admin to remove and filter admins-list to remove admin
      (var-set admin-helper admin)
      (var-set admins (filter admin-not-removable admins-list))

      ;; Print remove admin data and return true
      (print {action: "remove-admin", caller: caller, data: {admin: admin}})
      (ok true)
    )
  )
)

;; Enable or disable keeper status
(define-public (set-keeper-status (status bool))
  (let (
    (caller tx-sender)
  )
    (begin
      ;; Assert caller is an admin
      (asserts! (is-some (index-of (var-get admins) caller)) ERR_NOT_AUTHORIZED)

      ;; Set keeper-status to status
      (var-set keeper-status status)

      ;; Print function data and return true
      (print {action: "set-keeper-status", caller: caller, data: {status: status}})
      (ok true)
    )
  )
)

;; Set default percent fee for all keeper action traits
(define-public (set-default-action-fee (fee uint))
  (let (
    (caller tx-sender)
  )
    (begin
      ;; Assert caller is an admin
      (asserts! (is-some (index-of (var-get admins) caller)) ERR_NOT_AUTHORIZED)

      ;; Assert fee is less than maximum BPS
      (asserts! (< fee BPS) ERR_INVALID_FEE)

      ;; Set default-action-fee to fee
      (var-set default-action-fee fee)

      ;; Print function data and return true
      (print {action: "set-default-action-fee", caller: caller, data: {fee: fee}})
      (ok true)
    )
  )
)

;; Set percent fee for keeper action trait
(define-public (set-action-fee (action-trait <keeper-action-trait>) (fee uint))
  (let (
    (action-contract (contract-of action-trait))
    (caller tx-sender)
  )
    (begin
      ;; Assert caller is an admin
      (asserts! (is-some (index-of (var-get admins) caller)) ERR_NOT_AUTHORIZED)

      ;; Assert fee is less than maximum BPS
      (asserts! (< fee BPS) ERR_INVALID_FEE)

      ;; Set fee for keeper action trait in action-fees map
      (map-set action-fees action-contract fee)

      ;; Print function data and return true
      (print {
        action: "set-action-fee",
        caller: caller,
        data: {
          action-contract: action-contract,
          fee: fee
        }
      })
      (ok true)
    )
  )
)

;; Enable or disable approval for all keeper action traits
(define-public (set-all-actions-approved (approved bool))
  (let (
    (caller tx-sender)
  )
    (begin
      ;; Assert caller is an admin
      (asserts! (is-some (index-of (var-get admins) caller)) ERR_NOT_AUTHORIZED)

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
    (caller tx-sender)
  )
    (begin
      ;; Assert caller is an admin
      (asserts! (is-some (index-of (var-get admins) caller)) ERR_NOT_AUTHORIZED)

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

;; Helper function for removing an admin
(define-private (admin-not-removable (admin principal))
  (not (is-eq admin (var-get admin-helper)))
)
```
