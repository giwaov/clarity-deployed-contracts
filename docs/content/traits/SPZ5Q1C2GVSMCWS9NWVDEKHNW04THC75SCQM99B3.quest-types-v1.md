---
title: "Trait quest-types-v1"
draft: true
---
```
;; title: quest-types
;; summary: Registry of quest categories with simple admin controls
;; version: 1

(impl-trait .quest-types-trait-v1.quest-types-trait)

;; constants
(define-constant err-not-owner (err u100))
(define-constant err-name-required (err u101))
(define-constant err-type-not-found (err u102))

;; data vars
(define-data-var contract-admin principal tx-sender)
(define-data-var next-type-id uint u1)

;; data maps
;; id -> { name, description, active }
(define-map quest-types
  { id: uint }
  {
    name: (string-utf8 64),
    description: (optional (string-utf8 256)),
    active: bool
  })

;; private helpers
(define-private (is-owner (who principal))
  (is-eq who (var-get contract-admin)))

(define-private (assert-owner (who principal))
  (is-owner who))

(define-private (type-exists? (id uint))
  (is-some (map-get? quest-types { id: id })))

(define-private (fetch-type-or-err (id uint))
  (match (map-get? quest-types { id: id })
    entry (ok entry)
    err-type-not-found))

;; public functions

;; admin: set a new contract admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (assert-owner tx-sender) err-not-owner)
    (var-set contract-admin new-admin)
    (print { event: "set-admin", admin: new-admin })
    (ok true)))

;; admin: create a new quest type
(define-public (create-type (name (string-utf8 64)) (description (optional (string-utf8 256))))
  (begin
    (asserts! (assert-owner tx-sender) err-not-owner)
    (asserts! (> (len name) u0) err-name-required)
    (let ((id (var-get next-type-id)))
      (map-set quest-types { id: id } { name: name, description: description, active: true })
      (var-set next-type-id (+ id u1))
      (print { event: "create-type", id: id, name: name })
      (ok id))))

;; admin: toggle type active flag
(define-public (set-type-active (id uint) (flag bool))
  (begin
    (asserts! (assert-owner tx-sender) err-not-owner)
    (asserts! (type-exists? id) err-type-not-found)
    (let ((entry (unwrap! (fetch-type-or-err id) err-type-not-found)))
      (map-set quest-types { id: id }
        {
          name: (get name entry),
          description: (get description entry),
          active: flag
        }))
    (print { event: "set-type-active", id: id, active: flag })
    (ok flag)))

;; read only functions

;; get a type by id
(define-read-only (get-type (id uint))
  (fetch-type-or-err id))

;; check if a type is active
(define-read-only (is-type-active (id uint))
  (match (fetch-type-or-err id)
    entry (ok (get active entry))
    err err-type-not-found))

;; get the next type id that will be assigned
(define-read-only (get-next-type-id)
  (ok (var-get next-type-id)))

```
