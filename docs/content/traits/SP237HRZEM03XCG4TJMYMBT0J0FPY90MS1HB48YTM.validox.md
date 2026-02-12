---
title: "Trait validox"
draft: true
---
```
;; title: validox
;; version: 1.0.0
;; summary: Decentralized Identity Management System
;; description: A comprehensive on-chain identity solution enabling self-sovereign identities,
;; verifiable credentials, and third-party attestations on the Stacks blockchain.

;; traits
;;

;; token definitions
;;

;; constants
;;

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-EXPIRED (err u103))
(define-constant ERR-REVOKED (err u104))
(define-constant ERR-INVALID-PARAMS (err u105))
(define-constant ERR-IDENTITY-INACTIVE (err u106))

;; Maximum lengths
(define-constant MAX-DID-LENGTH u256)
(define-constant MAX-METADATA-LENGTH u512)
(define-constant MAX-CREDENTIAL-TYPE-LENGTH u128)

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; data vars
;;

;; Global counters for unique IDs
(define-data-var credential-counter uint u0)
(define-data-var attestation-counter uint u0)

;; General purpose counter for utility functions
(define-data-var general-counter uint u0)

;; data maps
;;

;; Identity storage: maps principal to identity data
(define-map identities
    principal
    {
        did: (string-utf8 256),
        metadata: (string-utf8 512),
        registered-at: uint,
        is-active: bool
    }
)

;; Credential storage: maps credential ID to credential data
(define-map credentials
    uint
    {
        issuer: principal,
        subject: principal,
        credential-type: (string-utf8 128),
        credential-hash: (buff 32),
        issued-at: uint,
        expiration: uint,
        is-revoked: bool
    }
)

;; Attestation storage: maps attestation ID to attestation data
(define-map attestations
    uint
    {
        credential-id: uint,
        attestor: principal,
        attestation-hash: (buff 32),
        attested-at: uint,
        is-revoked: bool
    }
)

;; Track credentials by subject for easy lookup
(define-map subject-credentials
    { subject: principal, index: uint }
    uint
)

;; Track credential count per subject
(define-map subject-credential-count
    principal
    uint
)

;; Track attestations by credential for easy lookup
(define-map credential-attestation-list
    { credential-id: uint, index: uint }
    uint
)

;; Track attestation count per credential
(define-map credential-attestation-count
    uint
    uint
)

;; public functions
;;

;; ============================================
;; IDENTITY MANAGEMENT FUNCTIONS
;; ============================================

;; Register a new decentralized identity
(define-public (register-identity (did (string-utf8 256)) (metadata (string-utf8 512)))
    (let
        (
            (caller tx-sender)
        )
        ;; Check if identity already exists
        (asserts! (is-none (map-get? identities caller)) ERR-ALREADY-EXISTS)
        
        ;; Validate DID length
        (asserts! (> (len did) u0) ERR-INVALID-PARAMS)
        
        ;; Store identity
        (map-set identities caller {
            did: did,
            metadata: metadata,
            registered-at: stacks-block-height,
            is-active: true
        })
        
        ;; Initialize credential count for this subject
        (map-set subject-credential-count caller u0)
        
        ;; Emit event
        (print {
            event: "identity-registered",
            principal: caller,
            did: did,
            stacks-block-height: stacks-block-height
        })
        
        (ok true)
    )
)

;; Update identity metadata (only by owner)
(define-public (update-identity (metadata (string-utf8 512)))
    (let
        (
            (caller tx-sender)
            (identity (unwrap! (map-get? identities caller) ERR-NOT-FOUND))
        )
        ;; Check if identity is active
        (asserts! (get is-active identity) ERR-IDENTITY-INACTIVE)
        
        ;; Update metadata
        (map-set identities caller (merge identity { metadata: metadata }))
        
        ;; Emit event
        (print {
            event: "identity-updated",
            principal: caller,
            stacks-block-height: stacks-block-height
        })
        
        (ok true)
    )
)

;; Deactivate identity (soft delete)
(define-public (deactivate-identity)
    (let
        (
            (caller tx-sender)
            (identity (unwrap! (map-get? identities caller) ERR-NOT-FOUND))
        )
        ;; Update is-active flag
        (map-set identities caller (merge identity { is-active: false }))
        
        ;; Emit event
        (print {
            event: "identity-deactivated",
            principal: caller,
            stacks-block-height: stacks-block-height
        })
        
        (ok true)
    )
)

;; ============================================
;; CREDENTIAL OPERATIONS
;; ============================================

;; Issue a new credential
(define-public (issue-credential 
    (subject principal) 
    (credential-type (string-utf8 128)) 
    (credential-hash (buff 32)) 
    (expiration uint))
    (let
        (
            (issuer tx-sender)
            (new-credential-id (+ (var-get credential-counter) u1))
            (subject-identity (unwrap! (map-get? identities subject) ERR-NOT-FOUND))
            (subject-cred-count (default-to u0 (map-get? subject-credential-count subject)))
        )
        ;; Check if subject identity is active
        (asserts! (get is-active subject-identity) ERR-IDENTITY-INACTIVE)
        
        ;; Validate expiration is in the future
        (asserts! (> expiration stacks-block-height) ERR-INVALID-PARAMS)
        
        ;; Increment credential counter
        (var-set credential-counter new-credential-id)
        
        ;; Store credential
        (map-set credentials new-credential-id {
            issuer: issuer,
            subject: subject,
            credential-type: credential-type,
            credential-hash: credential-hash,
            issued-at: stacks-block-height,
            expiration: expiration,
            is-revoked: false
        })
        
        ;; Add to subject's credential list
        (map-set subject-credentials { subject: subject, index: subject-cred-count } new-credential-id)
        (map-set subject-credential-count subject (+ subject-cred-count u1))
        
        ;; Initialize attestation count for this credential
        (map-set credential-attestation-count new-credential-id u0)
        
        ;; Emit event
        (print {
            event: "credential-issued",
            credential-id: new-credential-id,
            issuer: issuer,
            subject: subject,
            credential-type: credential-type,
            stacks-block-height: stacks-block-height
        })
        
        (ok new-credential-id)
    )
)

;; Revoke a credential (only by issuer)
(define-public (revoke-credential (credential-id uint))
    (let
        (
            (caller tx-sender)
            (credential (unwrap! (map-get? credentials credential-id) ERR-NOT-FOUND))
        )
        ;; Only issuer can revoke
        (asserts! (is-eq caller (get issuer credential)) ERR-UNAUTHORIZED)
        
        ;; Check if already revoked
        (asserts! (not (get is-revoked credential)) ERR-REVOKED)
        
        ;; Update revocation status
        (map-set credentials credential-id (merge credential { is-revoked: true }))
        
        ;; Emit event
        (print {
            event: "credential-revoked",
            credential-id: credential-id,
            issuer: caller,
            stacks-block-height: stacks-block-height
        })
        
        (ok true)
    )
)

;; ============================================
;; ATTESTATION FUNCTIONS
;; ============================================

;; Attest to a credential
(define-public (attest-credential (credential-id uint) (attestation-hash (buff 32)))
    (let
        (
            (attestor tx-sender)
            (new-attestation-id (+ (var-get attestation-counter) u1))
            (credential (unwrap! (map-get? credentials credential-id) ERR-NOT-FOUND))
            (attestor-identity (unwrap! (map-get? identities attestor) ERR-NOT-FOUND))
            (attestation-count (default-to u0 (map-get? credential-attestation-count credential-id)))
        )
        ;; Check if credential is valid (not revoked, not expired)
        (asserts! (not (get is-revoked credential)) ERR-REVOKED)
        (asserts! (> (get expiration credential) stacks-block-height) ERR-EXPIRED)
        
        ;; Check if attestor identity is active
        (asserts! (get is-active attestor-identity) ERR-IDENTITY-INACTIVE)
        
        ;; Increment attestation counter
        (var-set attestation-counter new-attestation-id)
        
        ;; Store attestation
        (map-set attestations new-attestation-id {
            credential-id: credential-id,
            attestor: attestor,
            attestation-hash: attestation-hash,
            attested-at: stacks-block-height,
            is-revoked: false
        })
        
        ;; Add to credential's attestation list
        (map-set credential-attestation-list 
            { credential-id: credential-id, index: attestation-count } 
            new-attestation-id)
        (map-set credential-attestation-count credential-id (+ attestation-count u1))
        
        ;; Emit event
        (print {
            event: "credential-attested",
            attestation-id: new-attestation-id,
            credential-id: credential-id,
            attestor: attestor,
            stacks-block-height: stacks-block-height
        })
        
        (ok new-attestation-id)
    )
)

;; Revoke an attestation (only by attestor)
(define-public (revoke-attestation (attestation-id uint))
    (let
        (
            (caller tx-sender)
            (attestation (unwrap! (map-get? attestations attestation-id) ERR-NOT-FOUND))
        )
        ;; Only attestor can revoke their attestation
        (asserts! (is-eq caller (get attestor attestation)) ERR-UNAUTHORIZED)
        
        ;; Check if already revoked
        (asserts! (not (get is-revoked attestation)) ERR-REVOKED)
        
        ;; Update revocation status
        (map-set attestations attestation-id (merge attestation { is-revoked: true }))
        
        ;; Emit event
        (print {
            event: "attestation-revoked",
            attestation-id: attestation-id,
            attestor: caller,
            stacks-block-height: stacks-block-height
        })
        
        (ok true)
    )
)

;; ============================================
;; COUNTER MANAGEMENT FUNCTIONS
;; ============================================

;; Get current credential counter value
(define-read-only (get-credential-counter)
    (ok (var-get credential-counter))
)

;; Get current attestation counter value
(define-read-only (get-attestation-counter)
    (ok (var-get attestation-counter))
)

;; ============================================
;; GENERAL COUNTER UTILITY FUNCTIONS
;; ============================================

;; Increment the general counter by a specified amount
(define-public (increment-counter (amount uint))
    (let
        (
            (current-value (var-get general-counter))
        )
        ;; Increment counter
        (var-set general-counter (+ current-value amount))
        
        ;; Emit event
        (print {
            event: "counter-incremented",
            previous-value: current-value,
            new-value: (var-get general-counter),
            amount: amount
        })
        
        (ok (var-get general-counter))
    )
)

;; Decrement the general counter by a specified amount
(define-public (decrement-counter (amount uint))
    (let
        (
            (current-value (var-get general-counter))
        )
        ;; Check if we can decrement (prevent underflow)
        (asserts! (>= current-value amount) ERR-INVALID-PARAMS)
        
        ;; Decrement counter
        (var-set general-counter (- current-value amount))
        
        ;; Emit event
        (print {
            event: "counter-decremented",
            previous-value: current-value,
            new-value: (var-get general-counter),
            amount: amount
        })
        
        (ok (var-get general-counter))
    )
)

;; Reset the general counter to zero
(define-public (reset-counter)
    (begin
        (var-set general-counter u0)
        
        ;; Emit event
        (print {
            event: "counter-reset",
            new-value: u0
        })
        
        (ok true)
    )
)

;; Get current general counter value
(define-read-only (get-counter)
    (ok (var-get general-counter))
)

;; read only functions
;;

;; ============================================
;; READ-ONLY VERIFICATION FUNCTIONS
;; ============================================

;; Get identity information
(define-read-only (get-identity (principal-address principal))
    (ok (map-get? identities principal-address))
)

;; Check if identity is active
(define-read-only (is-identity-active (principal-address principal))
    (match (map-get? identities principal-address)
        identity (ok (get is-active identity))
        (ok false)
    )
)

;; Get credential details
(define-read-only (get-credential (credential-id uint))
    (ok (map-get? credentials credential-id))
)

;; Verify credential validity (not revoked and not expired)
(define-read-only (verify-credential (credential-id uint))
    (match (map-get? credentials credential-id)
        credential 
            (ok {
                is-valid: (and 
                    (not (get is-revoked credential))
                    (> (get expiration credential) stacks-block-height)
                ),
                is-revoked: (get is-revoked credential),
                is-expired: (<= (get expiration credential) stacks-block-height)
            })
        ERR-NOT-FOUND
    )
)

;; Get attestation details
(define-read-only (get-attestation (attestation-id uint))
    (ok (map-get? attestations attestation-id))
)

;; Get attestation count for a credential
(define-read-only (get-credential-attestation-count (credential-id uint))
    (ok (default-to u0 (map-get? credential-attestation-count credential-id)))
)

;; Get specific attestation ID for a credential by index
(define-read-only (get-credential-attestation-at-index (credential-id uint) (index uint))
    (ok (map-get? credential-attestation-list { credential-id: credential-id, index: index }))
)

;; Get credential count for a subject
(define-read-only (get-subject-credential-count (subject principal))
    (ok (default-to u0 (map-get? subject-credential-count subject)))
)

;; Get specific credential ID for a subject by index
(define-read-only (get-subject-credential-at-index (subject principal) (index uint))
    (ok (map-get? subject-credentials { subject: subject, index: index }))
)

;; private functions
;;

```
