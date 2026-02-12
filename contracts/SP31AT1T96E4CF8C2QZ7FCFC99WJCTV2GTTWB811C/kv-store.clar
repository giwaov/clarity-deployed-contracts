(define-map store {key: (buff 32)} {value: (buff 32)})

(define-public (put (k (buff 32)) (v (buff 32)))
    (begin
        (map-set store {key: k} {value: v})
        (ok true)
    )
)
