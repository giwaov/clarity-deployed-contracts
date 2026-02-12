;; token-swap.clar
;; A simple vending machine: swap STX for Credits (internal map)

(define-map credits principal uint)
(define-constant EXCHANGE_RATE u100) ;; 100 Credits per 1 STX

(define-public (buy-credits (stx-amount uint))
    (let
        (
            (credit-amount (* stx-amount EXCHANGE_RATE))
            (current-credits (default-to u0 (map-get? credits tx-sender)))
        )
        (try! (stx-transfer? stx-amount tx-sender (as-contract tx-sender)))
        (map-set credits tx-sender (+ current-credits credit-amount))
        (ok credit-amount)
    )
)

(define-public (sell-credits (credit-amount uint))
    (let
        (
            (stx-amount (/ credit-amount EXCHANGE_RATE))
            (current-credits (unwrap! (map-get? credits tx-sender) (err u100)))
        )
        (asserts! (>= current-credits credit-amount) (err u101))
        (try! (as-contract (stx-transfer? stx-amount tx-sender tx-sender)))
        (map-set credits tx-sender (- current-credits credit-amount))
        (ok stx-amount)
    )
)

(define-read-only (get-credits (user principal))
    (default-to u0 (map-get? credits user))
)
