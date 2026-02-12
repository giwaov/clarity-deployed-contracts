;; StackSusu Emergency v5
;; Emergency withdrawal system with enhanced controls

(define-constant CONTRACT-OWNER tx-sender)

;; Status constants
(define-constant STATUS-ACTIVE u1)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-CIRCLE-NOT-FOUND (err u1001))
(define-constant ERR-NOT-MEMBER (err u1005))
(define-constant ERR-CONTRIBUTIONS-INCOMPLETE (err u1011))
(define-constant ERR-ALREADY-CLAIMED (err u1013))
(define-constant ERR-CIRCLE-NOT-ACTIVE (err u1015))
(define-constant ERR-EMERGENCY-NOT-ALLOWED (err u1018))
(define-constant ERR-ALREADY-RECEIVED-PAYOUT (err u1019))
(define-constant ERR-PAUSED (err u1021))
(define-constant ERR-COOLDOWN-ACTIVE (err u1033))
(define-constant ERR-MAX-EMERGENCY-REACHED (err u1034))

;; Emergency request tracking
(define-map emergency-requests
  { circle-id: uint, member: principal }
  { requested-at: uint, processed: bool, amount: uint }
)

;; Emergency payout count per circle
(define-map emergency-payout-count uint uint)

;; Member emergency cooldown (blocks until they can request again)
(define-map member-emergency-cooldown principal uint)

;; Maximum emergency payouts per circle (prevents all members from emergency exiting)
(define-constant MAX-EMERGENCY-PERCENT u30)  ;; Max 30% of members can emergency exit

;; Cooldown period (blocks after emergency before joining new circle)
(define-constant EMERGENCY-COOLDOWN-BLOCKS u1008)  ;; ~7 days


;; ============================================
;; Request Emergency Payout
;; ============================================

(define-public (request-emergency-payout (circle-id uint))
  (let
    (
      (caller tx-sender)
      (circle-info (unwrap! (contract-call? .stacksusu-core-v5 get-circle-info circle-id) 
                           ERR-CIRCLE-NOT-FOUND))
      (circle (unwrap! circle-info ERR-CIRCLE-NOT-FOUND))
      (member-info-result (contract-call? .stacksusu-core-v5 get-member-info circle-id caller))
      (contribution (get contribution circle))
      (max-members (get max-members circle))
      (contribution-mode (get contribution-mode circle))
      (total-pot (* contribution max-members))
      (emergency-fee-bps (contract-call? .stacksusu-admin-v5 get-emergency-fee-bps))
      (admin-fee-bps (contract-call? .stacksusu-admin-v5 get-admin-fee-bps))
      (emergency-fee (/ (* total-pot emergency-fee-bps) u10000))
      (admin-fee (/ (* total-pot admin-fee-bps) u10000))
      (current-emergency-count (default-to u0 (map-get? emergency-payout-count circle-id)))
      (current-round (get current-round circle))
      (emergency-round (+ current-round current-emergency-count u1000)) ;; Offset emergency rounds
      (max-emergency-allowed (/ (* max-members MAX-EMERGENCY-PERCENT) u100))
      (cooldown (default-to u0 (map-get? member-emergency-cooldown caller)))
    )
    ;; Validations
    (asserts! (not (contract-call? .stacksusu-admin-v5 is-paused)) ERR-PAUSED)
    (asserts! (is-eq (get status circle) STATUS-ACTIVE) ERR-CIRCLE-NOT-ACTIVE)
    (asserts! (contract-call? .stacksusu-core-v5 is-member circle-id caller) ERR-NOT-MEMBER)
    (asserts! (not (contract-call? .stacksusu-escrow-v5 has-received-payout circle-id caller)) 
              ERR-ALREADY-RECEIVED-PAYOUT)
    (asserts! (< current-emergency-count max-emergency-allowed) ERR-MAX-EMERGENCY-REACHED)
    (asserts! (< cooldown block-height) ERR-COOLDOWN-ACTIVE)
    
    ;; Check contributions based on mode
    (if (is-eq contribution-mode u0)  ;; MODE-UPFRONT
      (asserts! (contract-call? .stacksusu-escrow-v5 are-deposits-complete circle-id max-members) 
                ERR-CONTRIBUTIONS-INCOMPLETE)
      (asserts! (contract-call? .stacksusu-escrow-v5 are-round-contributions-complete 
                  circle-id current-round max-members) 
                ERR-CONTRIBUTIONS-INCOMPLETE)
    )
    
    ;; Check not already requested
    (let ((existing-request (map-get? emergency-requests { circle-id: circle-id, member: caller })))
      (asserts! (or (is-none existing-request)
                    (get processed (unwrap-panic existing-request)))
                ERR-ALREADY-CLAIMED)
    )
    
    ;; Record emergency request
    (map-set emergency-requests
      { circle-id: circle-id, member: caller }
      { requested-at: block-height, processed: true, amount: total-pot }
    )
    
    ;; Increment emergency count
    (map-set emergency-payout-count circle-id (+ current-emergency-count u1))
    
    ;; Set cooldown for member
    (map-set member-emergency-cooldown caller (+ block-height EMERGENCY-COOLDOWN-BLOCKS))
    
    ;; Record default in reputation (emergency counts as incomplete)
    (match (contract-call? .stacksusu-reputation-v5 record-default caller circle-id)
      success true
      error true
    )
    
    ;; Process the emergency payout through escrow
    (contract-call? .stacksusu-escrow-v5 process-emergency-payout
      circle-id emergency-round caller total-pot emergency-fee admin-fee
    )
  )
)


;; ============================================
;; Read-only Functions
;; ============================================

(define-read-only (can-request-emergency (circle-id uint) (member principal))
  (let 
    (
      (circle-opt (unwrap-panic (contract-call? .stacksusu-core-v5 get-circle-info circle-id)))
    )
    (match circle-opt
      circle
        (let
          (
            (max-members (get max-members circle))
            (contribution-mode (get contribution-mode circle))
            (current-round (get current-round circle))
            (is-member-check (contract-call? .stacksusu-core-v5 is-member circle-id member))
            (has-payout (contract-call? .stacksusu-escrow-v5 has-received-payout circle-id member))
            (current-emergency-count (default-to u0 (map-get? emergency-payout-count circle-id)))
            (max-emergency-allowed (/ (* max-members MAX-EMERGENCY-PERCENT) u100))
            (cooldown (default-to u0 (map-get? member-emergency-cooldown member)))
            (contributions-complete (if (is-eq contribution-mode u0)
              (contract-call? .stacksusu-escrow-v5 are-deposits-complete circle-id max-members)
              (contract-call? .stacksusu-escrow-v5 are-round-contributions-complete 
                circle-id current-round max-members)
            ))
          )
          (ok (and 
            (is-eq (get status circle) STATUS-ACTIVE) 
            is-member-check 
            (not has-payout) 
            contributions-complete
            (< current-emergency-count max-emergency-allowed)
            (< cooldown block-height)
          ))
        )
      (ok false)
    )
  )
)

(define-read-only (get-emergency-fee-amount (circle-id uint))
  (let 
    (
      (circle-opt (unwrap-panic (contract-call? .stacksusu-core-v5 get-circle-info circle-id)))
    )
    (match circle-opt
      circle
        (let
          (
            (total-pot (* (get contribution circle) (get max-members circle)))
            (emergency-fee-bps (contract-call? .stacksusu-admin-v5 get-emergency-fee-bps))
            (admin-fee-bps (contract-call? .stacksusu-admin-v5 get-admin-fee-bps))
            (emergency-fee (/ (* total-pot emergency-fee-bps) u10000))
            (admin-fee (/ (* total-pot admin-fee-bps) u10000))
          )
          (ok {
            total-pot: total-pot,
            emergency-fee: emergency-fee,
            admin-fee: admin-fee,
            total-fees: (+ emergency-fee admin-fee),
            payout-amount: (- total-pot (+ emergency-fee admin-fee))
          })
        )
      (err u1001)
    )
  )
)

(define-read-only (get-emergency-count (circle-id uint))
  (ok (default-to u0 (map-get? emergency-payout-count circle-id)))
)

(define-read-only (get-max-emergency-allowed (circle-id uint))
  (let 
    (
      (circle-opt (unwrap-panic (contract-call? .stacksusu-core-v5 get-circle-info circle-id)))
    )
    (match circle-opt
      circle
        (ok (/ (* (get max-members circle) MAX-EMERGENCY-PERCENT) u100))
      (err u1001)
    )
  )
)

(define-read-only (get-emergency-request (circle-id uint) (member principal))
  (ok (map-get? emergency-requests { circle-id: circle-id, member: member }))
)

(define-read-only (get-member-cooldown (member principal))
  (ok (default-to u0 (map-get? member-emergency-cooldown member)))
)

(define-read-only (is-member-on-cooldown (member principal))
  (let
    (
      (cooldown (default-to u0 (map-get? member-emergency-cooldown member)))
    )
    (> cooldown block-height)
  )
)

(define-read-only (get-cooldown-remaining (member principal))
  (let
    (
      (cooldown (default-to u0 (map-get? member-emergency-cooldown member)))
    )
    (if (> cooldown block-height)
      (ok (- cooldown block-height))
      (ok u0)
    )
  )
)
