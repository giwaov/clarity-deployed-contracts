
;; nova-cross-chain-bridge.clar
;; Bridge intent signals
;; CLARITY VERSION: 2

(define-public (bridge-out (amount uint) (dest-chain (string-ascii 32)) (dest-addr (string-ascii 64)))
    (begin
        (print {event: "bridge-out", amount: amount, dest-chain: dest-chain, dest-addr: dest-addr})
        (ok true)
    )
)
