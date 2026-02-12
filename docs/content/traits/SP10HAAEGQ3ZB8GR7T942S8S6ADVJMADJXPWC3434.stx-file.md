---
title: "Trait stx-file"
draft: true
---
```
;; title: stx-file
;; version:
;; summary:
;; description:

;; File sharing smart contract

(define-constant platform-owner tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-FILE-NOT-FOUND (err u101))
(define-constant ERR-UNAUTHORIZED-ACTION (err u102))
(define-constant ERR-INVALID-INPUT (err u103))
(define-constant ERR-FILE-ALREADY-EXISTS (err u104))
(define-constant ERR-STORAGE-LIMIT-EXCEEDED (err u105))

;; Storage Constants
(define-constant maximum-allowed-file-size u1073741824) ;; 1GB in bytes
(define-constant maximum-files-per-user-limit u100)
(define-constant minimum-file-name-length u1)
(define-constant minimum-description-length u1)

;; Data Maps
(define-map file-registry 
    { file-identifier: uint }
    {
        file-owner: principal,
        file-name: (string-ascii 64),
        file-cryptographic-hash: (string-ascii 64),
        file-byte-size: uint,
        file-upload-timestamp: uint,
        file-last-modified-timestamp: uint,
        file-content-type: (string-ascii 32),
        file-description: (string-ascii 256),
        is-file-private: bool,
        is-file-encrypted: bool,
        file-version-number: uint
    }
)

(define-map file-access-control 
    { file-identifier: uint, accessing-user: principal } 
    { 
        user-can-access: bool,
        user-can-edit: bool,
        access-grant-timestamp: uint,
        access-permission-expiration: (optional uint)
    }
)

(define-map user-storage-metrics
    { storage-user: principal }
    {
        total-user-files: uint,
        total-user-storage-consumed: uint,
        last-user-upload-timestamp: uint
    }
)

(define-map file-version-tracking
    { file-identifier: uint, version-identifier: uint }
    {
        version-file-hash: (string-ascii 64),
        version-file-size: uint,
        version-modified-by: principal,
        version-modification-timestamp: uint,
        version-change-description: (string-ascii 256)
    }
)

(define-map file-tag-index
    { file-identifier: uint }
    { tag-collection: (list 10 (string-ascii 32)) }
)

(define-data-var next-file-identifier uint u0)

;; Private Functions
(define-private (is-current-file-owner (file-identifier uint))
    (match (map-get? file-registry { file-identifier: file-identifier })
        file-record (is-eq (get file-owner file-record) tx-sender)
        false
    )
)

(define-private (validate-file-identifier (file-identifier uint))
    (match (map-get? file-registry { file-identifier: file-identifier })
        file-record (ok true)
        ERR-FILE-NOT-FOUND
    )
)

(define-private (validate-user-principal (user-principal principal))
    (if (is-eq user-principal platform-owner)
        ERR-INVALID-INPUT
        (ok true)
    )
)

(define-private (validate-file-name-length (file-name (string-ascii 64)))
    (if (>= (len file-name) minimum-file-name-length)
        (ok true)
        ERR-INVALID-INPUT
    )
)

(define-private (validate-file-description-length (description (string-ascii 256)))
    (if (>= (len description) minimum-description-length)
        (ok true)
        ERR-INVALID-INPUT
    )
)

(define-private (validate-access-expiration (expiration-timestamp (optional uint)))
    (match expiration-timestamp
        timestamp (if (> timestamp stacks-block-height)
            (ok true)
            ERR-INVALID-INPUT)
        (ok true)
    )
)

(define-private (check-file-access-permission (file-identifier uint) (requesting-user principal))
    (match (map-get? file-registry { file-identifier: file-identifier })
        file-record 
            (let ((access-entry (map-get? file-access-control { file-identifier: file-identifier, accessing-user: requesting-user })))
                (or 
                    (is-eq (get file-owner file-record) requesting-user)
                    (not (get is-file-private file-record))
                    (match access-entry
                        permission (and 
                            (get user-can-access permission)
                            (match (get access-permission-expiration permission)
                                expiration-time (> expiration-time stacks-block-height)
                                true
                            )
                        )
                        false
                    )
                )
            )
        false
    )
)

(define-private (check-file-edit-permission (file-identifier uint) (requesting-user principal))
    (match (map-get? file-access-control { file-identifier: file-identifier, accessing-user: requesting-user })
        permission (and
            (get user-can-edit permission)
            (match (get access-permission-expiration permission)
                expiration-time (> expiration-time stacks-block-height)
                true
            )
        )
        false
    )
)

(define-private (update-user-storage-metrics (user-principal principal) (storage-size-change int))
    (let (
        (current-storage-metrics (default-to 
            { total-user-files: u0, total-user-storage-consumed: u0, last-user-upload-timestamp: u0 }
            (map-get? user-storage-metrics { storage-user: user-principal })
        ))
        (new-total-files (+ (get total-user-files current-storage-metrics) u1))
        (new-storage-consumed (+ (get total-user-storage-consumed current-storage-metrics) 
            (if (> storage-size-change 0) 
                (to-uint storage-size-change) 
                (if (>= (get total-user-storage-consumed current-storage-metrics) (to-uint (if (< storage-size-change 0) (- 0 storage-size-change) storage-size-change)))
                    (to-uint (if (< storage-size-change 0) (- 0 storage-size-change) storage-size-change))
                    u0
                )
            )))
    )
        (map-set user-storage-metrics
            { storage-user: user-principal }
            {
                total-user-files: new-total-files,
                total-user-storage-consumed: new-storage-consumed,
                last-user-upload-timestamp: stacks-block-height
            }
        )
    )
)

;; Public Functions
(define-public (upload-new-file 
    (file-name (string-ascii 64)) 
    (file-cryptographic-hash (string-ascii 64)) 
    (file-byte-size uint)
    (file-content-type (string-ascii 32))
    (file-description (string-ascii 256))
    (is-file-private bool)
    (is-file-encrypted bool)
    (file-tags (list 10 (string-ascii 32)))
)
    (let (
        (new-file-identifier (+ (var-get next-file-identifier) u1))
        (user-storage-info (default-to 
            { total-user-files: u0, total-user-storage-consumed: u0, last-user-upload-timestamp: u0 }
            (map-get? user-storage-metrics { storage-user: tx-sender })
        ))
    )
        ;; Input validation
        (try! (validate-file-name-length file-name))
        (try! (validate-file-description-length file-description))
        (asserts! (<= file-byte-size maximum-allowed-file-size) ERR-INVALID-INPUT)
        (asserts! (< (get total-user-files user-storage-info) maximum-files-per-user-limit) ERR-STORAGE-LIMIT-EXCEEDED)

        (var-set next-file-identifier new-file-identifier)
        (map-set file-registry
            { file-identifier: new-file-identifier }
            {
                file-owner: tx-sender,
                file-name: file-name,
                file-cryptographic-hash: file-cryptographic-hash,
                file-byte-size: file-byte-size,
                file-upload-timestamp: stacks-block-height,
                file-last-modified-timestamp: stacks-block-height,
                file-content-type: file-content-type,
                file-description: file-description,
                is-file-private: is-file-private,
                is-file-encrypted: is-file-encrypted,
                file-version-number: u1
            }
        )

        (map-set file-tag-index { file-identifier: new-file-identifier } { tag-collection: file-tags })
        (map-set file-version-tracking
            { file-identifier: new-file-identifier, version-identifier: u1 }
            {
                version-file-hash: file-cryptographic-hash,
                version-file-size: file-byte-size,
                version-modified-by: tx-sender,
                version-modification-timestamp: stacks-block-height,
                version-change-description: "Initial upload"
            }
        )

        (update-user-storage-metrics tx-sender (to-int file-byte-size))
        (ok new-file-identifier)
    )
)

```
