;; Freelance Escrow - Clarity 4
;; Milestone-based escrow for freelance work

(define-constant contract-owner tx-sender)
(define-constant err-not-found (err u9000))
(define-constant err-unauthorized (err u9001))
(define-constant err-already-released (err u9002))
(define-constant err-dispute-active (err u9003))

(define-data-var escrow-nonce uint u0)

(define-map escrows
    uint
    {
        client: principal,
        freelancer: principal,
        amount: uint,
        released: bool,
        disputed: bool,
        arbiter: (optional principal)
    }
)

(define-map milestones
    {escrow-id: uint, milestone-id: uint}
    {
        description: (string-utf8 200),
        percentage: uint,
        approved: bool,
        released: bool
    }
)

(define-read-only (get-escrow (escrow-id uint))
    (map-get? escrows escrow-id)
)

(define-read-only (get-milestone (escrow-id uint) (milestone-id uint))
    (map-get? milestones {escrow-id: escrow-id, milestone-id: milestone-id})
)

(define-public (create-escrow
    (freelancer principal)
    (amount uint)
    (arbiter principal)
)
    (let (
        (escrow-id (var-get escrow-nonce))
    )
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (map-set escrows escrow-id {
            client: tx-sender,
            freelancer: freelancer,
            amount: amount,
            released: false,
            disputed: false,
            arbiter: (some arbiter)
        })
        
        (var-set escrow-nonce (+ escrow-id u1))
        (ok escrow-id)
    )
)

(define-public (add-milestone
    (escrow-id uint)
    (milestone-id uint)
    (description (string-utf8 200))
    (percentage uint)
)
    (let (
        (escrow (unwrap! (get-escrow escrow-id) err-not-found))
    )
        (asserts! (is-eq tx-sender (get client escrow)) err-unauthorized)
        
        (ok (map-set milestones {escrow-id: escrow-id, milestone-id: milestone-id}
            {
                description: description,
                percentage: percentage,
                approved: false,
                released: false
            }
        ))
    )
)

(define-public (approve-milestone (escrow-id uint) (milestone-id uint))
    (let (
        (escrow (unwrap! (get-escrow escrow-id) err-not-found))
        (milestone (unwrap! (get-milestone escrow-id milestone-id) err-not-found))
        (payment (/ (* (get amount escrow) (get percentage milestone)) u100))
    )
        (asserts! (is-eq tx-sender (get client escrow)) err-unauthorized)
        (asserts! (not (get released milestone)) err-already-released)
        
        (map-set milestones {escrow-id: escrow-id, milestone-id: milestone-id}
            (merge milestone {approved: true, released: true})
        )
        
        (try! (as-contract (stx-transfer? payment tx-sender (get freelancer escrow))))
        (ok true)
    )
)

(define-public (raise-dispute (escrow-id uint))
    (let (
        (escrow (unwrap! (get-escrow escrow-id) err-not-found))
    )
        (asserts! (or 
            (is-eq tx-sender (get client escrow))
            (is-eq tx-sender (get freelancer escrow))
        ) err-unauthorized)
        
        (ok (map-set escrows escrow-id (merge escrow {disputed: true})))
    )
)

(define-public (resolve-dispute
    (escrow-id uint)
    (client-amount uint)
    (freelancer-amount uint)
)
    (let (
        (escrow (unwrap! (get-escrow escrow-id) err-not-found))
        (arbiter (unwrap! (get arbiter escrow) err-not-found))
    )
        (asserts! (is-eq tx-sender arbiter) err-unauthorized)
        (asserts! (get disputed escrow) err-dispute-active)
        
        (try! (as-contract (stx-transfer? client-amount tx-sender (get client escrow))))
        (try! (as-contract (stx-transfer? freelancer-amount tx-sender (get freelancer escrow))))
        
        (ok (map-set escrows escrow-id (merge escrow {released: true})))
    )
)
