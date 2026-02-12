(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-PAUSED (err u1021))
(define-constant ERR-ZERO-AMOUNT (err u1023))
(define-constant ERR-TRANSFER-FAILED (err u1017))
(define-data-var protocol-paused bool false)

(define-data-var total-fees-collected uint u0)
(define-data-var admin-fee-bps uint u50)
(define-data-var emergency-fee-bps uint u200)
(define-data-var treasury-address principal CONTRACT-OWNER)
(define-map authorized-contracts principal bool)

(define-read-only (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-read-only (is-authorized-contract (caller principal))
  (default-to false (map-get? authorized-contracts caller))
)

(define-public (authorize-contract (contract principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-contracts contract true))
  )
)

(define-public (revoke-contract (contract principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-contracts contract))
  )
)


(define-public (pause-protocol)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set protocol-paused true))
  )
)

(define-public (unpause-protocol)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set protocol-paused false))
  )
)

(define-read-only (is-paused)
  (var-get protocol-paused)
)

(define-public (set-admin-fee (new-fee-bps uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee-bps u500) ERR-NOT-AUTHORIZED)
    (ok (var-set admin-fee-bps new-fee-bps))
  )
)

(define-public (set-emergency-fee (new-fee-bps uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee-bps u1000) ERR-NOT-AUTHORIZED)
    (ok (var-set emergency-fee-bps new-fee-bps))
  )
)

(define-public (set-treasury (new-treasury principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set treasury-address new-treasury))
  )
)


(define-read-only (get-admin-fee-bps)
  (var-get admin-fee-bps)
)

(define-read-only (get-emergency-fee-bps)
  (var-get emergency-fee-bps)
)

(define-read-only (get-treasury)
  (var-get treasury-address)
)

(define-read-only (get-total-fees)
  (var-get total-fees-collected)
)

(define-public (record-fee (amount uint))
  (begin
    (asserts! (or (is-authorized-contract contract-caller) (is-contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (var-set total-fees-collected (+ (var-get total-fees-collected) amount)))
  )
)

(define-public (withdraw-fees)
  (let
    (
      (fees (var-get total-fees-collected))
      (treasury (var-get treasury-address))
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (> fees u0) ERR-ZERO-AMOUNT)
    (var-set total-fees-collected u0)
    (match (as-contract (stx-transfer? fees tx-sender treasury))
      success (ok fees)
      error ERR-TRANSFER-FAILED
    )
  )
)
