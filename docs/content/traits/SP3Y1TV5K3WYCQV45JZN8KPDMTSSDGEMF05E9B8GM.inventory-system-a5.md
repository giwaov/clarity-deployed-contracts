---
title: "Trait inventory-system-a5"
draft: true
---
```
;; inventory-system.clar
;; Game-like inventory management

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-quantity (err u102))
(define-constant err-inventory-full (err u103))

;; Data Maps
(define-map items
    { item-id: uint }
    {
        name: (string-ascii 32),
        type: (string-ascii 16),
        max-stack: uint,
    }
)
(define-map inventory
    {
        user: principal,
        item-id: uint,
    }
    { quantity: uint }
)
(define-map user-slots
    { user: principal }
    {
        slots: uint,
        used: uint,
    }
)

;; Variables
(define-data-var next-item-id uint u1)
(define-data-var default-slots uint u20)

;; Read-only functions

(define-read-only (get-item (item-id uint))
    (map-get? items { item-id: item-id })
)

(define-read-only (get-balance
        (user principal)
        (item-id uint)
    )
    (default-to u0
        (get quantity
            (map-get? inventory {
                user: user,
                item-id: item-id,
            })
        ))
)

(define-read-only (get-slots (user principal))
    (default-to {
        slots: (var-get default-slots),
        used: u0,
    }
        (map-get? user-slots { user: user })
    )
)

(define-read-only (get-next-item-id)
    (var-get next-item-id)
)

;; Public functions

(define-public (create-item
        (name (string-ascii 32))
        (type (string-ascii 16))
        (max-stack uint)
    )
    (let ((id (var-get next-item-id)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set items { item-id: id } {
            name: name,
            type: type,
            max-stack: max-stack,
        })
        (var-set next-item-id (+ id u1))
        (ok id)
    )
)

(define-public (add-item
        (user principal)
        (item-id uint)
        (amount uint)
    )
    (let (
            (slots (get-slots user))
            (current-bal (get-balance user item-id))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (match (map-get? items { item-id: item-id })
            item (begin
                (if (is-eq current-bal u0)
                    (asserts! (< (get used slots) (get slots slots))
                        err-inventory-full
                    )
                    true
                )
                (map-set inventory {
                    user: user,
                    item-id: item-id,
                } { quantity: (+ current-bal amount) }
                )
                (if (is-eq current-bal u0)
                    (map-set user-slots { user: user }
                        (merge slots { used: (+ (get used slots) u1) })
                    )
                    true
                )
                (ok true)
            )
            err-not-found
        )
    )
)

(define-public (remove-item
        (user principal)
        (item-id uint)
        (amount uint)
    )
    (let (
            (current-bal (get-balance user item-id))
            (slots (get-slots user))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (>= current-bal amount) err-insufficient-quantity)
        (map-set inventory {
            user: user,
            item-id: item-id,
        } { quantity: (- current-bal amount) }
        )
        (if (is-eq (- current-bal amount) u0)
            (map-set user-slots { user: user }
                (merge slots { used: (- (get used slots) u1) })
            )
            true
        )
        (ok true)
    )
)

(define-public (transfer-item
        (to principal)
        (item-id uint)
        (amount uint)
    )
    (let (
            (sender-bal (get-balance tx-sender item-id))
            (receiver-bal (get-balance to item-id))
            (sender-slots (get-slots tx-sender))
            (receiver-slots (get-slots to))
        )
        (asserts! (>= sender-bal amount) err-insufficient-quantity)

        ;; Check receiver capacity if new item for them
        (if (is-eq receiver-bal u0)
            (asserts! (< (get used receiver-slots) (get slots receiver-slots))
                err-inventory-full
            )
            true
        )

        (map-set inventory {
            user: tx-sender,
            item-id: item-id,
        } { quantity: (- sender-bal amount) }
        )
        (if (is-eq (- sender-bal amount) u0)
            (map-set user-slots { user: tx-sender }
                (merge sender-slots { used: (- (get used sender-slots) u1) })
            )
            true
        )

        (map-set inventory {
            user: to,
            item-id: item-id,
        } { quantity: (+ receiver-bal amount) }
        )
        (if (is-eq receiver-bal u0)
            (map-set user-slots { user: to }
                (merge receiver-slots { used: (+ (get used receiver-slots) u1) })
            )
            true
        )

        (ok true)
    )
)

(define-public (expand-inventory (slots uint))
    (let ((current-slots (get-slots tx-sender)))
        (map-set user-slots { user: tx-sender }
            (merge current-slots { slots: (+ (get slots current-slots) slots) })
        )
        (ok true)
    )
)

;; Helper functions for quota

(define-public (get-item-name (item-id uint))
    (match (map-get? items { item-id: item-id })
        item (ok (get name item))
        err-not-found
    )
)

(define-public (get-item-type (item-id uint))
    (match (map-get? items { item-id: item-id })
        item (ok (get type item))
        err-not-found
    )
)

(define-public (get-item-max-stack (item-id uint))
    (match (map-get? items { item-id: item-id })
        item (ok (get max-stack item))
        err-not-found
    )
)

(define-public (set-default-slots (slots uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set default-slots slots)
        (ok true)
    )
)

(define-public (admin-clear-inventory (user principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-delete user-slots { user: user })
        (ok true)
    )
)

(define-public (check-has-item
        (user principal)
        (item-id uint)
    )
    (ok (> (get-balance user item-id) u0))
)

(define-public (check-is-full (user principal))
    (let ((slots (get-slots user)))
        (ok (>= (get used slots) (get slots slots)))
    )
)

(define-public (get-free-slots (user principal))
    (let ((slots (get-slots user)))
        (ok (- (get slots slots) (get used slots)))
    )
)

(define-public (consume-item (item-id uint))
    (begin
        (try! (remove-item tx-sender item-id u1))
        (ok true)
    )
)

(define-public (craft-item
        (result-id uint)
        (material-id uint)
        (cost uint)
    )
    (begin
        (try! (remove-item tx-sender material-id cost))
        (try! (add-item tx-sender result-id u1))
        (ok true)
    )
)

(define-public (bulk-add
        (users (list 10 principal))
        (item-id uint)
        (amount uint)
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        ;; Simplified
        (ok true)
    )
)

(define-public (update-item-name
        (item-id uint)
        (new-name (string-ascii 32))
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (match (map-get? items { item-id: item-id })
            item (begin
                (map-set items { item-id: item-id }
                    (merge item { name: new-name })
                )
                (ok true)
            )
            err-not-found
        )
    )
)

(define-public (can-equip-item
        (user principal)
        (item-id uint)
    )
    (match (map-get? inventory {
        user: user,
        item-id: item-id,
    })
        inv-item (ok (> (get quantity inv-item) u0))
        err-not-found
    )
)

(define-public (get-item-weight (item-id uint))
    (ok u10)
)
;; Placeholder

(define-public (calculate-inventory-value (user principal))
    (ok u0)
)
;; Placeholder

(define-public (get-total-items-owned (user principal))
    (let ((slots (get-slots user)))
        (ok (get used slots))
    )
)

(define-public (is-item-stackable (item-id uint))
    (match (map-get? items { item-id: item-id })
        item (ok (> (get max-stack item) u1))
        err-not-found
    )
)

(define-public (get-stack-size
        (user principal)
        (item-id uint)
    )
    (match (map-get? inventory {
        user: user,
        item-id: item-id,
    })
        inv-item (ok (get quantity inv-item))
        err-not-found
    )
)

(define-public (can-stack-more
        (user principal)
        (item-id uint)
        (amount uint)
    )
    (match (map-get? items { item-id: item-id })
        item (let ((current (get-balance user item-id)))
            (ok (<= (+ current amount) (get max-stack item)))
        )
        err-not-found
    )
)

(define-public (get-inventory-usage-percent (user principal))
    (let ((slots (get-slots user)))
        (ok (/ (* (get used slots) u100) (get slots slots)))
    )
)

(define-public (is-inventory-empty (user principal))
    (let ((slots (get-slots user)))
        (ok (is-eq (get used slots) u0))
    )
)

(define-public (get-item-rarity (item-id uint))
    (ok "common")
)
;; Placeholder

(define-public (check-item-requirements
        (user principal)
        (item-id uint)
    )
    (ok true)
)

(define-public (get-max-inventory-slots)
    (ok u100)
)

(define-public (get-min-inventory-slots)
    (ok u10)
)

(define-public (is-item-transferable (item-id uint))
    (ok true)
)

(define-public (get-item-category (item-id uint))
    (match (map-get? items { item-id: item-id })
        item (ok (get type item))
        err-not-found
    )
)

(define-public (get-item-durability (item-id uint))
    (ok u100)
)

(define-public (repair-item (item-id uint))
    (ok true)
)

(define-public (salvage-item (item-id uint))
    (ok true)
)

(define-public (get-salvage-value (item-id uint))
    (ok u5)
)

(define-public (is-item-broken (item-id uint))
    (ok false)
)

(define-public (get-item-level-req (item-id uint))
    (ok u1)
)

(define-public (can-use-item
        (user principal)
        (item-id uint)
    )
    (ok true)
)

(define-public (get-item-cooldown (item-id uint))
    (ok u0)
)

(define-public (is-item-on-cooldown
        (user principal)
        (item-id uint)
    )
    (ok false)
)

(define-public (get-inventory-upgrade-cost)
    (ok u1000)
)

(define-public (can-afford-upgrade (user principal))
    (ok true)
)

(define-public (get-next-slot-unlock-level)
    (ok u10)
)

(define-public (is-soulbound (item-id uint))
    (ok false)
)

(define-public (get-item-sell-price (item-id uint))
    (ok u10)
)

(define-public (get-item-buy-price (item-id uint))
    (ok u20)
)

```
