;; bns-simple.clar
;; Simplified Name System

(define-map names (string-ascii 20) principal)
(define-constant COST u50)

(define-public (register (name (string-ascii 20)))
    (begin
        (asserts! (is-none (map-get? names name)) (err u100)) ;; ERR_TAKEN
        (try! (stx-transfer? COST tx-sender (as-contract tx-sender)))
        (map-set names name tx-sender)
        (ok true)
    )
)

(define-read-only (resolve (name (string-ascii 20)))
    (map-get? names name)
)
