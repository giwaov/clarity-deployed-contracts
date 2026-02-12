
;; nova-content-tipping.clar
;; Tip content creators
;; CLARITY VERSION: 2

(define-public (tip (recipient principal) (amount uint) (content-id (string-utf8 64)))
    (begin
        (try! (stx-transfer? amount tx-sender recipient))
        (print {event: "tip", recipient: recipient, amount: amount, content-id: content-id})
        (ok true)
    )
)
