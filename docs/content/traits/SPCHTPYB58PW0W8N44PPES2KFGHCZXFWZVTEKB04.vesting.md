---
title: "Trait vesting"
draft: true
---
```
;; Token Vesting Contract
;; Linear vesting schedule for tokens

(define-constant contract-owner tx-sender)
(define-constant err-not-found (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-not-started (err u102))
(define-constant err-no-vested-tokens (err u103))

(define-data-var vesting-id-nonce uint u0)

(define-map vesting-schedules
    uint
    {
        beneficiary: principal,
        total-amount: uint,
        claimed-amount: uint,
        start-block: uint,
        cliff-duration: uint,
        vesting-duration: uint,
        revocable: bool,
        revoked: bool
    }
)

;; Create vesting schedule
(define-public (create-vesting
    (beneficiary principal)
    (total-amount uint)
    (start-block uint)
    (cliff-duration uint)
    (vesting-duration uint)
    (revocable bool))
    (let
        (
            (vesting-id (var-get vesting-id-nonce))
        )
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        
        (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
        
        (map-set vesting-schedules vesting-id {
            beneficiary: beneficiary,
            total-amount: total-amount,
            claimed-amount: u0,
            start-block: start-block,
            cliff-duration: cliff-duration,
            vesting-duration: vesting-duration,
            revocable: revocable,
            revoked: false
        })
        
        (var-set vesting-id-nonce (+ vesting-id u1))
        (ok vesting-id)
    )
)

;; Claim vested tokens
(define-public (claim-vested (vesting-id uint))
    (let
        (
            (schedule (unwrap! (map-get? vesting-schedules vesting-id) err-not-found))
            (vested-amount (calculate-vested-amount vesting-id))
            (claimable (- vested-amount (get claimed-amount schedule)))
        )
        (asserts! (is-eq tx-sender (get beneficiary schedule)) err-not-authorized)
        (asserts! (not (get revoked schedule)) err-not-found)
        (asserts! (> claimable u0) err-no-vested-tokens)
        
        (try! (as-contract (stx-transfer? claimable tx-sender (get beneficiary schedule))))
        
        (map-set vesting-schedules vesting-id (merge schedule {
            claimed-amount: (+ (get claimed-amount schedule) claimable)
        }))
        
        (ok claimable)
    )
)

;; Revoke vesting (if revocable)
(define-public (revoke-vesting (vesting-id uint))
    (let
        (
            (schedule (unwrap! (map-get? vesting-schedules vesting-id) err-not-found))
            (vested-amount (calculate-vested-amount vesting-id))
            (claimable (- vested-amount (get claimed-amount schedule)))
            (remaining (- (get total-amount schedule) vested-amount))
        )
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (get revocable schedule) err-not-authorized)
        (asserts! (not (get revoked schedule)) err-not-found)
        
        ;; Transfer claimable amount to beneficiary
        (if (> claimable u0)
            (try! (as-contract (stx-transfer? claimable tx-sender (get beneficiary schedule))))
            true
        )
        
        ;; Return unvested tokens to owner
        (if (> remaining u0)
            (try! (as-contract (stx-transfer? remaining tx-sender contract-owner)))
            true
        )
        
        (map-set vesting-schedules vesting-id (merge schedule {
            claimed-amount: vested-amount,
            revoked: true
        }))
        
        (ok true)
    )
)

;; Calculate vested amount
(define-read-only (calculate-vested-amount (vesting-id uint))
    (match (map-get? vesting-schedules vesting-id)
        schedule
        (let
            (
                (cliff-end (+ (get start-block schedule) (get cliff-duration schedule)))
                (vesting-end (+ (get start-block schedule) (get vesting-duration schedule)))
            )
            (if (get revoked schedule)
                (get claimed-amount schedule)
                (if (< block-height cliff-end)
                    u0
                    (if (>= block-height vesting-end)
                        (get total-amount schedule)
                        (/ (* (get total-amount schedule) 
                              (- block-height (get start-block schedule)))
                           (get vesting-duration schedule))
                    )
                )
            )
        )
        u0
    )
)

;; Get vesting schedule
(define-read-only (get-vesting-schedule (vesting-id uint))
    (map-get? vesting-schedules vesting-id)
)

;; Get claimable amount
(define-read-only (get-claimable-amount (vesting-id uint))
    (match (map-get? vesting-schedules vesting-id)
        schedule
        (- (calculate-vested-amount vesting-id) (get claimed-amount schedule))
        u0
    )
)

```
