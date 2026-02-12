(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-DESIGN-NOT-FOUND (err u101))
(define-constant ERR-INVALID-STAGE (err u102))

(define-map chip-designs
  { design-id: uint }
  {
    chip-name: (string-ascii 50),
    architecture: (string-ascii 50),
    process-node: uint,
    transistor-count: uint,
    design-stage: (string-ascii 30),
    designer: principal,
    created-at: uint
  }
)

(define-map design-milestones
  { design-id: uint, milestone-id: uint }
  {
    milestone-name: (string-ascii 50),
    description: (string-ascii 200),
    completed: bool,
    completed-at: uint
  }
)

(define-data-var design-nonce uint u0)

(define-public (create-design
  (chip-name (string-ascii 50))
  (architecture (string-ascii 50))
  (process-node uint)
  (transistor-count uint)
)
  (let ((design-id (var-get design-nonce)))
    (map-set chip-designs
      { design-id: design-id }
      {
        chip-name: chip-name,
        architecture: architecture,
        process-node: process-node,
        transistor-count: transistor-count,
        design-stage: "specification",
        designer: tx-sender,
        created-at: stacks-block-height
      }
    )
    (var-set design-nonce (+ design-id u1))
    (ok design-id)
  )
)

(define-public (add-milestone
  (design-id uint)
  (milestone-id uint)
  (milestone-name (string-ascii 50))
  (description (string-ascii 200))
)
  (let ((design (unwrap! (map-get? chip-designs { design-id: design-id }) ERR-DESIGN-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get designer design)) ERR-NOT-AUTHORIZED)
    (ok (map-set design-milestones
      { design-id: design-id, milestone-id: milestone-id }
      {
        milestone-name: milestone-name,
        description: description,
        completed: false,
        completed-at: u0
      }
    ))
  )
)

(define-public (complete-milestone (design-id uint) (milestone-id uint))
  (let (
    (design (unwrap! (map-get? chip-designs { design-id: design-id }) ERR-DESIGN-NOT-FOUND))
    (milestone (unwrap! (map-get? design-milestones { design-id: design-id, milestone-id: milestone-id }) ERR-DESIGN-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get designer design)) ERR-NOT-AUTHORIZED)
    (ok (map-set design-milestones
      { design-id: design-id, milestone-id: milestone-id }
      (merge milestone { completed: true, completed-at: stacks-block-height })
    ))
  )
)

(define-public (update-design-stage (design-id uint) (new-stage (string-ascii 30)))
  (let ((design (unwrap! (map-get? chip-designs { design-id: design-id }) ERR-DESIGN-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get designer design)) ERR-NOT-AUTHORIZED)
    (ok (map-set chip-designs
      { design-id: design-id }
      (merge design { design-stage: new-stage })
    ))
  )
)

(define-read-only (get-design-info (design-id uint))
  (map-get? chip-designs { design-id: design-id })
)

(define-read-only (get-milestone-info (design-id uint) (milestone-id uint))
  (map-get? design-milestones { design-id: design-id, milestone-id: milestone-id })
)

(define-public (update-transistor-count (design-id uint) (new-count uint))
  (let ((design (unwrap! (map-get? chip-designs { design-id: design-id }) ERR-DESIGN-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get designer design)) ERR-NOT-AUTHORIZED)
    (ok (map-set chip-designs
      { design-id: design-id }
      (merge design { transistor-count: new-count })
    ))
  )
)
