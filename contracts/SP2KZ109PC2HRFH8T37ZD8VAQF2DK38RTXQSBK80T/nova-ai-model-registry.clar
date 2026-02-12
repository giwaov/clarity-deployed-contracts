
;; nova-ai-model-registry.clar
;; Register AI models
;; CLARITY VERSION: 2

(define-map models
    (string-utf8 64) ;; name
    {
        owner: principal,
        hash: (buff 32)
    }
)

(define-public (register-model (name (string-utf8 64)) (hash (buff 32)))
    (begin
        (map-set models name {owner: tx-sender, hash: hash})
        (ok true)
    )
)
