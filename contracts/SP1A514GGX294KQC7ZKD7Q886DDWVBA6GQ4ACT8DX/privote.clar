(define-constant err-no-credits (err u100))
(define-constant err-invalid-project (err u101))
(define-constant err-round-closed (err u102))
(define-constant err-not-authorized (err u103))
(define-constant err-round-not-found (err u104))

(define-constant TOTAL-CREDITS u99)

(define-data-var contract-owner principal tx-sender)

(define-map rounds uint {
  open: bool
})

(define-map projects {round-id: uint, project-id: uint} {
  owner: principal,
  votes: uint
})

(define-map voter-credits {voter: principal, round-id: uint} uint)

;; Admin function to open a round
(define-public (open-round (round-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-not-authorized)
    (map-set rounds round-id {open: true})
    (ok round-id)
  )
)

;; Admin function to close a round
(define-public (close-round (round-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-not-authorized)
    (asserts! (is-some (map-get? rounds round-id)) err-round-not-found)
    (map-set rounds round-id {open: false})
    (ok round-id)
  )
)

;; Register a project
(define-public (register-project (round-id uint) (project-id uint))
  (begin
    (asserts! (is-none (map-get? projects {round-id: round-id, project-id: project-id})) err-invalid-project)
    (map-set projects {round-id: round-id, project-id: project-id} {
      owner: tx-sender,
      votes: u0
    })
    (ok project-id)
  )
)

;; Cast votes on a project
(define-public (vote (round-id uint) (project-id uint) (amount uint))
  (let (
        (round (map-get? rounds round-id))
        (remaining (default-to TOTAL-CREDITS (map-get? voter-credits {voter: tx-sender, round-id: round-id})))
        (project (map-get? projects {round-id: round-id, project-id: project-id}))
       )
    (begin
      (asserts! (is-some round) err-round-not-found)
      (asserts! (get open (unwrap! round err-round-not-found)) err-round-closed)
      (asserts! (is-some project) err-invalid-project)
      (asserts! (>= remaining amount) err-no-credits)

      ;; deduct credits
      (map-set voter-credits {voter: tx-sender, round-id: round-id} (- remaining amount))

      ;; add votes
      (map-set projects {round-id: round-id, project-id: project-id} {
        owner: (get owner (unwrap! project err-invalid-project)),
        votes: (+ (get votes (unwrap! project err-invalid-project)) amount)
      })

      (ok amount)
    )
  )
)

;; Read-only helpers
(define-read-only (get-project (round-id uint) (project-id uint))
  (map-get? projects {round-id: round-id, project-id: project-id})
)

(define-read-only (get-remaining-credits (round-id uint) (voter principal))
  (default-to TOTAL-CREDITS (map-get? voter-credits {voter: voter, round-id: round-id}))
)

(define-read-only (get-round-status (round-id uint))
  (map-get? rounds round-id)
)

(define-read-only (is-contract-owner (caller principal))
  (is-eq caller (var-get contract-owner))
)