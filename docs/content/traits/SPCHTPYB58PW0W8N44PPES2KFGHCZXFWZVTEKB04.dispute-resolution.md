---
title: "Trait dispute-resolution"
draft: true
---
```
;; Dispute Resolution Contract
;; Decentralized arbitration system

(define-constant err-not-party (err u100))
(define-constant err-already-resolved (err u101))
(define-constant err-not-arbitrator (err u102))

(define-data-var dispute-nonce uint u0)
(define-data-var arbitration-fee uint u500000)

(define-map disputes
    uint
    {
        plaintiff: principal,
        defendant: principal,
        arbitrator: (optional principal),
        stake-amount: uint,
        description: (string-utf8 500),
        plaintiff-evidence: (optional (string-utf8 500)),
        defendant-evidence: (optional (string-utf8 500)),
        resolved: bool,
        winner: (optional principal),
        resolution-block: (optional uint)
    }
)

(define-map arbitrators principal bool)

(define-public (register-arbitrator)
    (begin
        (map-set arbitrators tx-sender true)
        (ok true)
    )
)

(define-public (create-dispute
    (defendant principal)
    (stake-amount uint)
    (description (string-utf8 500)))
    (let ((dispute-id (var-get dispute-nonce)))
        (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))

        (map-set disputes dispute-id {
            plaintiff: tx-sender,
            defendant: defendant,
            arbitrator: none,
            stake-amount: stake-amount,
            description: description,
            plaintiff-evidence: none,
            defendant-evidence: none,
            resolved: false,
            winner: none,
            resolution-block: none
        })

        (var-set dispute-nonce (+ dispute-id u1))
        (ok dispute-id)
    )
)

(define-public (join-dispute (dispute-id uint))
    (let ((dispute (unwrap! (map-get? disputes dispute-id) err-not-party)))
        (asserts! (is-eq tx-sender (get defendant dispute)) err-not-party)
        (asserts! (not (get resolved dispute)) err-already-resolved)
        (try! (stx-transfer? (get stake-amount dispute) tx-sender (as-contract tx-sender)))
        (ok true)
    )
)

(define-public (submit-evidence (dispute-id uint) (evidence (string-utf8 500)))
    (let ((dispute (unwrap! (map-get? disputes dispute-id) err-not-party)))
        (asserts! (not (get resolved dispute)) err-already-resolved)

        (asserts!
            (or
                (is-eq tx-sender (get plaintiff dispute))
                (is-eq tx-sender (get defendant dispute))
            )
            err-not-party
        )

        (if (is-eq tx-sender (get plaintiff dispute))
            (map-set disputes dispute-id (merge dispute {
                plaintiff-evidence: (some evidence)
            }))
            (map-set disputes dispute-id (merge dispute {
                defendant-evidence: (some evidence)
            }))
        )

        (ok true)
    )
)

(define-public (accept-arbitration (dispute-id uint))
    (let ((dispute (unwrap! (map-get? disputes dispute-id) err-not-party)))
        (asserts! (default-to false (map-get? arbitrators tx-sender)) err-not-arbitrator)
        (asserts! (is-none (get arbitrator dispute)) err-already-resolved)

        (map-set disputes dispute-id (merge dispute {
            arbitrator: (some tx-sender)
        }))

        (ok true)
    )
)

(define-public (resolve-dispute (dispute-id uint) (winner principal))
    (let (
        (dispute (unwrap! (map-get? disputes dispute-id) err-not-party))
        (total-stake (* (get stake-amount dispute) u2))
    )
        (asserts! (is-eq (some tx-sender) (get arbitrator dispute)) err-not-arbitrator)
        (asserts! (not (get resolved dispute)) err-already-resolved)

        (try! (as-contract (stx-transfer? total-stake tx-sender winner)))
        (try! (as-contract (stx-transfer? (var-get arbitration-fee) tx-sender tx-sender)))

        (map-set disputes dispute-id (merge dispute {
            resolved: true,
            winner: (some winner),
            resolution-block: (some block-height)
        }))

        (ok true)
    )
)

(define-read-only (get-dispute (dispute-id uint))
    (map-get? disputes dispute-id)
)

(define-read-only (is-arbitrator (user principal))
    (default-to false (map-get? arbitrators user))
)

```
