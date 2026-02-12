(define-constant CONTRACT-OWNER tx-sender)
(define-constant STATUS-ACTIVE u2)
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-CIRCLE-NOT-FOUND (err u1001))
(define-constant ERR-NOT-MEMBER (err u1005))
(define-constant ERR-DEPOSITS-INCOMPLETE (err u1011))
(define-constant ERR-ALREADY-CLAIMED (err u1013))
(define-constant ERR-CIRCLE-NOT-ACTIVE (err u1015))
(define-constant ERR-EMERGENCY-NOT-ALLOWED (err u1018))
(define-constant ERR-ALREADY-RECEIVED-PAYOUT (err u1019))
(define-constant ERR-PAUSED (err u1021))

(define-map emergency-requests
  { circle-id: uint, member: principal }
  { requested-at: uint, processed: bool }
)

(define-map emergency-payout-count uint uint)


(define-public (request-emergency-payout (circle-id uint))
  (let
    (
      (caller tx-sender)
      (circle-info (unwrap! (contract-call? .stacksusu-core-v4 get-circle-info circle-id) 
                           ERR-CIRCLE-NOT-FOUND))
      (circle (unwrap! circle-info ERR-CIRCLE-NOT-FOUND))
      (member-info-response (unwrap-panic (contract-call? .stacksusu-core-v4 get-member-info circle-id caller)))
      (member-info (unwrap! member-info-response ERR-NOT-MEMBER))
      (contribution (get contribution circle))
      (max-members (get max-members circle))
      (total-pot (* contribution max-members))
      (emergency-fee-bps (contract-call? .stacksusu-admin-v4 get-emergency-fee-bps))
      (admin-fee-bps (contract-call? .stacksusu-admin-v4 get-admin-fee-bps))
      (emergency-fee (/ (* total-pot emergency-fee-bps) u10000))
      (admin-fee (/ (* total-pot admin-fee-bps) u10000))
      (current-emergency-count (default-to u0 (map-get? emergency-payout-count circle-id)))
      (current-round (get current-round circle))
      (emergency-round (+ current-round current-emergency-count))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v4 is-paused)) ERR-PAUSED)
    (asserts! (is-eq (get status circle) STATUS-ACTIVE) ERR-CIRCLE-NOT-ACTIVE)
    (asserts! (contract-call? .stacksusu-core-v4 is-member circle-id caller) ERR-NOT-MEMBER)
    (asserts! (contract-call? .stacksusu-escrow-v4 are-deposits-complete circle-id max-members) 
              ERR-DEPOSITS-INCOMPLETE)
    (asserts! (not (contract-call? .stacksusu-escrow-v4 has-received-payout circle-id caller)) 
              ERR-ALREADY-RECEIVED-PAYOUT)
    
    (let ((existing-request (map-get? emergency-requests { circle-id: circle-id, member: caller })))
      (asserts! (or (is-none existing-request)
                    (get processed (unwrap-panic existing-request)))
                ERR-ALREADY-CLAIMED)
    )
    
    (map-set emergency-requests
      { circle-id: circle-id, member: caller }
      { requested-at: block-height, processed: true }
    )
    
    (map-set emergency-payout-count circle-id (+ current-emergency-count u1))
    
    (contract-call? .stacksusu-escrow-v4 process-emergency-payout
      circle-id emergency-round caller total-pot emergency-fee admin-fee
    )
  )
)


(define-read-only (can-request-emergency (circle-id uint) (member principal))
  (let 
    (
      (circle-opt (unwrap-panic (contract-call? .stacksusu-core-v4 get-circle-info circle-id)))
    )
    (match circle-opt
      circle
        (let
          (
            (max-members (get max-members circle))
            (is-member-check (contract-call? .stacksusu-core-v4 is-member circle-id member))
            (has-payout (contract-call? .stacksusu-escrow-v4 has-received-payout circle-id member))
            (deposits-complete (contract-call? .stacksusu-escrow-v4 are-deposits-complete circle-id max-members))
          )
          (ok (and (is-eq (get status circle) STATUS-ACTIVE) is-member-check (not has-payout) deposits-complete))
        )
      (ok false)
    )
  )
)

(define-read-only (get-emergency-fee-amount (circle-id uint))
  (let 
    (
      (circle-opt (unwrap-panic (contract-call? .stacksusu-core-v4 get-circle-info circle-id)))
    )
    (match circle-opt
      circle
        (let
          (
            (total-pot (* (get contribution circle) (get max-members circle)))
            (emergency-fee-bps (contract-call? .stacksusu-admin-v4 get-emergency-fee-bps))
          )
          (ok (/ (* total-pot emergency-fee-bps) u10000))
        )
      ERR-CIRCLE-NOT-FOUND
    )
  )
)

(define-read-only (get-emergency-count (circle-id uint))
  (default-to u0 (map-get? emergency-payout-count circle-id))
)

(define-read-only (get-emergency-request (circle-id uint) (member principal))
  (ok (map-get? emergency-requests { circle-id: circle-id, member: member }))
)

(define-read-only (get-emergency-payout-amount (circle-id uint))
  (let 
    (
      (circle-opt (unwrap-panic (contract-call? .stacksusu-core-v4 get-circle-info circle-id)))
    )
    (match circle-opt
      circle
        (let
          (
            (total-pot (* (get contribution circle) (get max-members circle)))
            (emergency-fee-bps (contract-call? .stacksusu-admin-v4 get-emergency-fee-bps))
            (admin-fee-bps (contract-call? .stacksusu-admin-v4 get-admin-fee-bps))
            (emergency-fee (/ (* total-pot emergency-fee-bps) u10000))
            (admin-fee (/ (* total-pot admin-fee-bps) u10000))
          )
          (ok (- total-pot (+ emergency-fee admin-fee)))
        )
      ERR-CIRCLE-NOT-FOUND
    )
  )
)
