;; StackSusu Emergency v7
;; Emergency withdrawal handling

(define-constant CONTRACT-OWNER tx-sender)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u4000))
(define-constant ERR-CIRCLE-NOT-FOUND (err u4001))
(define-constant ERR-NOT-MEMBER (err u4002))
(define-constant ERR-ALREADY-REQUESTED (err u4003))
(define-constant ERR-NO-REQUEST (err u4004))
(define-constant ERR-COOLDOWN (err u4005))
(define-constant ERR-PAUSED (err u4006))

;; Emergency request status
(define-constant STATUS-PENDING u0)
(define-constant STATUS-APPROVED u1)
(define-constant STATUS-DENIED u2)
(define-constant STATUS-PROCESSED u3)

;; Configuration
(define-constant EMERGENCY-COOLDOWN u144) ;; ~1 day

;; Emergency requests
(define-map emergency-requests
  { circle-id: uint, member: principal }
  {
    reason: (string-ascii 200),
    amount-requested: uint,
    status: uint,
    created-at: uint,
    processed-at: uint
  }
)

;; Stats
(define-data-var total-emergency-requests uint u0)
(define-data-var total-emergency-payouts uint u0)


;; ============================================
;; Emergency Functions
;; ============================================

(define-public (request-emergency-payout (circle-id uint) (reason (string-ascii 200)))
  (let
    (
      (member tx-sender)
      (member-balance (unwrap! (contract-call? .stacksusu-escrow-v7 get-member-balance circle-id member) ERR-CIRCLE-NOT-FOUND))
      (existing-request (map-get? emergency-requests { circle-id: circle-id, member: member }))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v7 is-paused)) ERR-PAUSED)
    (asserts! (> member-balance u0) ERR-NOT-MEMBER)
    
    ;; Check for existing pending request
    (match existing-request
      req (asserts! (or 
            (is-eq (get status req) STATUS-PROCESSED)
            (is-eq (get status req) STATUS-DENIED)
            (> (- block-height (get created-at req)) EMERGENCY-COOLDOWN))
          ERR-ALREADY-REQUESTED)
      true
    )
    
    ;; Create request
    (map-set emergency-requests { circle-id: circle-id, member: member } {
      reason: reason,
      amount-requested: member-balance,
      status: STATUS-PENDING,
      created-at: block-height,
      processed-at: u0
    })
    
    (var-set total-emergency-requests (+ (var-get total-emergency-requests) u1))
    
    (ok true)
  )
)

(define-public (process-emergency-request (circle-id uint) (member principal) (approve bool))
  (let
    (
      (request (unwrap! (map-get? emergency-requests { circle-id: circle-id, member: member }) ERR-NO-REQUEST))
    )
    ;; Only contract owner can process
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request) STATUS-PENDING) ERR-ALREADY-REQUESTED)
    
    (if approve
      (begin
        ;; Process withdrawal through escrow
        (try! (as-contract (contract-call? .stacksusu-escrow-v7 emergency-withdraw circle-id (get amount-requested request))))
        
        (map-set emergency-requests { circle-id: circle-id, member: member }
          (merge request { status: STATUS-PROCESSED, processed-at: block-height }))
        
        (var-set total-emergency-payouts (+ (var-get total-emergency-payouts) (get amount-requested request)))
        (ok true)
      )
      (begin
        (map-set emergency-requests { circle-id: circle-id, member: member }
          (merge request { status: STATUS-DENIED, processed-at: block-height }))
        (ok false)
      )
    )
  )
)

;; Self-service emergency withdraw (no approval needed, higher fee)
(define-public (self-emergency-withdraw (circle-id uint))
  (let
    (
      (member tx-sender)
      (member-balance (unwrap! (contract-call? .stacksusu-escrow-v7 get-member-balance circle-id member) ERR-CIRCLE-NOT-FOUND))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v7 is-paused)) ERR-PAUSED)
    (asserts! (> member-balance u0) ERR-NOT-MEMBER)
    
    ;; Direct withdraw from escrow (applies emergency fee)
    (try! (contract-call? .stacksusu-escrow-v7 emergency-withdraw circle-id member-balance))
    
    (var-set total-emergency-payouts (+ (var-get total-emergency-payouts) member-balance))
    
    (ok member-balance)
  )
)


;; ============================================
;; Read Functions
;; ============================================

(define-read-only (get-emergency-request (circle-id uint) (member principal))
  (map-get? emergency-requests { circle-id: circle-id, member: member })
)

(define-read-only (get-emergency-stats)
  {
    total-requests: (var-get total-emergency-requests),
    total-payouts: (var-get total-emergency-payouts)
  }
)

(define-read-only (has-pending-request (circle-id uint) (member principal))
  (match (map-get? emergency-requests { circle-id: circle-id, member: member })
    req (is-eq (get status req) STATUS-PENDING)
    false
  )
)
