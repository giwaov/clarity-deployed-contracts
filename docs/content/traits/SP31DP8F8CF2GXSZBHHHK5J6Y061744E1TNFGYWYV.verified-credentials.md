---
title: "Trait verified-credentials"
draft: true
---
```

;; verified-credentials.clar
;; Issuers can sign claims about users (KYC proof, etc.).
;; CLARITY VERSION: 4

(define-constant ERR-NOT-AUTHORIZED (err u100))

(define-map claims
    {issuer: principal, subject: principal, claim-id: (string-ascii 32)}
    {
        data: (buff 128),
        verified: bool,
        revoked: bool
    }
)

(define-map authorized-issuers principal bool)

(define-data-var admin principal tx-sender)

(define-public (add-issuer (issuer principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
        (map-set authorized-issuers issuer true)
        (ok true)
    )
)

(define-public (issue-claim (subject principal) (claim-id (string-ascii 32)) (data (buff 128)))
    (let (
        (issuer tx-sender)
    )
    (asserts! (default-to false (map-get? authorized-issuers issuer)) ERR-NOT-AUTHORIZED)
    
    (map-set claims {issuer: issuer, subject: subject, claim-id: claim-id} {
        data: data,
        verified: true,
        revoked: false
    })
    (ok true))
)

(define-public (revoke-claim (subject principal) (claim-id (string-ascii 32)))
    (let (
        (issuer tx-sender)
        (claim (unwrap! (map-get? claims {issuer: issuer, subject: subject, claim-id: claim-id}) (err u101)))
    )
    (map-set claims {issuer: issuer, subject: subject, claim-id: claim-id} (merge claim { revoked: true }))
    (ok true))
)

(define-read-only (get-claim (issuer principal) (subject principal) (claim-id (string-ascii 32)))
    (map-get? claims {issuer: issuer, subject: subject, claim-id: claim-id})
)

```
