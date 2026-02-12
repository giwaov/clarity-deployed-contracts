---
title: "Trait emergency-controls"
draft: true
---
```
;; Title: Emergency Controls
;; Version: 1.0.0
;; Summary: Circuit breaker and emergency pause system
;; Description: Provides global and per-stream pause mechanisms with admin controls

;; ============================================
;; Constants - Error Codes
;; ============================================
(define-constant ERR_UNAUTHORIZED (err u4000))
(define-constant ERR_ALREADY_PAUSED (err u4001))
(define-constant ERR_NOT_PAUSED (err u4002))
(define-constant ERR_EMERGENCY_MODE_ACTIVE (err u4003))
(define-constant ERR_COOLDOWN_ACTIVE (err u4004))

;; ============================================
;; Constants - Configuration
;; ============================================
(define-constant COOLDOWN_BLOCKS u144) ;; ~24 hours cooldown after unpause

;; ============================================
;; Data Variables - Global State
;; ============================================
(define-data-var contract-owner principal tx-sender)
(define-data-var global-paused bool false)
(define-data-var emergency-mode bool false)
(define-data-var last-pause-block uint u0)
(define-data-var last-unpause-block uint u0)

;; ============================================
;; Data Maps - Per-Stream Pause
;; ============================================
(define-map stream-paused uint bool)
(define-map stream-pause-history
    uint
    (list 50 { paused: bool, block: uint, by: principal })
)

;; ============================================
;; Data Maps - Authorized Admins
;; ============================================
(define-map emergency-admins principal bool)

;; ============================================
;; Read-Only Functions - State Queries
;; ============================================

(define-read-only (is-global-paused)
    (var-get global-paused)
)

(define-read-only (is-emergency-mode)
    (var-get emergency-mode)
)

(define-read-only (is-stream-paused (stream-id uint))
    (default-to false (map-get? stream-paused stream-id))
)

(define-read-only (get-last-pause-block)
    (var-get last-pause-block)
)

(define-read-only (get-last-unpause-block)
    (var-get last-unpause-block)
)

(define-read-only (is-admin (user principal))
    (or 
        (is-eq user (var-get contract-owner))
        (default-to false (map-get? emergency-admins user))
    )
)

(define-read-only (get-stream-pause-history (stream-id uint))
    (default-to (list) (map-get? stream-pause-history stream-id))
)

;; Check if system is operational (not paused and not in emergency mode)
(define-read-only (is-operational)
    (and 
        (not (var-get global-paused))
        (not (var-get emergency-mode))
    )
)

;; Check if a specific stream can be accessed
(define-read-only (can-access-stream (stream-id uint))
    (and
        (is-operational)
        (not (is-stream-paused stream-id))
    )
)

;; ============================================
;; Private Functions - Helpers
;; ============================================

(define-private (add-to-pause-history (stream-id uint) (paused bool))
    (let
        (
            (current-history (default-to (list) (map-get? stream-pause-history stream-id)))
            (new-entry { paused: paused, block: block-height, by: tx-sender })
        )
        (map-set stream-pause-history stream-id 
            (unwrap-panic (as-max-len? (append current-history new-entry) u50)))
    )
)

;; ============================================
;; Public Functions - Admin Management
;; ============================================

(define-public (add-emergency-admin (admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (map-set emergency-admins admin true))
    )
)

(define-public (remove-emergency-admin (admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (map-delete emergency-admins admin))
    )
)

(define-public (set-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (var-set contract-owner new-owner))
    )
)

;; ============================================
;; Public Functions - Global Pause Controls
;; ============================================

(define-public (pause-system)
    (begin
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
        (asserts! (not (var-get global-paused)) ERR_ALREADY_PAUSED)
        
        (var-set global-paused true)
        (var-set last-pause-block block-height)
        
        (print {
            event: "system-paused",
            by: tx-sender,
            block: block-height
        })
        
        (ok true)
    )
)

(define-public (unpause-system)
    (begin
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
        (asserts! (var-get global-paused) ERR_NOT_PAUSED)
        
        (var-set global-paused false)
        (var-set last-unpause-block block-height)
        
        (print {
            event: "system-unpaused",
            by: tx-sender,
            block: block-height
        })
        
        (ok true)
    )
)

;; ============================================
;; Public Functions - Per-Stream Pause Controls
;; ============================================

(define-public (pause-stream (stream-id uint))
    (begin
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
        (asserts! (not (is-stream-paused stream-id)) ERR_ALREADY_PAUSED)
        
        (map-set stream-paused stream-id true)
        (add-to-pause-history stream-id true)
        
        (print {
            event: "stream-paused",
            stream-id: stream-id,
            by: tx-sender,
            block: block-height
        })
        
        (ok true)
    )
)

(define-public (unpause-stream (stream-id uint))
    (begin
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
        (asserts! (is-stream-paused stream-id) ERR_NOT_PAUSED)
        
        (map-set stream-paused stream-id false)
        (add-to-pause-history stream-id false)
        
        (print {
            event: "stream-unpaused",
            stream-id: stream-id,
            by: tx-sender,
            block: block-height
        })
        
        (ok true)
    )
)

;; ============================================
;; Public Functions - Emergency Mode
;; ============================================

(define-public (enable-emergency-mode)
    (begin
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
        (asserts! (not (var-get emergency-mode)) ERR_EMERGENCY_MODE_ACTIVE)
        
        (var-set emergency-mode true)
        (var-set global-paused true)
        (var-set last-pause-block block-height)
        
        (print {
            event: "emergency-mode-enabled",
            by: tx-sender,
            block: block-height
        })
        
        (ok true)
    )
)

(define-public (disable-emergency-mode)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (asserts! (var-get emergency-mode) ERR_NOT_PAUSED)
        
        (var-set emergency-mode false)
        (var-set global-paused false)
        (var-set last-unpause-block block-height)
        
        (print {
            event: "emergency-mode-disabled",
            by: tx-sender,
            block: block-height
        })
        
        (ok true)
    )
)

;; ============================================
;; Public Functions - Batch Operations
;; ============================================

(define-public (pause-multiple-streams (stream-ids (list 50 uint)))
    (begin
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
        (ok (map pause-stream-internal stream-ids))
    )
)

(define-private (pause-stream-internal (stream-id uint))
    (begin
        (map-set stream-paused stream-id true)
        (add-to-pause-history stream-id true)
        true
    )
)

```
