
;; nova-quantum-rng-mock.clar
;; Mock quantum random number generator
;; CLARITY VERSION: 2

(define-public (get-random)
    (ok (mod block-height u100))
)
