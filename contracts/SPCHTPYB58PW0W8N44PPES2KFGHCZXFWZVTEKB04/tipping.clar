;; Tipping Platform Contract
;; Send tips to content creators

(define-constant err-self-tip (err u100))
(define-constant err-zero-amount (err u101))

(define-map creator-stats
    principal
    {
        total-received: uint,
        tip-count: uint,
        top-tipper: (optional principal),
        top-tip-amount: uint
    }
)

(define-map tipper-stats
    principal
    {
        total-sent: uint,
        tip-count: uint,
        favorite-creator: (optional principal)
    }
)

(define-public (send-tip (recipient principal) (amount uint) (message (optional (string-utf8 280))))
    (let (
        (recipient-stats (default-to
            {total-received: u0, tip-count: u0, top-tipper: none, top-tip-amount: u0}
            (map-get? creator-stats recipient)))

        (sender-stats (default-to
            {total-sent: u0, tip-count: u0, favorite-creator: none}
            (map-get? tipper-stats tx-sender)))
    )
        (asserts! (not (is-eq tx-sender recipient)) err-self-tip)
        (asserts! (> amount u0) err-zero-amount)

        (try! (stx-transfer? amount tx-sender recipient))

        (map-set creator-stats recipient {
            total-received: (+ (get total-received recipient-stats) amount),
            tip-count: (+ (get tip-count recipient-stats) u1),
            top-tipper: (if (> amount (get top-tip-amount recipient-stats))
                (some tx-sender)
                (get top-tipper recipient-stats)),
            top-tip-amount: (if (> amount (get top-tip-amount recipient-stats))
                amount
                (get top-tip-amount recipient-stats))
        })

        (map-set tipper-stats tx-sender {
            total-sent: (+ (get total-sent sender-stats) amount),
            tip-count: (+ (get tip-count sender-stats) u1),
            favorite-creator: (some recipient)
        })

        (match message
            msg
            (print {
                event: "tip-sent",
                from: tx-sender,
                to: recipient,
                amount: amount,
                message: (some msg)
            })
            (print {
                event: "tip-sent",
                from: tx-sender,
                to: recipient,
                amount: amount,
                message: none
            })
        )

        (ok true)
    )
)

(define-public (send-bulk-tips (recipients (list 10 {recipient: principal, amount: uint})))
    (ok (fold process-tip recipients {success: true}))
)

(define-private (process-tip
    (tip-data {recipient: principal, amount: uint})
    (state {success: bool}))
    (begin
        (unwrap-panic (send-tip (get recipient tip-data) (get amount tip-data) none))
        state
    )
)

(define-read-only (get-creator-stats (creator principal))
    (map-get? creator-stats creator)
)

(define-read-only (get-tipper-stats (tipper principal))
    (map-get? tipper-stats tipper)
)
