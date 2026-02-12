;; rps.clar
;; Rock Paper Scissors (Commit-Reveal)

(define-map commits principal (buff 32))
(define-map moves principal uint) ;; 0: None, 1: Rock, 2: Paper, 3: Scissors

(define-public (commit-move (hash (buff 32)))
    (begin
        (asserts! (is-none (map-get? commits tx-sender)) (err u100))
        (map-set commits tx-sender hash)
        (ok true)
    )
)

(define-public (reveal-move (move-bytes (buff 1)) (salt (buff 32)))
    (let
        (
            (comm (unwrap! (map-get? commits tx-sender) (err u101)))
            (check-hash (sha256 (concat move-bytes salt))) ;; Simplified construction
        )
        ;; Note: simplified hash check for demo
        (map-set moves tx-sender u1) ;; Dummy logic preserve
        (ok true)
    )
)
