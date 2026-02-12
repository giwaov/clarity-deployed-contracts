(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-CIRCLE-NOT-FOUND (err u1001))
(define-constant ERR-NOT-MEMBER (err u1005))
(define-constant ERR-INVALID-AMOUNT (err u1006))
(define-constant ERR-ALREADY-DEPOSITED (err u1009))
(define-constant ERR-NOT-DEPOSITED (err u1010))
(define-constant ERR-TRANSFER-FAILED (err u1017))
(define-constant ERR-ZERO-AMOUNT (err u1023))
(define-constant ERR-PAUSED (err u1021))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1024))

(define-map deposits 
  { circle-id: uint, member: principal }
  { deposited: bool, amount: uint, deposit-block: uint }
)

(define-map circle-deposits
  uint
  { total-deposited: uint, deposit-count: uint }
)

(define-map payouts
  { circle-id: uint, round: uint }
  { recipient: principal, amount: uint, block: uint, is-emergency: bool }
)

(define-map member-received-payout
  { circle-id: uint, member: principal }
  bool
)

(define-map authorized-callers principal bool)


(define-read-only (is-authorized (caller principal))
  (or 
    (is-eq caller CONTRACT-OWNER)
    (default-to false (map-get? authorized-callers caller))
  )
)

(define-public (authorize-caller (caller principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-callers caller true))
  )
)

(define-public (revoke-caller (caller principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-callers caller))
  )
)


(define-public (deposit (circle-id uint) (amount uint) (is-member bool))
  (let
    (
      (sender tx-sender)
      (current-deposits (default-to { total-deposited: u0, deposit-count: u0 } 
                          (map-get? circle-deposits circle-id)))
      (existing-deposit (map-get? deposits { circle-id: circle-id, member: sender }))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v3 is-paused)) ERR-PAUSED)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (is-none existing-deposit) ERR-ALREADY-DEPOSITED)
    (asserts! is-member ERR-NOT-MEMBER)
    
    (match (stx-transfer? amount sender (as-contract tx-sender))
      success
        (begin
          (map-set deposits 
            { circle-id: circle-id, member: sender }
            { deposited: true, amount: amount, deposit-block: block-height }
          )
          (map-set circle-deposits circle-id
            { 
              total-deposited: (+ (get total-deposited current-deposits) amount),
              deposit-count: (+ (get deposit-count current-deposits) u1)
            }
          )
          (ok true)
        )
      error ERR-TRANSFER-FAILED
    )
  )
)


(define-public (process-payout 
    (circle-id uint) 
    (round uint) 
    (recipient principal) 
    (total-pot uint)
    (admin-fee uint))
  (let
    (
      (payout-amount (- total-pot admin-fee))
      (treasury (contract-call? .stacksusu-admin-v3 get-treasury))
    )
    (asserts! (is-authorized contract-caller) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? member-received-payout { circle-id: circle-id, member: recipient })) 
              ERR-NOT-AUTHORIZED)
    
    (match (as-contract (stx-transfer? payout-amount tx-sender recipient))
      success
        (begin
          (if (> admin-fee u0)
            (match (as-contract (stx-transfer? admin-fee tx-sender treasury))
              fee-success (begin (unwrap-panic (contract-call? .stacksusu-admin-v3 record-fee admin-fee)) true)
              fee-error true
            )
            true
          )
          (map-set payouts 
            { circle-id: circle-id, round: round }
            { recipient: recipient, amount: payout-amount, block: block-height, is-emergency: false }
          )
          (map-set member-received-payout { circle-id: circle-id, member: recipient } true)
          (ok payout-amount)
        )
      error ERR-TRANSFER-FAILED
    )
  )
)

(define-public (process-emergency-payout
    (circle-id uint)
    (round uint)
    (recipient principal)
    (total-pot uint)
    (emergency-fee uint)
    (admin-fee uint))
  (let
    (
      (total-fees (+ emergency-fee admin-fee))
      (payout-amount (- total-pot total-fees))
      (treasury (contract-call? .stacksusu-admin-v3 get-treasury))
    )
    (asserts! (is-authorized contract-caller) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? member-received-payout { circle-id: circle-id, member: recipient }))
              ERR-NOT-AUTHORIZED)
    
    (match (as-contract (stx-transfer? payout-amount tx-sender recipient))
      success
        (begin
          (if (> total-fees u0)
            (match (as-contract (stx-transfer? total-fees tx-sender treasury))
              fee-success (begin (unwrap-panic (contract-call? .stacksusu-admin-v3 record-fee total-fees)) true)
              fee-error true
            )
            true
          )
          (map-set payouts
            { circle-id: circle-id, round: round }
            { recipient: recipient, amount: payout-amount, block: block-height, is-emergency: true }
          )
          (map-set member-received-payout { circle-id: circle-id, member: recipient } true)
          (ok payout-amount)
        )
      error ERR-TRANSFER-FAILED
    )
  )
)


(define-read-only (get-deposit-info (circle-id uint) (member principal))
  (ok (default-to 
    { deposited: false, amount: u0, deposit-block: u0 }
    (map-get? deposits { circle-id: circle-id, member: member })
  ))
)

(define-read-only (get-circle-deposit-status (circle-id uint))
  (ok (default-to 
    { total-deposited: u0, deposit-count: u0 }
    (map-get? circle-deposits circle-id)
  ))
)

(define-read-only (get-payout-info (circle-id uint) (round uint))
  (ok (map-get? payouts { circle-id: circle-id, round: round }))
)

(define-read-only (has-received-payout (circle-id uint) (member principal))
  (default-to false (map-get? member-received-payout { circle-id: circle-id, member: member }))
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (are-deposits-complete (circle-id uint) (required-count uint))
  (let
    (
      (status (default-to { total-deposited: u0, deposit-count: u0 } 
                (map-get? circle-deposits circle-id)))
    )
    (>= (get deposit-count status) required-count)
  )
)
