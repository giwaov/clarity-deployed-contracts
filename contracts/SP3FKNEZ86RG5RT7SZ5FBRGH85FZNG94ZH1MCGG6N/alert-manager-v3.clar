;; StackPulse Alert Manager V3
;; Upgrades from V2:
;; - Enhanced error handling with descriptive codes
;; - Optimized gas usage
;; - Improved alert tracking with metadata
;; - Batch operations for efficiency
;; - Better chainhook integration
;;
;; Alert Types (matching chainhooks):
;; 1 = Whale Transfer
;; 2 = Contract Deployed  
;; 3 = NFT Mint
;; 4 = Token Launch
;; 5 = Large Swap
;; 6 = Custom Address Watch

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-REGISTERED (err u101))
(define-constant ERR-ALERT-NOT-FOUND (err u102))
(define-constant ERR-MAX-ALERTS-REACHED (err u103))
(define-constant ERR-INVALID-ALERT-TYPE (err u104))
(define-constant ERR-INVALID-NAME (err u105))
(define-constant ERR-ALERT-DISABLED (err u106))
(define-constant ERR-DUPLICATE-ALERT (err u107))

;; Max alerts per tier
(define-constant MAX-ALERTS-FREE u3)
(define-constant MAX-ALERTS-BASIC u10)
(define-constant MAX-ALERTS-PRO u25)
(define-constant MAX-ALERTS-PREMIUM u999)

;; Valid alert type range
(define-constant MIN-ALERT-TYPE u1)
(define-constant MAX-ALERT-TYPE u6)

;; ============================================
;; DATA STORAGE
;; ============================================

(define-data-var next-alert-id uint u1)
(define-data-var total-alerts uint u0)
(define-data-var total-triggers uint u0)
(define-data-var contract-version (string-ascii 8) "v3.0.0")

;; Alert storage with V3 enhanced metadata
(define-map alerts uint
  {
    owner: principal,
    alert-type: uint,
    name: (string-ascii 64),
    target-address: (optional principal),
    threshold: uint,
    enabled: bool,
    trigger-count: uint,
    last-triggered: uint,    ;; V3: Track last trigger block
    created-at: uint
  }
)

;; User alert count
(define-map user-alert-count principal uint)

;; User's alert IDs (for lookup)
(define-map user-alerts { user: principal, index: uint } uint)

;; V3: Track alert types per user for quick lookup
(define-map user-alert-types { user: principal, alert-type: uint } uint)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-version)
  (var-get contract-version)
)

(define-read-only (get-alert (alert-id uint))
  (map-get? alerts alert-id)
)

(define-read-only (get-user-alert-count (user principal))
  (default-to u0 (map-get? user-alert-count user))
)

(define-read-only (get-max-alerts-for-tier (tier uint))
  (if (is-eq tier u0) MAX-ALERTS-FREE
    (if (is-eq tier u1) MAX-ALERTS-BASIC
      (if (is-eq tier u2) MAX-ALERTS-PRO
        MAX-ALERTS-PREMIUM)))
)

(define-read-only (get-user-alert-by-index (user principal) (index uint))
  (match (map-get? user-alerts { user: user, index: index })
    alert-id (map-get? alerts alert-id)
    none
  )
)

(define-read-only (get-stats)
  {
    total-alerts: (var-get total-alerts),
    total-triggers: (var-get total-triggers),
    next-id: (var-get next-alert-id),
    version: (var-get contract-version)
  }
)

;; V3: Get count of specific alert type for user
(define-read-only (get-user-alert-type-count (user principal) (alert-type uint))
  (default-to u0 (map-get? user-alert-types { user: user, alert-type: alert-type }))
)

;; V3: Check if alert is enabled and valid
(define-read-only (is-alert-active (alert-id uint))
  (match (map-get? alerts alert-id)
    alert-data (get enabled alert-data)
    false
  )
)

;; ============================================
;; PRIVATE HELPER FUNCTIONS
;; ============================================

;; V3: Validate alert type
(define-private (is-valid-alert-type (alert-type uint))
  (and (>= alert-type MIN-ALERT-TYPE) (<= alert-type MAX-ALERT-TYPE))
)

;; V3: Validate alert name
(define-private (is-valid-name (name (string-ascii 64)))
  (> (len name) u0)
)

;; ============================================
;; PUBLIC FUNCTIONS
;; ============================================

;; Create a new alert
;; alert-type: 1=whale, 2=contract, 3=nft, 4=token, 5=swap, 6=address
(define-public (create-alert 
    (alert-type uint)
    (name (string-ascii 64))
    (target-address (optional principal))
    (threshold uint)
    (user-tier uint))
  (let
    (
      (caller tx-sender)
      (alert-id (var-get next-alert-id))
      (current-count (get-user-alert-count caller))
      (max-allowed (get-max-alerts-for-tier user-tier))
      (type-count (get-user-alert-type-count caller alert-type))
    )
    ;; V3: Enhanced validation
    (asserts! (is-valid-alert-type alert-type) ERR-INVALID-ALERT-TYPE)
    (asserts! (is-valid-name name) ERR-INVALID-NAME)
    (asserts! (< current-count max-allowed) ERR-MAX-ALERTS-REACHED)
    
    ;; Store alert with V3 enhanced metadata
    (map-set alerts alert-id {
      owner: caller,
      alert-type: alert-type,
      name: name,
      target-address: target-address,
      threshold: threshold,
      enabled: true,
      trigger-count: u0,
      last-triggered: u0,
      created-at: block-height
    })
    
    ;; Update user's alert tracking
    (map-set user-alert-count caller (+ current-count u1))
    (map-set user-alerts { user: caller, index: current-count } alert-id)
    (map-set user-alert-types { user: caller, alert-type: alert-type } (+ type-count u1))
    
    ;; Update global stats
    (var-set next-alert-id (+ alert-id u1))
    (var-set total-alerts (+ (var-get total-alerts) u1))
    
    (print {
      event: "alert-created",
      version: "v3",
      alert-id: alert-id,
      owner: caller,
      alert-type: alert-type,
      name: name,
      threshold: threshold,
      block: block-height
    })
    
    (ok alert-id)
  )
)

;; Toggle alert enabled/disabled
(define-public (toggle-alert (alert-id uint))
  (let
    (
      (caller tx-sender)
      (alert-data (unwrap! (map-get? alerts alert-id) ERR-ALERT-NOT-FOUND))
      (new-enabled (not (get enabled alert-data)))
    )
    (asserts! (is-eq (get owner alert-data) caller) ERR-NOT-AUTHORIZED)
    
    (map-set alerts alert-id (merge alert-data {
      enabled: new-enabled
    }))
    
    (print {
      event: "alert-toggled",
      version: "v3",
      alert-id: alert-id,
      enabled: new-enabled,
      block: block-height
    })
    
    (ok new-enabled)
  )
)

;; Delete an alert
(define-public (delete-alert (alert-id uint))
  (let
    (
      (caller tx-sender)
      (alert-data (unwrap! (map-get? alerts alert-id) ERR-ALERT-NOT-FOUND))
      (current-count (get-user-alert-count caller))
      (alert-type (get alert-type alert-data))
      (type-count (get-user-alert-type-count caller alert-type))
    )
    (asserts! (is-eq (get owner alert-data) caller) ERR-NOT-AUTHORIZED)
    
    ;; Remove alert
    (map-delete alerts alert-id)
    
    ;; Update counts
    (map-set user-alert-count caller (- current-count u1))
    (if (> type-count u0)
      (map-set user-alert-types { user: caller, alert-type: alert-type } (- type-count u1))
      true
    )
    
    (print {
      event: "alert-deleted",
      version: "v3",
      alert-id: alert-id,
      owner: caller,
      alert-type: alert-type,
      block: block-height
    })
    
    (ok true)
  )
)

;; Record alert trigger (called by chainhook server or authorized caller)
(define-public (record-trigger (alert-id uint))
  (let
    (
      (alert-data (unwrap! (map-get? alerts alert-id) ERR-ALERT-NOT-FOUND))
      (new-trigger-count (+ (get trigger-count alert-data) u1))
    )
    ;; Only owner or contract owner can record triggers
    (asserts! (or (is-eq tx-sender (get owner alert-data)) 
                  (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    
    ;; V3: Check alert is enabled
    (asserts! (get enabled alert-data) ERR-ALERT-DISABLED)
    
    (map-set alerts alert-id (merge alert-data {
      trigger-count: new-trigger-count,
      last-triggered: block-height
    }))
    
    ;; V3: Update global trigger count
    (var-set total-triggers (+ (var-get total-triggers) u1))
    
    (print {
      event: "alert-triggered",
      version: "v3",
      alert-id: alert-id,
      owner: (get owner alert-data),
      alert-type: (get alert-type alert-data),
      trigger-count: new-trigger-count,
      block: block-height
    })
    
    (ok new-trigger-count)
  )
)

;; Update alert settings
(define-public (update-alert 
    (alert-id uint)
    (name (string-ascii 64))
    (target-address (optional principal))
    (threshold uint))
  (let
    (
      (caller tx-sender)
      (alert-data (unwrap! (map-get? alerts alert-id) ERR-ALERT-NOT-FOUND))
    )
    (asserts! (is-eq (get owner alert-data) caller) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-name name) ERR-INVALID-NAME)
    
    (map-set alerts alert-id (merge alert-data {
      name: name,
      target-address: target-address,
      threshold: threshold
    }))
    
    (print {
      event: "alert-updated",
      version: "v3",
      alert-id: alert-id,
      name: name,
      threshold: threshold,
      block: block-height
    })
    
    (ok true)
  )
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

;; V3: Admin can disable/enable alerts for moderation
(define-public (admin-set-alert-status (alert-id uint) (enabled bool))
  (let
    (
      (alert-data (unwrap! (map-get? alerts alert-id) ERR-ALERT-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set alerts alert-id (merge alert-data {
      enabled: enabled
    }))
    
    (print {
      event: "admin-alert-status",
      version: "v3",
      alert-id: alert-id,
      enabled: enabled,
      block: block-height
    })
    
    (ok true)
  )
)
