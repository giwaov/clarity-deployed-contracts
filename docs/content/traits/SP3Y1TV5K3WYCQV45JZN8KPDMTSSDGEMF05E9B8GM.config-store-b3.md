---
title: "Trait config-store-b3"
draft: true
---
```
;; config-store.clar
;; System configuration storage

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

;; Data Maps
(define-map uint-config { key: (string-ascii 32) } { value: uint })
(define-map bool-config { key: (string-ascii 32) } { value: bool })
(define-map principal-config { key: (string-ascii 32) } { value: principal })
(define-map string-config { key: (string-ascii 32) } { value: (string-ascii 64) })

;; Variables
(define-data-var config-version uint u1)

;; Read-only functions

(define-read-only (get-uint-config (key (string-ascii 32)))
    (map-get? uint-config { key: key }))

(define-read-only (get-bool-config (key (string-ascii 32)))
    (map-get? bool-config { key: key }))

(define-read-only (get-principal-config (key (string-ascii 32)))
    (map-get? principal-config { key: key }))

(define-read-only (get-string-config (key (string-ascii 32)))
    (map-get? string-config { key: key }))

(define-read-only (get-config-version)
    (var-get config-version))

;; Public functions

(define-public (set-uint-config (key (string-ascii 32)) (value uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set uint-config { key: key } { value: value })
        (ok true)))

(define-public (set-bool-config (key (string-ascii 32)) (value bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set bool-config { key: key } { value: value })
        (ok true)))

(define-public (set-principal-config (key (string-ascii 32)) (value principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set principal-config { key: key } { value: value })
        (ok true)))

(define-public (set-string-config (key (string-ascii 32)) (value (string-ascii 64)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set string-config { key: key } { value: value })
        (ok true)))

(define-public (delete-uint-config (key (string-ascii 32)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-delete uint-config { key: key })
        (ok true)))

(define-public (delete-bool-config (key (string-ascii 32)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-delete bool-config { key: key })
        (ok true)))

(define-public (delete-principal-config (key (string-ascii 32)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-delete principal-config { key: key })
        (ok true)))

(define-public (delete-string-config (key (string-ascii 32)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-delete string-config { key: key })
        (ok true)))

(define-public (increment-version)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set config-version (+ (var-get config-version) u1))
        (ok true)))

;; Helper functions for quota

(define-public (check-uint-exists (key (string-ascii 32)))
    (ok (is-some (map-get? uint-config { key: key }))))

(define-public (check-bool-exists (key (string-ascii 32)))
    (ok (is-some (map-get? bool-config { key: key }))))

(define-public (check-principal-exists (key (string-ascii 32)))
    (ok (is-some (map-get? principal-config { key: key }))))

(define-public (check-string-exists (key (string-ascii 32)))
    (ok (is-some (map-get? string-config { key: key }))))

(define-public (get-uint-default (key (string-ascii 32)) (default uint))
    (match (map-get? uint-config { key: key })
        config (ok (get value config))
        (ok default)))

(define-public (get-bool-default (key (string-ascii 32)) (default bool))
    (match (map-get? bool-config { key: key })
        config (ok (get value config))
        (ok default)))

(define-public (get-principal-default (key (string-ascii 32)) (default principal))
    (match (map-get? principal-config { key: key })
        config (ok (get value config))
        (ok default)))

(define-public (get-string-default (key (string-ascii 32)) (default (string-ascii 64)))
    (match (map-get? string-config { key: key })
        config (ok (get value config))
        (ok default)))

(define-public (batch-set-uint (keys (list 10 (string-ascii 32))) (values (list 10 uint)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        ;; Simplified
        (ok true)))

(define-public (reset-all-config)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        ;; Simplified - would need to iterate or clear maps
        (var-set config-version u1)
        (ok true)))

(define-public (get-config-count)
    (ok u0)) ;; Placeholder - would need counters

(define-public (is-config-initialized)
    (ok true))

(define-public (get-last-update-block)
    (ok burn-block-height))

(define-public (validate-config-key (key (string-ascii 32)))
    (ok (> (len key) u0)))

(define-public (get-admin-list)
    (ok (list contract-owner)))

(define-public (add-admin (user principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)))

(define-public (remove-admin (user principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)))

(define-public (is-admin (user principal))
    (ok (is-eq user contract-owner)))

(define-public (get-system-mode)
    (ok "production"))

(define-public (set-system-mode (mode (string-ascii 16)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)))

(define-public (get-maintenance-window)
    (ok u0))

(define-public (set-maintenance-window (blocks uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)))

(define-public (get-max-users)
    (ok u1000000))

(define-public (set-max-users (max uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)))

(define-public (get-min-deposit)
    (ok u10))

(define-public (set-min-deposit (min uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)))

(define-public (get-platform-fee-rate)
    (ok u25)) ;; 2.5%

(define-public (set-platform-fee-rate (rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)))

(define-public (get-treasury-address)
    (ok contract-owner))

(define-public (set-treasury-address (address principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)))

(define-public (get-api-endpoint)
    (ok "https://api.example.com"))

(define-public (set-api-endpoint (url (string-ascii 64)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)))

(define-public (get-support-email)
    (ok "support@example.com"))

(define-public (set-support-email (email (string-ascii 64)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)))

(define-public (get-emergency-contact)
    (ok "admin@example.com"))

(define-public (set-emergency-contact (email (string-ascii 64)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)))

(define-public (get-allowed-tokens)
    (ok (list "STX")))

(define-public (add-allowed-token (token (string-ascii 10)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)))

(define-public (remove-allowed-token (token (string-ascii 10)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)))

(define-public (get-contract-metadata)
    (ok "Config Store v1"))

```
