;; ---------------------------------------------------------
;; Pause Guardian
;; Emergency pause toggle
;; ---------------------------------------------------------

(define-data-var paused bool false)


(define-public (toggle)
    (begin
        (var-set paused (not (var-get paused)))
        (ok (var-get paused))
    )
)
