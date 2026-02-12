(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-AIRCRAFT-NOT-FOUND (err u101))
(define-constant ERR-STAGE-NOT-FOUND (err u102))

(define-map aircraft-production
  { aircraft-id: uint }
  {
    model: (string-ascii 50),
    serial-number: (string-ascii 30),
    customer: principal,
    assembly-stage: (string-ascii 30),
    started-at: uint,
    estimated-completion: uint,
    actual-completion: uint,
    status: (string-ascii 20),
    manufacturer: principal
  }
)

(define-map assembly-stages
  { aircraft-id: uint, stage-id: uint }
  {
    stage-name: (string-ascii 50),
    description: (string-ascii 200),
    started-at: uint,
    completed-at: uint,
    quality-check: bool,
    completed: bool
  }
)

(define-data-var aircraft-nonce uint u0)

(define-public (start-assembly
  (model (string-ascii 50))
  (serial-number (string-ascii 30))
  (customer principal)
  (estimated-completion uint)
)
  (let ((aircraft-id (var-get aircraft-nonce)))
    (map-set aircraft-production
      { aircraft-id: aircraft-id }
      {
        model: model,
        serial-number: serial-number,
        customer: customer,
        assembly-stage: "fuselage",
        started-at: stacks-block-height,
        estimated-completion: estimated-completion,
        actual-completion: u0,
        status: "in-assembly",
        manufacturer: tx-sender
      }
    )
    (var-set aircraft-nonce (+ aircraft-id u1))
    (ok aircraft-id)
  )
)

(define-public (add-assembly-stage
  (aircraft-id uint)
  (stage-id uint)
  (stage-name (string-ascii 50))
  (description (string-ascii 200))
)
  (let ((aircraft (unwrap! (map-get? aircraft-production { aircraft-id: aircraft-id }) ERR-AIRCRAFT-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get manufacturer aircraft)) ERR-NOT-AUTHORIZED)
    (ok (map-set assembly-stages
      { aircraft-id: aircraft-id, stage-id: stage-id }
      {
        stage-name: stage-name,
        description: description,
        started-at: u0,
        completed-at: u0,
        quality-check: false,
        completed: false
      }
    ))
  )
)

(define-public (complete-stage (aircraft-id uint) (stage-id uint) (quality-passed bool))
  (let (
    (aircraft (unwrap! (map-get? aircraft-production { aircraft-id: aircraft-id }) ERR-AIRCRAFT-NOT-FOUND))
    (stage (unwrap! (map-get? assembly-stages { aircraft-id: aircraft-id, stage-id: stage-id }) ERR-STAGE-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get manufacturer aircraft)) ERR-NOT-AUTHORIZED)
    (ok (map-set assembly-stages
      { aircraft-id: aircraft-id, stage-id: stage-id }
      (merge stage {
        completed: true,
        completed-at: stacks-block-height,
        quality-check: quality-passed
      })
    ))
  )
)

(define-public (update-assembly-stage (aircraft-id uint) (new-stage (string-ascii 30)))
  (let ((aircraft (unwrap! (map-get? aircraft-production { aircraft-id: aircraft-id }) ERR-AIRCRAFT-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get manufacturer aircraft)) ERR-NOT-AUTHORIZED)
    (ok (map-set aircraft-production
      { aircraft-id: aircraft-id }
      (merge aircraft { assembly-stage: new-stage })
    ))
  )
)

(define-public (complete-assembly (aircraft-id uint))
  (let ((aircraft (unwrap! (map-get? aircraft-production { aircraft-id: aircraft-id }) ERR-AIRCRAFT-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get manufacturer aircraft)) ERR-NOT-AUTHORIZED)
    (ok (map-set aircraft-production
      { aircraft-id: aircraft-id }
      (merge aircraft {
        status: "completed",
        actual-completion: stacks-block-height
      })
    ))
  )
)

(define-read-only (get-aircraft-info (aircraft-id uint))
  (map-get? aircraft-production { aircraft-id: aircraft-id })
)

(define-read-only (get-stage-info (aircraft-id uint) (stage-id uint))
  (map-get? assembly-stages { aircraft-id: aircraft-id, stage-id: stage-id })
)
