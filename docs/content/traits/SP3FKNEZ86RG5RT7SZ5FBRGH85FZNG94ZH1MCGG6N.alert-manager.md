---
title: "Trait alert-manager"
draft: true
---
```
;; Alert Manager Contract
;; Create, manage, and configure custom blockchain alerts
;; Built with Clarity 4 features for Stacks Builder Challenge

;; ============================================
;; CONSTANTS & ERRORS
;; ============================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-ALERT-NOT-FOUND (err u201))
(define-constant ERR-ALERT-LIMIT-REACHED (err u202))
(define-constant ERR-INVALID-ALERT-TYPE (err u203))
(define-constant ERR-ALERT-ALREADY-EXISTS (err u204))
(define-constant ERR-INSUFFICIENT-BALANCE (err u205))
(define-constant ERR-NOT-REGISTERED (err u206))
(define-constant ERR-INVALID-THRESHOLD (err u207))
(define-constant ERR-SUBSCRIPTION-REQUIRED (err u208))

;; Alert types
(define-constant ALERT-TYPE-WHALE-TRANSFER u1)
(define-constant ALERT-TYPE-CONTRACT-DEPLOY u2)
(define-constant ALERT-TYPE-NFT-MINT u3)
(define-constant ALERT-TYPE-TOKEN-LAUNCH u4)
(define-constant ALERT-TYPE-LARGE-SWAP u5)
(define-constant ALERT-TYPE-PRICE-THRESHOLD u6)
(define-constant ALERT-TYPE-CONTRACT-CALL u7)
(define-constant ALERT-TYPE-CUSTOM u8)

;; Alert creation fee (in microSTX)
(define-constant ALERT-CREATION-FEE u1000000) ;; 1 STX per alert

;; ============================================
;; DATA VARIABLES
;; ============================================

(define-data-var alert-nonce uint u0)
(define-data-var total-alerts-created uint u0)
(define-data-var total-alerts-triggered uint u0)
(define-data-var total-fees-collected uint u0)
(define-data-var fee-vault-principal principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; ============================================
;; DATA MAPS
;; ============================================

;; Main alert storage
(define-map alerts
  uint  ;; alert-id
  {
    owner: principal,
    alert-type: uint,
    name: (string-ascii 64),
    description: (string-utf8 256),
    threshold: uint,
    target-contract: (optional principal),
    target-function: (optional (string-ascii 128)),
    webhook-url: (optional (string-ascii 256)),
    is-active: bool,
    created-at: uint,
    triggered-count: uint,
    last-triggered: uint
  }
)

;; User's alert IDs
(define-map user-alerts
  principal
  (list 100 uint)
)

;; Track which contracts are being monitored
(define-map monitored-contracts
  principal
  {
    monitor-count: uint,
    first-monitored: uint
  }
)

;; Alert type statistics
(define-map alert-type-stats
  uint
  {
    total-created: uint,
    total-triggered: uint
  }
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

;; Get alert by ID
(define-read-only (get-alert (alert-id uint))
  (map-get? alerts alert-id)
)

;; Get user's alerts
(define-read-only (get-user-alerts (user principal))
  (default-to (list) (map-get? user-alerts user))
)

;; Get user's alert count
(define-read-only (get-user-alert-count (user principal))
  (len (default-to (list) (map-get? user-alerts user)))
)

;; Get platform statistics
(define-read-only (get-stats)
  {
    total-alerts: (var-get total-alerts-created),
    total-triggered: (var-get total-alerts-triggered),
    total-fees: (var-get total-fees-collected),
    current-nonce: (var-get alert-nonce)
  }
)

;; Get alert type stats
(define-read-only (get-alert-type-stats (alert-type uint))
  (default-to 
    { total-created: u0, total-triggered: u0 }
    (map-get? alert-type-stats alert-type)
  )
)

;; Check if alert type is valid
(define-read-only (is-valid-alert-type (alert-type uint))
  (and (>= alert-type u1) (<= alert-type u8))
)

;; Get monitored contract info
(define-read-only (get-monitored-contract (contract-principal principal))
  (map-get? monitored-contracts contract-principal)
)

;; ============================================
;; PRIVATE FUNCTIONS
;; ============================================

;; Update alert type statistics
(define-private (update-alert-type-created (alert-type uint))
  (let
    (
      (current-stats (default-to { total-created: u0, total-triggered: u0 } 
                      (map-get? alert-type-stats alert-type)))
    )
    (map-set alert-type-stats alert-type
      (merge current-stats {
        total-created: (+ (get total-created current-stats) u1)
      })
    )
  )
)

(define-private (update-alert-type-triggered (alert-type uint))
  (let
    (
      (current-stats (default-to { total-created: u0, total-triggered: u0 } 
                      (map-get? alert-type-stats alert-type)))
    )
    (map-set alert-type-stats alert-type
      (merge current-stats {
        total-triggered: (+ (get total-triggered current-stats) u1)
      })
    )
  )
)

;; ============================================
;; PUBLIC FUNCTIONS
;; ============================================

;; Create a new alert
(define-public (create-alert 
    (alert-type uint)
    (name (string-ascii 64))
    (description (string-utf8 256))
    (threshold uint)
    (target-contract (optional principal))
    (target-function (optional (string-ascii 128)))
    (webhook-url (optional (string-ascii 256)))
  )
  (let
    (
      (caller tx-sender)
      (alert-id (+ (var-get alert-nonce) u1))
      (user-current-alerts (default-to (list) (map-get? user-alerts caller)))
    )
    ;; Validate alert type
    (asserts! (is-valid-alert-type alert-type) ERR-INVALID-ALERT-TYPE)
    
    ;; Validate threshold (must be > 0 for whale transfers, swaps, etc.)
    (asserts! (or (> threshold u0) (is-eq alert-type ALERT-TYPE-CONTRACT-DEPLOY) (is-eq alert-type ALERT-TYPE-TOKEN-LAUNCH)) ERR-INVALID-THRESHOLD)
    
    ;; Check user is registered and can create alerts
    (asserts! (contract-call? .stackpulse-registry can-create-alert caller) ERR-ALERT-LIMIT-REACHED)
    
    ;; Charge creation fee
    (try! (stx-transfer? ALERT-CREATION-FEE caller (var-get fee-vault-principal)))
    
    ;; Create the alert
    (map-set alerts alert-id
      {
        owner: caller,
        alert-type: alert-type,
        name: name,
        description: description,
        threshold: threshold,
        target-contract: target-contract,
        target-function: target-function,
        webhook-url: webhook-url,
        is-active: true,
        created-at: stacks-block-height,
        triggered-count: u0,
        last-triggered: u0
      }
    )
    
    ;; Add to user's alerts list - Clarity 4 enhanced list operations
    (map-set user-alerts caller
      (unwrap! (as-max-len? (append user-current-alerts alert-id) u100) ERR-ALERT-LIMIT-REACHED)
    )
    
    ;; Update monitored contracts if applicable
    (match target-contract
      contract-to-monitor 
        (let
          (
            (current-monitor (default-to { monitor-count: u0, first-monitored: stacks-block-height } 
                              (map-get? monitored-contracts contract-to-monitor)))
          )
          (map-set monitored-contracts contract-to-monitor
            (merge current-monitor {
              monitor-count: (+ (get monitor-count current-monitor) u1)
            })
          )
        )
      true
    )
    
    ;; Update counters
    (var-set alert-nonce alert-id)
    (var-set total-alerts-created (+ (var-get total-alerts-created) u1))
    (var-set total-fees-collected (+ (var-get total-fees-collected) ALERT-CREATION-FEE))
    
    ;; Update alert type stats
    (update-alert-type-created alert-type)
    
    ;; Notify registry contract
    (try! (contract-call? .stackpulse-registry increment-alerts caller))
    
    ;; Emit event for chainhook
    (print {
      event: "alert-created",
      alert-id: alert-id,
      owner: caller,
      alert-type: alert-type,
      name: name,
      threshold: threshold,
      target-contract: target-contract,
      block: stacks-block-height
    })
    
    (ok alert-id)
  )
)

;; Toggle alert active status
(define-public (toggle-alert (alert-id uint))
  (let
    (
      (caller tx-sender)
      (alert-data (unwrap! (map-get? alerts alert-id) ERR-ALERT-NOT-FOUND))
    )
    ;; Only owner can toggle
    (asserts! (is-eq (get owner alert-data) caller) ERR-NOT-AUTHORIZED)
    
    (map-set alerts alert-id
      (merge alert-data {
        is-active: (not (get is-active alert-data))
      })
    )
    
    (print {
      event: "alert-toggled",
      alert-id: alert-id,
      is-active: (not (get is-active alert-data)),
      block: stacks-block-height
    })
    
    (ok (not (get is-active alert-data)))
  )
)

;; Update alert threshold
(define-public (update-threshold (alert-id uint) (new-threshold uint))
  (let
    (
      (caller tx-sender)
      (alert-data (unwrap! (map-get? alerts alert-id) ERR-ALERT-NOT-FOUND))
    )
    (asserts! (is-eq (get owner alert-data) caller) ERR-NOT-AUTHORIZED)
    (asserts! (> new-threshold u0) ERR-INVALID-THRESHOLD)
    
    (map-set alerts alert-id
      (merge alert-data { threshold: new-threshold })
    )
    
    (print {
      event: "alert-threshold-updated",
      alert-id: alert-id,
      old-threshold: (get threshold alert-data),
      new-threshold: new-threshold,
      block: stacks-block-height
    })
    
    (ok true)
  )
)

;; Update webhook URL (requires subscription)
(define-public (update-webhook (alert-id uint) (new-webhook (optional (string-ascii 256))))
  (let
    (
      (caller tx-sender)
      (alert-data (unwrap! (map-get? alerts alert-id) ERR-ALERT-NOT-FOUND))
    )
    (asserts! (is-eq (get owner alert-data) caller) ERR-NOT-AUTHORIZED)
    (asserts! (contract-call? .stackpulse-registry is-subscription-active caller) ERR-SUBSCRIPTION-REQUIRED)
    
    (map-set alerts alert-id
      (merge alert-data { webhook-url: new-webhook })
    )
    
    (print {
      event: "alert-webhook-updated",
      alert-id: alert-id,
      block: stacks-block-height
    })
    
    (ok true)
  )
)

;; Record alert triggered (called by admin/oracle)
(define-public (record-trigger (alert-id uint))
  (let
    (
      (alert-data (unwrap! (map-get? alerts alert-id) ERR-ALERT-NOT-FOUND))
    )
    ;; Only contract owner can record triggers
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    ;; Update alert
    (map-set alerts alert-id
      (merge alert-data {
        triggered-count: (+ (get triggered-count alert-data) u1),
        last-triggered: stacks-block-height
      })
    )
    
    ;; Update global counter
    (var-set total-alerts-triggered (+ (var-get total-alerts-triggered) u1))
    
    ;; Update type stats
    (update-alert-type-triggered (get alert-type alert-data))
    
    ;; Emit trigger event for chainhook
    (print {
      event: "alert-triggered",
      alert-id: alert-id,
      owner: (get owner alert-data),
      alert-type: (get alert-type alert-data),
      triggered-count: (+ (get triggered-count alert-data) u1),
      block: stacks-block-height
    })
    
    (ok true)
  )
)

;; Delete alert
(define-public (delete-alert (alert-id uint))
  (let
    (
      (caller tx-sender)
      (alert-data (unwrap! (map-get? alerts alert-id) ERR-ALERT-NOT-FOUND))
    )
    (asserts! (is-eq (get owner alert-data) caller) ERR-NOT-AUTHORIZED)
    
    ;; Deactivate (we don't actually delete to preserve history)
    (map-set alerts alert-id
      (merge alert-data { is-active: false })
    )
    
    (print {
      event: "alert-deleted",
      alert-id: alert-id,
      owner: caller,
      block: stacks-block-height
    })
    
    (ok true)
  )
)

;; Update fee vault (admin only)
(define-public (set-fee-vault (new-vault principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set fee-vault-principal new-vault)
    (ok true)
  )
)

```
