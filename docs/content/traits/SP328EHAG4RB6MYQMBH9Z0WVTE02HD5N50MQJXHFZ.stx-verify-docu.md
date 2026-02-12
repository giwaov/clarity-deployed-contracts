---
title: "Trait stx-verify-docu"
draft: true
---
```
;; title: Stx-VerifyDocu
;; version:
;; summary:
;; description:

;; Document Verification Smart Contract
;; Enhanced version with improved security and validation

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-DUPLICATE-DOCUMENT (err u101))
(define-constant ERR-DOCUMENT-MISSING (err u102))
(define-constant ERR-DOCUMENT-ALREADY-VERIFIED (err u103))
(define-constant ERR-INVALID-DOCUMENT-HASH-ID (err u104))
(define-constant ERR-INVALID-CONTENT-HASH (err u105))
(define-constant ERR-INVALID-METADATA (err u106))
(define-constant ERR-INVALID-AUTHORIZED-USER (err u107))
(define-constant ERR-INVALID-INPUT (err u108))
(define-constant ERR-PERMISSION-DENIED (err u109))

;; Constants for verification status
(define-constant STATUS-PENDING "PENDING")
(define-constant STATUS-VERIFIED "VERIFIED")

;; Define document record type
(define-data-var document-record-type {
  document-owner: principal,
  document-content-hash: (buff 32),
  submission-timestamp: uint,
  verification-status: (string-ascii 20),
  verification-authority: (optional principal),
  document-metadata: (string-utf8 256),
  document-version: uint,
  verification-complete: bool,
} {
  document-owner: tx-sender,
  document-content-hash: 0x0000000000000000000000000000000000000000000000000000000000000000,
  submission-timestamp: u0,
  verification-status: STATUS-PENDING,
  verification-authority: none,
  document-metadata: u"",
  document-version: u0,
  verification-complete: false,
})

;; Data maps
(define-map document-records
  { document-hash-id: (buff 32) }
  {
    document-owner: principal,
    document-content-hash: (buff 32),
    submission-timestamp: uint,
    verification-status: (string-ascii 20),
    verification-authority: (optional principal),
    document-metadata: (string-utf8 256),
    document-version: uint,
    verification-complete: bool,
  }
)

(define-map document-permissions
  {
    document-hash-id: (buff 32),
    authorized-user: principal,
  }
  {
    document-viewing-permission: bool,
    document-verification-permission: bool,
  }
)

;; Input validation functions
(define-private (check-buff-32 (input (buff 32)))
  (if (is-eq (len input) u32)
    (ok input)
    ERR-INVALID-INPUT
  )
)

(define-private (check-string-utf8 (input (string-utf8 256)))
  (if (and
      (<= (len input) u256)
      (> (len input) u0)
    )
    (ok input)
    ERR-INVALID-INPUT
  )
)

(define-private (check-principal (input principal))
  (if (not (is-eq input tx-sender))
    (ok input)
    ERR-INVALID-INPUT
  )
)

;; Enhanced validation functions with consistent response types
(define-private (validate-and-sanitize-hash (hash (buff 32)))
  (check-buff-32 hash)
)

(define-private (validate-and-sanitize-metadata (metadata (string-utf8 256)))
  (check-string-utf8 metadata)
)

(define-private (validate-and-sanitize-user
    (document-owner principal)
    (authorized-user principal)
  )
  (if (not (is-eq document-owner authorized-user))
    (ok authorized-user)
    ERR-INVALID-AUTHORIZED-USER
  )
)

;; Safe getter functions
(define-private (safe-get-document (document-hash-id (buff 32)))
  (ok (unwrap! (map-get? document-records { document-hash-id: document-hash-id })
    ERR-DOCUMENT-MISSING
  ))
)

;; Read-only functions
(define-read-only (get-document-details (document-hash-id (buff 32)))
  (let ((validated-hash-id (try! (validate-and-sanitize-hash document-hash-id))))
    (safe-get-document validated-hash-id)
  )
)

(define-read-only (get-user-permissions
    (document-hash-id (buff 32))
    (authorized-user principal)
  )
  (let (
      (validated-hash-id (try! (validate-and-sanitize-hash document-hash-id)))
      (validated-user (try! (check-principal authorized-user)))
    )
    (ok (default-to {
      document-viewing-permission: false,
      document-verification-permission: false,
    }
      (map-get? document-permissions {
        document-hash-id: validated-hash-id,
        authorized-user: validated-user,
      })
    ))
  )
)

(define-public (modify-existing-document
    (document-hash-id (buff 32))
    (updated-content-hash (buff 32))
    (updated-metadata (string-utf8 256))
  )
  (let (
      (validated-hash-id (unwrap! (validate-and-sanitize-hash document-hash-id)
        ERR-INVALID-DOCUMENT-HASH-ID
      ))
      (validated-content-hash (unwrap! (validate-and-sanitize-hash updated-content-hash)
        ERR-INVALID-CONTENT-HASH
      ))
      (validated-metadata (unwrap! (validate-and-sanitize-metadata updated-metadata)
        ERR-INVALID-METADATA
      ))
      (existing-doc (unwrap! (safe-get-document validated-hash-id) ERR-DOCUMENT-MISSING))
    )
    (asserts! (is-eq (get document-owner existing-doc) tx-sender)
      ERR-UNAUTHORIZED-ACCESS
    )
    (asserts! (not (get verification-complete existing-doc))
      ERR-DOCUMENT-ALREADY-VERIFIED
    )

    (ok (map-set document-records { document-hash-id: validated-hash-id }
      (merge existing-doc {
        document-content-hash: validated-content-hash,
        document-metadata: validated-metadata,
        submission-timestamp: stacks-block-time,
        document-version: (+ (get document-version existing-doc) u1),
        verification-complete: false,
      })
    ))
  )
)

(define-public (perform-document-verification (document-hash-id (buff 32)))
  (let (
      (validated-hash-id (unwrap! (validate-and-sanitize-hash document-hash-id)
        ERR-INVALID-DOCUMENT-HASH-ID
      ))
      (existing-doc (unwrap! (safe-get-document validated-hash-id) ERR-DOCUMENT-MISSING))
      (permissions (unwrap! (get-user-permissions validated-hash-id tx-sender)
        ERR-PERMISSION-DENIED
      ))
    )
    (asserts! (get document-verification-permission permissions)
      ERR-UNAUTHORIZED-ACCESS
    )
    (asserts! (not (get verification-complete existing-doc))
      ERR-DOCUMENT-ALREADY-VERIFIED
    )

    (ok (map-set document-records { document-hash-id: validated-hash-id }
      (merge existing-doc {
        verification-status: STATUS-VERIFIED,
        verification-authority: (some tx-sender),
        verification-complete: true,
      })
    ))
  )
)

;; Public functions
(define-public (register-new-document
    (document-hash-id (buff 32))
    (document-content-hash (buff 32))
    (document-metadata (string-utf8 256))
  )
  (let (
      (document-submitter tx-sender)
      (validated-hash-id (unwrap! (validate-and-sanitize-hash document-hash-id)
        ERR-INVALID-DOCUMENT-HASH-ID
      ))
      (validated-content-hash (unwrap! (validate-and-sanitize-hash document-content-hash)
        ERR-INVALID-CONTENT-HASH
      ))
      (validated-metadata (unwrap! (validate-and-sanitize-metadata document-metadata)
        ERR-INVALID-METADATA
      ))
    )
    ;; Check for duplicate document
    (asserts!
      (is-none (map-get? document-records { document-hash-id: validated-hash-id }))
      ERR-DUPLICATE-DOCUMENT
    )

    (ok (map-set document-records { document-hash-id: validated-hash-id } {
      document-owner: document-submitter,
      document-content-hash: validated-content-hash,
      submission-timestamp: stacks-block-time,
      verification-status: STATUS-PENDING,
      verification-authority: none,
      document-metadata: validated-metadata,
      document-version: u1,
      verification-complete: false,
    }))
  )
)

(define-public (assign-document-permissions
    (document-hash-id (buff 32))
    (authorized-user principal)
    (grant-viewing-permission bool)
    (grant-verification-permission bool)
  )
  (let (
      (validated-hash-id (unwrap! (validate-and-sanitize-hash document-hash-id)
        ERR-INVALID-DOCUMENT-HASH-ID
      ))
      (validated-user (unwrap! (check-principal authorized-user) ERR-INVALID-AUTHORIZED-USER))
      (existing-doc (unwrap! (safe-get-document validated-hash-id) ERR-DOCUMENT-MISSING))
    )
    (asserts! (is-eq (get document-owner existing-doc) tx-sender)
      ERR-UNAUTHORIZED-ACCESS
    )

    (ok (map-set document-permissions {
      document-hash-id: validated-hash-id,
      authorized-user: validated-user,
    } {
      document-viewing-permission: grant-viewing-permission,
      document-verification-permission: grant-verification-permission,
    }))
  )
)

(define-public (remove-document-permissions
    (document-hash-id (buff 32))
    (authorized-user principal)
  )
  (let (
      (validated-hash-id (unwrap! (validate-and-sanitize-hash document-hash-id)
        ERR-INVALID-DOCUMENT-HASH-ID
      ))
      (validated-user (unwrap! (check-principal authorized-user) ERR-INVALID-AUTHORIZED-USER))
      (existing-doc (unwrap! (safe-get-document validated-hash-id) ERR-DOCUMENT-MISSING))
    )
    (asserts! (is-eq (get document-owner existing-doc) tx-sender)
      ERR-UNAUTHORIZED-ACCESS
    )

    (ok (map-delete document-permissions {
      document-hash-id: validated-hash-id,
      authorized-user: validated-user,
    }))
  )
)

```
