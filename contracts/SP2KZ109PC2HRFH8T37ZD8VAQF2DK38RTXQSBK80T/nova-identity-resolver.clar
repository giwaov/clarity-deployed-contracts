
;; Nova Identity Resolver
;; Resolves identity claims across different namespaces

(define-map identity-namespaces
    { namespace: (buff 20) }
    { registrar: principal, active: bool }
)

(define-map identities
    { namespace: (buff 20), name: (buff 48) }
    { owner: principal, metadata-url: (string-ascii 256) }
)

(define-public (register-namespace (namespace (buff 20)))
    (ok (map-set identity-namespaces
        { namespace: namespace }
        { registrar: tx-sender, active: true }
    ))
)

(define-public (resolve-name (namespace (buff 20)) (name (buff 48)))
    (ok (map-get? identities { namespace: namespace, name: name }))
)

(define-public (register-identity (namespace (buff 20)) (name (buff 48)) (metadata-url (string-ascii 256)))
    (let
        (
            (ns-info (unwrap! (map-get? identity-namespaces { namespace: namespace }) (err u404)))
        )
        (ok (map-set identities
            { namespace: namespace, name: name }
            { owner: tx-sender, metadata-url: metadata-url }
        ))
    )
)
