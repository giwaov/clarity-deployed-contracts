;; Title: wrapped stx
;; Description:
;; Wrapped STX allows real STX to be treated the same as any other SIP10

(impl-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)

(define-read-only (get-balance (owner principal))
    (ok (stx-get-balance owner))
)

(define-read-only (get-decimals)
    (ok u6)
)

(define-read-only (get-name)
    (ok "STX")
)

(define-read-only (get-symbol)
    (ok "STX")
)

(define-read-only (get-token-uri)
    (ok (some u"https://www.stacks.co"))
)

(define-read-only (get-total-supply)
    (ok stx-liquid-supply)
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (try! (stx-transfer? amount sender recipient))
        (match memo to-print (print to-print) 0x)
        (ok true)
    )
)