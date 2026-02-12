;; ---------------------------------------------------------
;; Protocol Upgrades
;; Tracks protocol upgrade count
;; ---------------------------------------------------------

(define-data-var upgrades uint u0)


(define-public (upgrade)
    (begin
        (var-set upgrades (+ (var-get upgrades) u1))
        (ok (var-get upgrades))
    )
)
