(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PLAN-NOT-FOUND (err u101))
(define-constant ERR-DEPLOYMENT-NOT-FOUND (err u102))

(define-map deployment-plans
  { plan-id: uint }
  {
    facility-name: (string-ascii 100),
    robot-type: (string-ascii 50),
    planned-quantity: uint,
    deployment-zone: (string-ascii 50),
    planned-date: uint,
    status: (string-ascii 20),
    planner: principal
  }
)

(define-map robot-deployments
  { plan-id: uint, deployment-id: uint }
  {
    robot-serial: (string-ascii 30),
    installation-date: uint,
    location: (string-ascii 100),
    operational: bool,
    deployed: bool
  }
)

(define-data-var plan-nonce uint u0)

(define-public (create-plan
  (facility (string-ascii 100))
  (robot-type (string-ascii 50))
  (quantity uint)
  (zone (string-ascii 50))
  (planned-date uint)
)
  (let ((plan-id (var-get plan-nonce)))
    (map-set deployment-plans
      { plan-id: plan-id }
      {
        facility-name: facility,
        robot-type: robot-type,
        planned-quantity: quantity,
        deployment-zone: zone,
        planned-date: planned-date,
        status: "planning",
        planner: tx-sender
      }
    )
    (var-set plan-nonce (+ plan-id u1))
    (ok plan-id)
  )
)

(define-public (add-deployment
  (plan-id uint)
  (deployment-id uint)
  (robot-serial (string-ascii 30))
  (location (string-ascii 100))
)
  (let ((plan (unwrap! (map-get? deployment-plans { plan-id: plan-id }) ERR-PLAN-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get planner plan)) ERR-NOT-AUTHORIZED)
    (ok (map-set robot-deployments
      { plan-id: plan-id, deployment-id: deployment-id }
      {
        robot-serial: robot-serial,
        installation-date: u0,
        location: location,
        operational: false,
        deployed: false
      }
    ))
  )
)

(define-public (complete-deployment (plan-id uint) (deployment-id uint))
  (let (
    (plan (unwrap! (map-get? deployment-plans { plan-id: plan-id }) ERR-PLAN-NOT-FOUND))
    (deployment (unwrap! (map-get? robot-deployments { plan-id: plan-id, deployment-id: deployment-id }) ERR-DEPLOYMENT-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get planner plan)) ERR-NOT-AUTHORIZED)
    (ok (map-set robot-deployments
      { plan-id: plan-id, deployment-id: deployment-id }
      (merge deployment { deployed: true, installation-date: stacks-block-height })
    ))
  )
)

(define-public (set-operational (plan-id uint) (deployment-id uint) (status bool))
  (let (
    (plan (unwrap! (map-get? deployment-plans { plan-id: plan-id }) ERR-PLAN-NOT-FOUND))
    (deployment (unwrap! (map-get? robot-deployments { plan-id: plan-id, deployment-id: deployment-id }) ERR-DEPLOYMENT-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get planner plan)) ERR-NOT-AUTHORIZED)
    (ok (map-set robot-deployments
      { plan-id: plan-id, deployment-id: deployment-id }
      (merge deployment { operational: status })
    ))
  )
)

(define-read-only (get-plan-info (plan-id uint))
  (map-get? deployment-plans { plan-id: plan-id })
)

(define-read-only (get-deployment-info (plan-id uint) (deployment-id uint))
  (map-get? robot-deployments { plan-id: plan-id, deployment-id: deployment-id })
)

(define-public (update-plan-status (plan-id uint) (new-status (string-ascii 20)))
  (let ((plan (unwrap! (map-get? deployment-plans { plan-id: plan-id }) ERR-PLAN-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get planner plan)) ERR-NOT-AUTHORIZED)
    (ok (map-set deployment-plans
      { plan-id: plan-id }
      (merge plan { status: new-status })
    ))
  )
)
