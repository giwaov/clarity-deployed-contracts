---
title: "Trait quest-registry-v2"
draft: true
---
```
;; title: quest-registry
;; summary: Stores quest definitions and rewards for use by quest-progress
;; version: 1

;; constants
(define-constant err-not-owner (err u100))
(define-constant err-name-required (err u101))
(define-constant err-quest-not-found (err u102))
(define-constant err-type-inactive (err u103))
(define-constant err-type-missing (err u104))
(define-constant err-uri-required (err u105))

(use-trait quest-types-trait .quest-types-trait-v2.quest-types-trait)
(impl-trait .quest-registry-trait-v2.quest-registry-trait)

;; data vars
(define-data-var contract-admin principal tx-sender)
(define-data-var next-quest-id uint u1)

;; data maps
;; { id } -> { name, type-id, xp-reward, badge-uri, active }
(define-map quests
  { id: uint }
  {
    name: (string-utf8 64),
    type-id: uint,
    xp-reward: uint,
    badge-uri: (string-utf8 256),
    active: bool
  })

;; private helpers
(define-private (is-owner (who principal))
  (is-eq who (var-get contract-admin)))

(define-private (quest-exists? (id uint))
  (is-some (map-get? quests { id: id })))

(define-private (fetch-quest-or-err (id uint))
  (match (map-get? quests { id: id })
    entry (ok entry)
    err-quest-not-found))

;; public functions

;; admin: set a new contract admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-owner tx-sender) err-not-owner)
    (var-set contract-admin new-admin)
    (print { event: "set-admin", admin: new-admin })
    (ok true)))

;; admin: create a quest definition
(define-public (create-quest (name (string-utf8 64)) (type-id uint) (xp-reward uint) (badge-uri (string-utf8 256)))
  (begin
    (asserts! (is-owner tx-sender) err-not-owner)
    (asserts! (> (len name) u0) err-name-required)
    (asserts! (> (len badge-uri) u0) err-uri-required)
    (let ((type-entry (unwrap! (contract-call? .quest-types-v2 get-type type-id) err-type-missing)))
      (asserts! (get active type-entry) err-type-inactive))
    (let ((id (var-get next-quest-id)))
      (map-set quests { id: id }
        { name: name, type-id: type-id, xp-reward: xp-reward, badge-uri: badge-uri, active: true })
      (var-set next-quest-id (+ id u1))
      (print { event: "create-quest", id: id, type: type-id, xp: xp-reward })
      (ok id))))

;; admin: toggle quest active flag
(define-public (set-quest-active (id uint) (flag bool))
  (begin
    (asserts! (is-owner tx-sender) err-not-owner)
    (asserts! (quest-exists? id) err-quest-not-found)
    (let ((entry (unwrap! (fetch-quest-or-err id) err-quest-not-found)))
      (map-set quests { id: id }
        {
          name: (get name entry),
          type-id: (get type-id entry),
          xp-reward: (get xp-reward entry),
          badge-uri: (get badge-uri entry),
          active: flag
        }))
    (print { event: "set-quest-active", id: id, active: flag })
    (ok flag)))

;; admin: update XP reward
(define-public (set-quest-xp (id uint) (xp-reward uint))
  (begin
    (asserts! (is-owner tx-sender) err-not-owner)
    (asserts! (quest-exists? id) err-quest-not-found)
    (let ((entry (unwrap! (fetch-quest-or-err id) err-quest-not-found)))
      (map-set quests { id: id }
        {
          name: (get name entry),
          type-id: (get type-id entry),
          xp-reward: xp-reward,
          badge-uri: (get badge-uri entry),
          active: (get active entry)
        }))
    (print { event: "set-quest-xp", id: id, xp: xp-reward })
    (ok xp-reward)))

;; admin: update badge URI
(define-public (set-quest-badge-uri (id uint) (badge-uri (string-utf8 256)))
  (begin
    (asserts! (is-owner tx-sender) err-not-owner)
    (asserts! (> (len badge-uri) u0) err-uri-required)
    (asserts! (quest-exists? id) err-quest-not-found)
    (let ((entry (unwrap! (fetch-quest-or-err id) err-quest-not-found)))
      (map-set quests { id: id }
        {
          name: (get name entry),
          type-id: (get type-id entry),
          xp-reward: (get xp-reward entry),
          badge-uri: badge-uri,
          active: (get active entry)
        }))
    (print { event: "set-quest-badge-uri", id: id })
    (ok true)))

;; read only functions

(define-read-only (get-quest (id uint))
  (fetch-quest-or-err id))

(define-read-only (quest-is-active (id uint))
  (match (fetch-quest-or-err id)
    entry (ok (get active entry))
    err err-quest-not-found))

(define-read-only (get-next-quest-id)
  (ok (var-get next-quest-id)))

```
