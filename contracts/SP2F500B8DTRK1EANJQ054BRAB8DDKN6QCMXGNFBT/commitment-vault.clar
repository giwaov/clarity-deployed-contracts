;; Commitment Vault - Clarity 3 (Sandbox Safe)

;; -------------------------------
;; Errors
;; -------------------------------

(define-constant err-not-found (err u100))
(define-constant err-not-owner (err u101))
(define-constant err-not-partner (err u102))
(define-constant err-too-early (err u103))
(define-constant err-already-resolved (err u104))

;; -------------------------------
;; Constants
;; -------------------------------

(define-constant MIN-LOCK u20) ;; burn blocks

;; -------------------------------
;; Storage
;; -------------------------------

(define-map commitments
  uint
  {
    owner: principal,
    partner: principal,
    created-at: uint,
    resolved: bool
  }
)

(define-data-var next-id uint u0)

;; -------------------------------
;; Public Functions
;; -------------------------------

(define-public (create (partner principal))
  (let ((id (var-get next-id)))
    (begin
      (map-set commitments id {
        owner: tx-sender,
        partner: partner,
        created-at: burn-block-height,
        resolved: false
      })
      (var-set next-id (+ id u1))
      (ok id)
    )
  )
)

(define-public (resolve-by-owner (id uint))
  (match (map-get? commitments id)
    commitment
      (if (not (is-eq tx-sender (get owner commitment)))
          err-not-owner
          (if (get resolved commitment)
              err-already-resolved
              (if (< (- burn-block-height (get created-at commitment)) MIN-LOCK)
                  err-too-early
                  (begin
                    (map-set commitments id {
                      owner: (get owner commitment),
                      partner: (get partner commitment),
                      created-at: (get created-at commitment),
                      resolved: true
                    })
                    (ok true)
                  )
              )
          )
      )
    err-not-found
  )
)

(define-public (resolve-by-partner (id uint))
  (match (map-get? commitments id)
    commitment
      (if (not (is-eq tx-sender (get partner commitment)))
          err-not-partner
          (if (get resolved commitment)
              err-already-resolved
              (begin
                (map-set commitments id {
                  owner: (get owner commitment),
                  partner: (get partner commitment),
                  created-at: (get created-at commitment),
                  resolved: true
                })
                (ok true)
              )
          )
      )
    err-not-found
  )
)

;; -------------------------------
;; Read-only Functions
;; -------------------------------

(define-read-only (get-commitment (id uint))
  (map-get? commitments id)
)

(define-read-only (time-left (id uint))
  (match (map-get? commitments id)
    commitment
      (let ((elapsed (- burn-block-height (get created-at commitment))))
        (if (>= elapsed MIN-LOCK)
            u0
            (- MIN-LOCK elapsed)
        )
      )
    u0
  )
)
