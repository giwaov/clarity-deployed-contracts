---
title: "Trait StackerMint"
draft: true
---
```
;; title: StackerMint
;; version:
;; summary:
;; description:

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1001))
(define-constant ERR-VESTING-NOT-FOUND (err u1002))
(define-constant ERR-NO-TOKENS-AVAILABLE (err u1003))
(define-constant ERR-VESTING-ALREADY-EXISTS (err u1004))
(define-constant ERR-INVALID-SCHEDULE (err u1005))
(define-constant ERR-VESTING-NOT-STARTED (err u1006))

;; Data variables
(define-data-var total-vesting-schedules uint u0)

;; Data maps
(define-map vesting-schedules
    { beneficiary: principal, schedule-id: uint }
    {
        total-amount: uint,
        released-amount: uint,
        start-time: uint,                   ;; Clarity 4: Unix timestamp
        cliff-time: uint,                   ;; Clarity 4: Unix timestamp
        end-time: uint,                     ;; Clarity 4: Unix timestamp
        revocable: bool,
        revoked: bool,
        revoked-at: (optional uint)         ;; Clarity 4: Unix timestamp
    }
)

(define-map beneficiary-schedule-count { beneficiary: principal } uint)

(define-map vesting-releases
    { beneficiary: principal, schedule-id: uint, release-index: uint }
    {
        amount: uint,
        released-at: uint                   ;; Clarity 4: Unix timestamp
    }
)

(define-map release-count { beneficiary: principal, schedule-id: uint } uint)

;; Read-only functions
(define-read-only (get-vesting-schedule (beneficiary principal) (schedule-id uint))
    (ok (map-get? vesting-schedules { beneficiary: beneficiary, schedule-id: schedule-id }))
)

(define-read-only (get-beneficiary-schedule-count (beneficiary principal))
    (ok (default-to u0 (map-get? beneficiary-schedule-count { beneficiary: beneficiary })))
)

(define-read-only (get-vesting-release (beneficiary principal) (schedule-id uint) (release-index uint))
    (ok (map-get? vesting-releases { beneficiary: beneficiary, schedule-id: schedule-id, release-index: release-index }))
)

(define-read-only (calculate-vested-amount (beneficiary principal) (schedule-id uint))
    (match (map-get? vesting-schedules { beneficiary: beneficiary, schedule-id: schedule-id })
        schedule
            (if (get revoked schedule)
                (ok u0)
                (if (< stacks-block-time (get cliff-time schedule))
                    (ok u0)
                    (if (>= stacks-block-time (get end-time schedule))
                        (ok (get total-amount schedule))
                        (let
                            (
                                (elapsed (- stacks-block-time (get start-time schedule)))
                                (duration (- (get end-time schedule) (get start-time schedule)))
                                (vested (/ (* (get total-amount schedule) elapsed) duration))
                            )
                            (ok vested)
                        )
                    )
                )
            )
        ERR-VESTING-NOT-FOUND
    )
)

(define-read-only (calculate-releasable-amount (beneficiary principal) (schedule-id uint))
    (match (map-get? vesting-schedules { beneficiary: beneficiary, schedule-id: schedule-id })
        schedule
            (let
                (
                    (vested (unwrap! (calculate-vested-amount beneficiary schedule-id) ERR-VESTING-NOT-FOUND))
                    (released (get released-amount schedule))
                )
                (ok (if (> vested released) (- vested released) u0))
            )
        ERR-VESTING-NOT-FOUND
    )
)

;; Public functions
(define-public (create-vesting-schedule
    (beneficiary principal)
    (total-amount uint)
    (start-time uint)
    (cliff-duration uint)
    (vesting-duration uint)
    (revocable bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (> total-amount u0) ERR-INVALID-SCHEDULE)
        (asserts! (> vesting-duration u0) ERR-INVALID-SCHEDULE)
        (asserts! (>= start-time stacks-block-time) ERR-INVALID-SCHEDULE)

        (let
            (
                (schedule-id (default-to u0 (map-get? beneficiary-schedule-count { beneficiary: beneficiary })))
                (cliff-time (+ start-time cliff-duration))
                (end-time (+ start-time vesting-duration))
            )
            (map-set vesting-schedules
                { beneficiary: beneficiary, schedule-id: schedule-id }
                {
                    total-amount: total-amount,
                    released-amount: u0,
                    start-time: start-time,
                    cliff-time: cliff-time,
                    end-time: end-time,
                    revocable: revocable,
                    revoked: false,
                    revoked-at: none
                }
            )

            (map-set beneficiary-schedule-count { beneficiary: beneficiary } (+ schedule-id u1))
            (var-set total-vesting-schedules (+ (var-get total-vesting-schedules) u1))

            (print {
                event: "vesting-schedule-created",
                beneficiary: beneficiary,
                schedule-id: schedule-id,
                total-amount: total-amount,
                start-time: start-time,
                cliff-time: cliff-time,
                end-time: end-time,
                timestamp: stacks-block-time
            })
            (ok schedule-id)
        )
    )
)

(define-public (release-vested-tokens (schedule-id uint))
    (let
        (
            (schedule (unwrap! (map-get? vesting-schedules { beneficiary: tx-sender, schedule-id: schedule-id }) ERR-VESTING-NOT-FOUND))
            (releasable (unwrap! (calculate-releasable-amount tx-sender schedule-id) ERR-VESTING-NOT-FOUND))
        )
        (asserts! (not (get revoked schedule)) ERR-NOT-AUTHORIZED)
        (asserts! (>= stacks-block-time (get cliff-time schedule)) ERR-VESTING-NOT-STARTED)
        (asserts! (> releasable u0) ERR-NO-TOKENS-AVAILABLE)

        (let
            (
                (release-index (default-to u0 (map-get? release-count { beneficiary: tx-sender, schedule-id: schedule-id })))
                (new-released (+ (get released-amount schedule) releasable))
            )
            ;; Update vesting schedule
            (map-set vesting-schedules
                { beneficiary: tx-sender, schedule-id: schedule-id }
                (merge schedule { released-amount: new-released })
            )

            ;; Record release
            (map-set vesting-releases
                { beneficiary: tx-sender, schedule-id: schedule-id, release-index: release-index }
                {
                    amount: releasable,
                    released-at: stacks-block-time
                }
            )

            (map-set release-count { beneficiary: tx-sender, schedule-id: schedule-id } (+ release-index u1))

            (print {
                event: "tokens-released",
                beneficiary: tx-sender,
                schedule-id: schedule-id,
                amount: releasable,
                timestamp: stacks-block-time
            })
            (ok releasable)
        )
    )
)

(define-public (revoke-vesting (beneficiary principal) (schedule-id uint))
    (let
        (
            (schedule (unwrap! (map-get? vesting-schedules { beneficiary: beneficiary, schedule-id: schedule-id }) ERR-VESTING-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (get revocable schedule) ERR-NOT-AUTHORIZED)
        (asserts! (not (get revoked schedule)) ERR-NOT-AUTHORIZED)

        (map-set vesting-schedules
            { beneficiary: beneficiary, schedule-id: schedule-id }
            (merge schedule {
                revoked: true,
                revoked-at: (some stacks-block-time)
            })
        )

        (print {
            event: "vesting-revoked",
            beneficiary: beneficiary,
            schedule-id: schedule-id,
            timestamp: stacks-block-time
        })
        (ok true)
    )
)

(define-public (batch-create-vesting (beneficiaries (list 50 { recipient: principal, amount: uint })) (start-time uint) (cliff-duration uint) (vesting-duration uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (ok (map create-vesting-helper beneficiaries))
    )
)

(define-private (create-vesting-helper (beneficiary-data { recipient: principal, amount: uint }))
    (unwrap-panic (create-vesting-schedule
        (get recipient beneficiary-data)
        (get amount beneficiary-data)
        stacks-block-time
        u2592000  ;; 30 days cliff
        u31536000 ;; 365 days vesting
        true
    ))
)

```
