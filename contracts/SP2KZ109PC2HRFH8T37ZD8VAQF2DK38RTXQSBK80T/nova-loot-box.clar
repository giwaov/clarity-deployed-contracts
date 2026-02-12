
;; nova-loot-box.clar
;; Randomly distributes items
;; CLARITY VERSION: 2

(define-data-var nonce uint u0)

(define-public (open-box)
    (let (
        (random-val (mod (var-get nonce) u100))
    )
    (var-set nonce (+ (var-get nonce) u1))
    ;; Random logic simulated
    (ok random-val)
    )
)
