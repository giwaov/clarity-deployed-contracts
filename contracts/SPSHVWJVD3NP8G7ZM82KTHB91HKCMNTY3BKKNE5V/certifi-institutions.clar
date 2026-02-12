;; Certifi Institutions Contract
;; Manages institution registration and verification
;; Built on Stacks Blockchain

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-INSTITUTION-NOT-FOUND (err u404))
(define-constant ERR-INSTITUTION-EXISTS (err u409))
(define-constant ERR-INVALID-NAME (err u420))
(define-constant ERR-INVALID-COUNTRY (err u421))
(define-constant ERR-NOT-VERIFIED (err u422))
(define-constant ERR-ALREADY-VERIFIED (err u423))
(define-constant ERR-INVALID-REGISTRATION (err u424))

;; Data structures
(define-map institutions
  { institution-id: uint }
  {
    name: (string-ascii 256),
    country: (string-ascii 128),
    registration-number: (string-ascii 128),
    owner: principal,
    verified: bool,
    verified-at: (optional uint),
    created-at: uint,
    metadata-uri: (string-ascii 512)
  }
)

(define-map institution-by-owner
  { owner: principal }
  uint
)

(define-map verifiers
  { verifier: principal }
  bool
)

(define-data-var institution-counter uint u0)
(define-data-var total-verified uint u0)

;; Register a new institution
(define-public (register-institution 
  (name (string-ascii 256))
  (country (string-ascii 128))
  (registration-number (string-ascii 128))
  (metadata-uri (string-ascii 512)))
  (let ((institution-id (var-get institution-counter)))
    ;; Validation
    (asserts! (> (len name) u0) ERR-INVALID-NAME)
    (asserts! (> (len country) u0) ERR-INVALID-COUNTRY)
    (asserts! (> (len registration-number) u0) ERR-INVALID-REGISTRATION)
    (asserts! (is-none (map-get? institution-by-owner { owner: tx-sender })) ERR-INSTITUTION-EXISTS)

    ;; Create institution
    (map-insert institutions
      { institution-id: institution-id }
      {
        name: name,
        country: country,
        registration-number: registration-number,
        owner: tx-sender,
        verified: false,
        verified-at: none,
        created-at: burn-block-height,
        metadata-uri: metadata-uri
      }
    )

    ;; Map owner to institution
    (map-set institution-by-owner { owner: tx-sender } institution-id)

    ;; Increment counter
    (var-set institution-counter (+ institution-id u1))

    (ok institution-id)
  )
)

;; Add verifier (contract owner only)
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (map-set verifiers { verifier: verifier } true)
    (ok true)
  )
)

;; Remove verifier (contract owner only)
(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (map-set verifiers { verifier: verifier } false)
    (ok true)
  )
)

;; Verify institution (verifier only)
(define-public (verify-institution (institution-id uint))
  (let ((institution (unwrap! (map-get? institutions { institution-id: institution-id }) ERR-INSTITUTION-NOT-FOUND)))
    (asserts! (default-to false (map-get? verifiers { verifier: tx-sender })) ERR-UNAUTHORIZED)
    (asserts! (not (get verified institution)) ERR-ALREADY-VERIFIED)

    ;; Update institution
    (map-set institutions
      { institution-id: institution-id }
      (merge institution { verified: true, verified-at: (some burn-block-height) })
    )

    ;; Increment verified counter
    (var-set total-verified (+ (var-get total-verified) u1))

    (ok true)
  )
)

;; Get institution details
(define-read-only (get-institution (institution-id uint))
  (map-get? institutions { institution-id: institution-id })
)

;; Get institution by owner
(define-read-only (get-institution-by-owner (owner principal))
  (match (map-get? institution-by-owner { owner: owner })
    inst-id (map-get? institutions { institution-id: inst-id })
    none
  )
)

;; Check if institution is verified
(define-read-only (is-institution-verified (institution-id uint))
  (match (map-get? institutions { institution-id: institution-id })
    institution (get verified institution)
    false
  )
)

;; Get total institutions
(define-read-only (get-institution-count)
  (var-get institution-counter)
)

;; Get total verified institutions
(define-read-only (get-verified-count)
  (var-get total-verified)
)

;; Check if principal is verifier
(define-read-only (is-verifier (user principal))
  (default-to false (map-get? verifiers { verifier: user }))
)
