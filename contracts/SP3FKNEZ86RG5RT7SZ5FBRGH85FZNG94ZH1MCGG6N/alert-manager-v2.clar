;; StackPulse Alert Manager V2
;; Manages user alerts, triggers, and integrates with chainhooks
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

;; Max alerts per tier
(define-constant MAX-ALERTS-FREE u3)
(define-constant MAX-ALERTS-BASIC u10)
(define-constant MAX-ALERTS-PRO u25)
(define-constant MAX-ALERTS-PREMIUM u999)

;; ============================================
;; DATA STORAGE
;; ============================================

(define-data-var next-alert-id uint u1)
(define-data-var total-alerts uint u0)

;; Alert storage
(define-map alerts uint
  {
    owner: principal,
    alert-type: uint,
    name: (string-ascii 64),
    target-address: (optional principal),
    threshold: uint,
    enabled: bool,
    trigger-count: uint,
    created-at: uint
  }
)

;; User alert count
(define-map user-alert-count principal uint)

;; User's alert IDs (for lookup)
(define-map user-alerts { user: principal, index: uint } uint)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

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
    next-id: (var-get next-alert-id)
  }
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
    )
    ;; Check alert type is valid (1-6)
    (asserts! (and (>= alert-type u1) (<= alert-type u6)) ERR-INVALID-ALERT-TYPE)
    
    ;; Check user hasn't exceeded their limit
    (asserts! (< current-count max-allowed) ERR-MAX-ALERTS-REACHED)
    
    ;; Store alert
    (map-set alerts alert-id {
      owner: caller,
      alert-type: alert-type,
      name: name,
      target-address: target-address,
      threshold: threshold,
      enabled: true,
      trigger-count: u0,
      created-at: block-height
    })
    
    ;; Update user's alert tracking
    (map-set user-alert-count caller (+ current-count u1))
    (map-set user-alerts { user: caller, index: current-count } alert-id)
    
    ;; Update global stats
    (var-set next-alert-id (+ alert-id u1))
    (var-set total-alerts (+ (var-get total-alerts) u1))
    
    (print {
      event: "alert-created",
      alert-id: alert-id,
      owner: caller,
      alert-type: alert-type,
      name: name,
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
    )
    (asserts! (is-eq (get owner alert-data) caller) ERR-NOT-AUTHORIZED)
    
    (map-set alerts alert-id (merge alert-data {
      enabled: (not (get enabled alert-data))
    }))
    
    (print {
      event: "alert-toggled",
      alert-id: alert-id,
      enabled: (not (get enabled alert-data)),
      block: block-height
    })
    
    (ok true)
  )
)

;; Delete an alert
(define-public (delete-alert (alert-id uint))
  (let
    (
      (caller tx-sender)
      (alert-data (unwrap! (map-get? alerts alert-id) ERR-ALERT-NOT-FOUND))
      (current-count (get-user-alert-count caller))
    )
    (asserts! (is-eq (get owner alert-data) caller) ERR-NOT-AUTHORIZED)
    
    ;; Remove alert
    (map-delete alerts alert-id)
    
    ;; Update count
    (map-set user-alert-count caller (- current-count u1))
    
    (print {
      event: "alert-deleted",
      alert-id: alert-id,
      owner: caller,
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
    )
    ;; Only owner or contract owner can record triggers
    (asserts! (or (is-eq tx-sender (get owner alert-data)) 
                  (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    
    (map-set alerts alert-id (merge alert-data {
      trigger-count: (+ (get trigger-count alert-data) u1)
    }))
    
    (print {
      event: "alert-triggered",
      alert-id: alert-id,
      owner: (get owner alert-data),
      alert-type: (get alert-type alert-data),
      trigger-count: (+ (get trigger-count alert-data) u1),
      block: block-height
    })
    
    (ok true)
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
    
    (map-set alerts alert-id (merge alert-data {
      name: name,
      target-address: target-address,
      threshold: threshold
    }))
    
    (print {
      event: "alert-updated",
      alert-id: alert-id,
      name: name,
      block: block-height
    })
    
    (ok true)
  )
)
