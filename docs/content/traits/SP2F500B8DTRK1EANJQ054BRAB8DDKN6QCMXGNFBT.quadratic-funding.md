---
title: "Trait quadratic-funding"
draft: true
---
```
;; Quadratic Funding - Clarity 4
;; Quadratic funding for public goods

(define-constant contract-owner tx-sender)
(define-constant err-round-not-active (err u10000))
(define-constant err-not-found (err u10001))
(define-constant err-round-ended (err u10002))

(define-data-var round-nonce uint u0)
(define-data-var current-round uint u0)

(define-map funding-rounds
    uint
    {
        matching-pool: uint,
        start-height: uint,
        end-height: uint,
        total-contributions: uint,
        active: bool
    }
)

(define-map projects
    {round-id: uint, project-id: uint}
    {
        creator: principal,
        title: (string-utf8 100),
        description: (string-utf8 500),
        total-raised: uint,
        contributor-count: uint,
        matching-amount: uint
    }
)

(define-map contributions
    {round-id: uint, project-id: uint, contributor: principal}
    uint
)

(define-read-only (get-round (round-id uint))
    (map-get? funding-rounds round-id)
)

(define-read-only (get-project (round-id uint) (project-id uint))
    (map-get? projects {round-id: round-id, project-id: project-id})
)

(define-public (create-round (matching-pool uint) (duration-blocks uint))
    (let (
        (round-id (var-get round-nonce))
    )
        (asserts! (is-eq tx-sender contract-owner) err-not-found)
        (try! (stx-transfer? matching-pool tx-sender (as-contract tx-sender)))
        
        (map-set funding-rounds round-id {
            matching-pool: matching-pool,
            start-height: stacks-block-height,
            end-height: (+ stacks-block-height duration-blocks),
            total-contributions: u0,
            active: true
        })
        
        (var-set round-nonce (+ round-id u1))
        (var-set current-round round-id)
        (ok round-id)
    )
)

(define-public (submit-project
    (round-id uint)
    (project-id uint)
    (title (string-utf8 100))
    (description (string-utf8 500))
)
    (let (
        (round (unwrap! (get-round round-id) err-not-found))
    )
        (asserts! (get active round) err-round-not-active)
        (asserts! (< stacks-block-height (get end-height round)) err-round-ended)
        
        (ok (map-set projects {round-id: round-id, project-id: project-id}
            {
                creator: tx-sender,
                title: title,
                description: description,
                total-raised: u0,
                contributor-count: u0,
                matching-amount: u0
            }
        ))
    )
)

(define-public (contribute (round-id uint) (project-id uint) (amount uint))
    (let (
        (round (unwrap! (get-round round-id) err-not-found))
        (project (unwrap! (get-project round-id project-id) err-not-found))
        (existing-contribution (default-to u0 
            (map-get? contributions {round-id: round-id, project-id: project-id, contributor: tx-sender})))
    )
        (asserts! (get active round) err-round-not-active)
        (asserts! (< stacks-block-height (get end-height round)) err-round-ended)
        
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (map-set contributions {round-id: round-id, project-id: project-id, contributor: tx-sender}
            (+ existing-contribution amount)
        )
        
        (map-set projects {round-id: round-id, project-id: project-id}
            (merge project {
                total-raised: (+ (get total-raised project) amount),
                contributor-count: (if (is-eq existing-contribution u0)
                    (+ (get contributor-count project) u1)
                    (get contributor-count project)
                )
            })
        )
        
        (ok true)
    )
)

(define-public (finalize-round (round-id uint))
    (let (
        (round (unwrap! (get-round round-id) err-not-found))
    )
        (asserts! (is-eq tx-sender contract-owner) err-not-found)
        (asserts! (>= stacks-block-height (get end-height round)) err-round-ended)
        
        ;; In production, calculate quadratic matching using sqrt formula
        (ok (map-set funding-rounds round-id (merge round {active: false})))
    )
)

```
