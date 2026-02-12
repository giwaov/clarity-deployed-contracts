;; -------------------------------------
;; Errors
;; -------------------------------------
(define-constant ERR_NOT_OWNER u100)
(define-constant ERR_LOCKED u101)
(define-constant ERR_UNLOCKED u102)
(define-constant ERR_NO_BALANCE u103)
(define-constant ERR_TRANSFER_FAILED u104) ;; new: transfer failed

;; -------------------------------------
;; State
;; -------------------------------------
(define-data-var owner principal tx-sender)
(define-data-var unlock-time uint stacks-block-time)

;; Track total deposited STX
(define-data-var total-balance uint u0)

;; Track individual deposits (for refunds)
(define-map deposits
    principal
    uint
)

;; Beneficiaries
(define-map beneficiaries
    principal
    bool
)

;; -------------------------------------
;; Deposit STX
;; -------------------------------------
(define-public (deposit (amount uint))
    (begin
        (asserts! (> amount u0) (err ERR_NO_BALANCE))

        ;; ensure transfer succeeded
        (asserts! (is-ok (stx-transfer? amount tx-sender tx-sender))
            (err ERR_TRANSFER_FAILED)
        )

        ;; Update balances
        (var-set total-balance (+ (var-get total-balance) amount))
        (map-set deposits tx-sender
            (+ amount (default-to u0 (map-get? deposits tx-sender)))
        )

        (print {
            event: "deposit",
            sender: tx-sender,
            amount: amount,
            timestamp: stacks-block-time,
        })

        (ok amount)
    )
)

;; -------------------------------------
;; Refund before unlock
;; -------------------------------------
(define-public (refund)
    (let ((amount (default-to u0 (map-get? deposits tx-sender))))
        (begin
            (asserts! (< stacks-block-time (var-get unlock-time))
                (err ERR_UNLOCKED)
            )
            (asserts! (> amount u0) (err ERR_NO_BALANCE))

            (map-delete deposits tx-sender)
            (var-set total-balance (- (var-get total-balance) amount))

            ;; ensure transfer succeeded
            (asserts! (is-ok (stx-transfer? amount tx-sender tx-sender))
                (err ERR_TRANSFER_FAILED)
            )

            (print {
                event: "refund",
                sender: tx-sender,
                amount: amount,
                timestamp: stacks-block-time,
            })

            (ok amount)
        )
    )
)

;; -------------------------------------
;; Withdraw (owner or beneficiaries)
;; -------------------------------------
(define-public (withdraw (amount uint))
    (begin
        (asserts! (>= stacks-block-time (var-get unlock-time)) (err ERR_LOCKED))
        (asserts!
            (or
                (is-eq tx-sender (var-get owner))
                (is-some (map-get? beneficiaries tx-sender))
            )
            (err ERR_NOT_OWNER)
        )

        (var-set total-balance (- (var-get total-balance) amount))

        ;; ensure transfer succeeded
        (asserts! (is-ok (stx-transfer? amount tx-sender tx-sender))
            (err ERR_TRANSFER_FAILED)
        )

        (print {
            event: "withdraw",
            recipient: tx-sender,
            amount: amount,
            timestamp: stacks-block-time,
        })

        (ok amount)
    )
)

;; -------------------------------------
;; Extend lock time (owner only)
;; -------------------------------------
(define-public (extend-lock (new-unlock uint))
    (begin
        (asserts! (is-eq tx-sender (var-get owner)) (err ERR_NOT_OWNER))
        (asserts! (> new-unlock (var-get unlock-time)) (err ERR_LOCKED))

        (var-set unlock-time new-unlock)

        (print {
            event: "lock-extended",
            new-unlock: new-unlock,
            timestamp: stacks-block-time,
        })

        (ok new-unlock)
    )
)

;; -------------------------------------
;; Manage beneficiaries
;; -------------------------------------
(define-public (add-beneficiary (who principal))
    (begin
        (asserts! (is-eq tx-sender (var-get owner)) (err ERR_NOT_OWNER))
        (map-set beneficiaries who true)

        (print {
            event: "beneficiary-added",
            who: who,
        })

        (ok true)
    )
)

(define-public (remove-beneficiary (who principal))
    (begin
        (asserts! (is-eq tx-sender (var-get owner)) (err ERR_NOT_OWNER))
        (map-delete beneficiaries who)

        (print {
            event: "beneficiary-removed",
            who: who,
        })

        (ok true)
    )
)

;; -------------------------------------
;; Read-only functions
;; -------------------------------------
(define-read-only (get-total-balance)
    (var-get total-balance)
)

(define-read-only (get-unlock-time)
    (var-get unlock-time)
)

(define-read-only (is-unlocked)
    (>= stacks-block-time (var-get unlock-time))
)

(define-read-only (get-user-deposit (user principal))
    (default-to u0 (map-get? deposits user))
)
