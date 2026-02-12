---
title: "Trait stx-main-ledge"
draft: true
---
```
;; title: STXMainLedge
;; version:
;; summary:
;; description:

;; Enables transparent tracking of health equipment lifecycle and validations

;; title: health
;; version:
;; summary:
;; description:
(define-trait health-equipment-tracking-trait (
  (register-equipment
    (uint uint)
    (response bool uint)
  )
  (update-equipment-phase
    (uint uint)
    (response bool uint)
  )
  (get-equipment-timeline
    (uint)
    (
      response       (list 10 {
      phase: uint,
      timestamp: uint,
    })
      uint
    )
  )
  (add-validation
    (uint uint principal)
    (response bool uint)
  )
  (verify-validation
    (uint uint)
    (response bool uint)
  )
))

;; traits
;;
;; Define equipment phase constants
(define-constant EQUIPMENT_PHASE_PRODUCED u1)
(define-constant EQUIPMENT_PHASE_EVALUATION u2)
(define-constant EQUIPMENT_PHASE_ACTIVE u3)
(define-constant EQUIPMENT_PHASE_SERVICED u4)

;; token definitions
;;
;; Define validation type constants
(define-constant VALIDATION_TYPE_FDA u1)
(define-constant VALIDATION_TYPE_CE u2)
(define-constant VALIDATION_TYPE_ISO u3)
(define-constant VALIDATION_TYPE_SAFETY u4)

;; constants
;;
;; Error constants
(define-constant ERR_UNAUTHORIZED (err u1))
(define-constant ERR_INVALID_EQUIPMENT (err u2))
(define-constant ERR_PHASE_UPDATE_FAILED (err u3))
(define-constant ERR_INVALID_PHASE (err u4))
(define-constant ERR_INVALID_VALIDATION (err u5))
(define-constant ERR_VALIDATION_EXISTS (err u6))

;; data vars
;;
;; Contract owner
(define-data-var admin-principal principal tx-sender)

;; data maps
;;
;; Current timestamp counter
(define-data-var time-sequence uint u0)

;; public functions
;;
;; Equipment tracking map
(define-map equipment-data
  { equipment-id: uint }
  {
    owner: principal,
    current-phase: uint,
    timeline: (list 10 {
      phase: uint,
      timestamp: uint,
    }),
  }
)

;; read only functions
;;
;; Validation tracking map
(define-map equipment-validations
  {
    equipment-id: uint,
    validation-type: uint,
  }
  {
    validator: principal,
    timestamp: uint,
    active: bool,
  }
)

;; private functions
;;
;; Approved regulatory authorities
(define-map regulatory-authorities
  {
    authority: principal,
    validation-type: uint,
  }
  { approved: bool }
)

;; Get current timestamp and increment counter
(define-private (get-current-time)
  (begin
    (var-set time-sequence (+ (var-get time-sequence) u1))
    (var-get time-sequence)
  )
)

;; Only contract admin can perform certain actions
(define-read-only (is-admin (sender principal))
  (is-eq sender (var-get admin-principal))
)

;; Validate phase
(define-private (is-valid-phase (phase uint))
  (or
    (is-eq phase EQUIPMENT_PHASE_PRODUCED)
    (is-eq phase EQUIPMENT_PHASE_EVALUATION)
    (is-eq phase EQUIPMENT_PHASE_ACTIVE)
    (is-eq phase EQUIPMENT_PHASE_SERVICED)
  )
)

;; Validate validation type
(define-private (is-valid-validation-type (validation-type uint))
  (or
    (is-eq validation-type VALIDATION_TYPE_FDA)
    (is-eq validation-type VALIDATION_TYPE_CE)
    (is-eq validation-type VALIDATION_TYPE_ISO)
    (is-eq validation-type VALIDATION_TYPE_SAFETY)
  )
)

;; Validate equipment ID
(define-private (is-valid-equipment-id (equipment-id uint))
  (and (> equipment-id u0) (<= equipment-id u1000000))
)

;; Check if sender is approved regulatory authority
(define-private (is-regulatory-authority
    (authority principal)
    (validation-type uint)
  )
  (default-to false
    (get approved
      (map-get? regulatory-authorities {
        authority: authority,
        validation-type: validation-type,
      })
    ))
)

;; Register a new equipment
(define-public (register-equipment
    (equipment-id uint)
    (initial-phase uint)
  )
  (begin
    (asserts! (is-valid-equipment-id equipment-id) ERR_INVALID_EQUIPMENT)
    (asserts! (is-valid-phase initial-phase) ERR_INVALID_PHASE)
    (asserts!
      (or (is-admin tx-sender) (is-eq initial-phase EQUIPMENT_PHASE_PRODUCED))
      ERR_UNAUTHORIZED
    )

    (map-set equipment-data { equipment-id: equipment-id } {
      owner: tx-sender,
      current-phase: initial-phase,
      timeline: (list {
        phase: initial-phase,
        timestamp: (get-current-time),
      }),
    })
    (ok true)
  )
)

;; Update equipment phase
(define-public (update-equipment-phase
    (equipment-id uint)
    (new-phase uint)
  )
  (let ((equipment (unwrap! (map-get? equipment-data { equipment-id: equipment-id })
      ERR_INVALID_EQUIPMENT
    )))
    (asserts! (is-valid-equipment-id equipment-id) ERR_INVALID_EQUIPMENT)
    (asserts! (is-valid-phase new-phase) ERR_INVALID_PHASE)
    (asserts!
      (or
        (is-admin tx-sender)
        (is-eq (get owner equipment) tx-sender)
      )
      ERR_UNAUTHORIZED
    )

    (map-set equipment-data { equipment-id: equipment-id }
      (merge equipment {
        current-phase: new-phase,
        timeline: (unwrap-panic (as-max-len?
          (append (get timeline equipment) {
            phase: new-phase,
            timestamp: (get-current-time),
          })
          u10
        )),
      })
    )
    (ok true)
  )
)

;; Validate authority principal
(define-private (is-valid-authority (authority principal))
  (and
    (not (is-eq authority (var-get admin-principal))) ;; Authority can't be contract admin
    (not (is-eq authority tx-sender)) ;; Authority can't be the sender
    (not (is-eq authority 'SP000000000000000000002Q6VF78)) ;; Not zero address
  )
)

;; Add regulatory authority with additional validation
(define-public (add-regulatory-authority
    (authority principal)
    (validation-type uint)
  )
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-valid-validation-type validation-type) ERR_INVALID_VALIDATION)
    (asserts! (is-valid-authority authority) ERR_UNAUTHORIZED)

    ;; After validation, we can safely use the authority
    (map-set regulatory-authorities {
      authority: authority,
      validation-type: validation-type,
    } { approved: true }
    )
    (ok true)
  )
)

;; Add validation to equipment
(define-public (add-validation
    (equipment-id uint)
    (validation-type uint)
  )
  (begin
    (asserts! (is-valid-equipment-id equipment-id) ERR_INVALID_EQUIPMENT)
    (asserts! (is-valid-validation-type validation-type) ERR_INVALID_VALIDATION)
    (asserts! (is-regulatory-authority tx-sender validation-type)
      ERR_UNAUTHORIZED
    )

    (asserts!
      (is-none (map-get? equipment-validations {
        equipment-id: equipment-id,
        validation-type: validation-type,
      }))
      ERR_VALIDATION_EXISTS
    )

    (let (
        (validated-equipment-id equipment-id)
        (validated-validation-type validation-type)
      )
      (map-set equipment-validations {
        equipment-id: validated-equipment-id,
        validation-type: validated-validation-type,
      } {
        validator: tx-sender,
        timestamp: (get-current-time),
        active: true,
      })
      (ok true)
    )
  )
)

;; Verify equipment validation
(define-read-only (verify-validation
    (equipment-id uint)
    (validation-type uint)
  )
  (let ((validation (unwrap!
      (map-get? equipment-validations {
        equipment-id: equipment-id,
        validation-type: validation-type,
      })
      ERR_INVALID_VALIDATION
    )))
    (ok (get active validation))
  )
)

;; Revoke validation
(define-public (revoke-validation
    (equipment-id uint)
    (validation-type uint)
  )
  (begin
    (asserts! (is-valid-equipment-id equipment-id) ERR_INVALID_EQUIPMENT)
    (asserts! (is-valid-validation-type validation-type) ERR_INVALID_VALIDATION)

    (let (
        (validation (unwrap!
          (map-get? equipment-validations {
            equipment-id: equipment-id,
            validation-type: validation-type,
          })
          ERR_INVALID_VALIDATION
        ))
        (validated-equipment-id equipment-id)
        (validated-validation-type validation-type)
      )
      (asserts!
        (or
          (is-admin tx-sender)
          (is-eq (get validator validation) tx-sender)
        )
        ERR_UNAUTHORIZED
      )

      (map-set equipment-validations {
        equipment-id: validated-equipment-id,
        validation-type: validated-validation-type,
      }
        (merge validation { active: false })
      )
      (ok true)
    )
  )
)

;; Get equipment timeline
(define-read-only (get-equipment-timeline (equipment-id uint))
  (let ((equipment (unwrap! (map-get? equipment-data { equipment-id: equipment-id })
      ERR_INVALID_EQUIPMENT
    )))
    (ok (get timeline equipment))
  )
)

;; Get current equipment phase
(define-read-only (get-equipment-phase (equipment-id uint))
  (let ((equipment (unwrap! (map-get? equipment-data { equipment-id: equipment-id })
      ERR_INVALID_EQUIPMENT
    )))
    (ok (get current-phase equipment))
  )
)

;; Get validation details
(define-read-only (get-validation-details
    (equipment-id uint)
    (validation-type uint)
  )
  (ok (map-get? equipment-validations {
    equipment-id: equipment-id,
    validation-type: validation-type,
  }))
)

```
