(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-subscription-expired (err u105))

(define-data-var account-nonce uint u0)
(define-data-var lead-nonce uint u0)

(define-map customer-accounts
  uint
  {
    organization: principal,
    subscription-tier: (string-ascii 20),
    monthly-fee: uint,
    seats: uint,
    active: bool,
    subscription-end: uint
  }
)

(define-map sales-leads
  uint
  {
    account-id: uint,
    lead-data-hash: (buff 32),
    status: (string-ascii 20),
    created-at: uint,
    assigned-to: (optional principal),
    conversion-value: uint,
    converted: bool
  }
)

(define-map ai-interactions
  {account-id: uint, interaction-id: uint}
  {
    interaction-type: (string-ascii 30),
    data-hash: (buff 32),
    timestamp: uint,
    ai-model-used: (string-ascii 30)
  }
)

(define-map org-accounts principal (list 20 uint))
(define-map account-leads uint (list 500 uint))

(define-public (create-account (subscription-tier (string-ascii 20)) (monthly-fee uint) (seats uint) (duration-blocks uint))
  (let
    (
      (account-id (+ (var-get account-nonce) u1))
      (total-cost (* monthly-fee (/ duration-blocks u4320)))
    )
    (asserts! (> monthly-fee u0) err-invalid-amount)
    (asserts! (> seats u0) err-invalid-amount)
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    (map-set customer-accounts account-id
      {
        organization: tx-sender,
        subscription-tier: subscription-tier,
        monthly-fee: monthly-fee,
        seats: seats,
        active: true,
        subscription-end: (+ stacks-block-height duration-blocks)
      }
    )
    (map-set org-accounts tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? org-accounts tx-sender)) account-id) u20)))
    (var-set account-nonce account-id)
    (ok account-id)
  )
)

(define-public (create-lead (account-id uint) (lead-data-hash (buff 32)))
  (let
    (
      (account (unwrap! (map-get? customer-accounts account-id) err-not-found))
      (lead-id (+ (var-get lead-nonce) u1))
    )
    (asserts! (is-eq tx-sender (get organization account)) err-unauthorized)
    (asserts! (get active account) err-subscription-expired)
    (asserts! (< stacks-block-height (get subscription-end account)) err-subscription-expired)
    (map-set sales-leads lead-id
      {
        account-id: account-id,
        lead-data-hash: lead-data-hash,
        status: "new",
        created-at: stacks-block-height,
        assigned-to: none,
        conversion-value: u0,
        converted: false
      }
    )
    (map-set account-leads account-id
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? account-leads account-id)) lead-id) u500)))
    (var-set lead-nonce lead-id)
    (ok lead-id)
  )
)

(define-public (update-lead-status (lead-id uint) (new-status (string-ascii 20)))
  (let
    (
      (lead (unwrap! (map-get? sales-leads lead-id) err-not-found))
      (account (unwrap! (map-get? customer-accounts (get account-id lead)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get organization account)) err-unauthorized)
    (map-set sales-leads lead-id (merge lead {status: new-status}))
    (ok true)
  )
)

(define-public (convert-lead (lead-id uint) (conversion-value uint))
  (let
    (
      (lead (unwrap! (map-get? sales-leads lead-id) err-not-found))
      (account (unwrap! (map-get? customer-accounts (get account-id lead)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get organization account)) err-unauthorized)
    (asserts! (not (get converted lead)) err-already-exists)
    (map-set sales-leads lead-id (merge lead {
      converted: true,
      conversion-value: conversion-value,
      status: "converted"
    }))
    (ok true)
  )
)

(define-public (renew-subscription (account-id uint) (duration-blocks uint))
  (let
    (
      (account (unwrap! (map-get? customer-accounts account-id) err-not-found))
      (total-cost (* (get monthly-fee account) (/ duration-blocks u4320)))
    )
    (asserts! (is-eq tx-sender (get organization account)) err-unauthorized)
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    (map-set customer-accounts account-id (merge account {
      subscription-end: (+ (get subscription-end account) duration-blocks),
      active: true
    }))
    (ok true)
  )
)

(define-read-only (get-account (account-id uint))
  (ok (map-get? customer-accounts account-id))
)

(define-read-only (get-lead (lead-id uint))
  (ok (map-get? sales-leads lead-id))
)

(define-read-only (get-org-accounts (org principal))
  (ok (map-get? org-accounts org))
)

(define-read-only (get-account-leads (account-id uint))
  (ok (map-get? account-leads account-id))
)
