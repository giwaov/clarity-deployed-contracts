(impl-trait .orange-sip010-ft-trait-v19.ft-trait)
(define-fungible-token orange-token)
(define-data-var contract-owner principal tx-sender)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        ;; Caller-Identity Pattern: allow if tx-sender is sender OR if the calling contract is the sender
        (asserts! (or (is-eq tx-sender sender) (is-eq contract-caller sender)) (err u101))
        (try! (ft-transfer? orange-token amount sender recipient))
        (match memo to-print (print to-print) 0x)
        (ok true)
    )
)

(define-read-only (get-name) (ok "Orange Token"))
(define-read-only (get-symbol) (ok "ORNG"))
(define-read-only (get-decimals) (ok u6))
(define-read-only (get-total-supply) (ok (ft-get-supply orange-token)))
(define-read-only (get-token-uri) (ok none))

(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err u100))
        (ft-mint? orange-token amount recipient)
    )
)
