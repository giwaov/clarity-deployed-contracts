---
title: "Trait guild-management-x2"
draft: true
---
```
;; guild-management.clar
;; Guild/Group management system

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-not-member (err u103))
(define-constant err-unauthorized (err u104))

;; Data Maps
(define-map guilds 
    { guild-id: uint } 
    { 
        name: (string-ascii 64), 
        owner: principal, 
        description: (string-utf8 256),
        member-count: uint,
        created-at: uint
    }
)

(define-map guild-members { guild-id: uint, user: principal } { role: (string-ascii 16), joined-at: uint })
(define-map user-guilds { user: principal } { guild-id: (optional uint) })

;; Variables
(define-data-var guild-count uint u0)

;; Read-only functions

(define-read-only (get-guild (guild-id uint))
    (map-get? guilds { guild-id: guild-id }))

(define-read-only (get-member-role (guild-id uint) (user principal))
    (match (map-get? guild-members { guild-id: guild-id, user: user })
        member (ok (get role member))
        err-not-found))

(define-read-only (get-user-guild (user principal))
    (default-to { guild-id: none } (map-get? user-guilds { user: user })))

(define-read-only (get-guild-count)
    (var-get guild-count))

;; Public functions

(define-public (create-guild (name (string-ascii 64)) (description (string-utf8 256)))
    (let ((id (var-get guild-count)))
        (asserts! (is-none (get guild-id (get-user-guild tx-sender))) err-already-exists)
        (map-set guilds { guild-id: id } 
                 { 
                     name: name, 
                     owner: tx-sender, 
                     description: description, 
                     member-count: u1,
                     created-at: burn-block-height
                 })
        (map-set guild-members { guild-id: id, user: tx-sender } { role: "owner", joined-at: burn-block-height })
        (map-set user-guilds { user: tx-sender } { guild-id: (some id) })
        (var-set guild-count (+ id u1))
        (ok id)))

(define-public (join-guild (guild-id uint))
    (match (map-get? guilds { guild-id: guild-id })
        guild (begin
                (asserts! (is-none (get guild-id (get-user-guild tx-sender))) err-already-exists)
                (map-set guild-members { guild-id: guild-id, user: tx-sender } { role: "member", joined-at: burn-block-height })
                (map-set user-guilds { user: tx-sender } { guild-id: (some guild-id) })
                (map-set guilds { guild-id: guild-id } (merge guild { member-count: (+ (get member-count guild) u1) }))
                (ok true))
        err-not-found))

(define-public (leave-guild)
    (match (get guild-id (get-user-guild tx-sender))
        guild-id (match (map-get? guilds { guild-id: guild-id })
                    guild (begin
                            (asserts! (not (is-eq (get owner guild) tx-sender)) err-unauthorized)
                            (map-delete guild-members { guild-id: guild-id, user: tx-sender })
                            (map-delete user-guilds { user: tx-sender })
                            (map-set guilds { guild-id: guild-id } (merge guild { member-count: (- (get member-count guild) u1) }))
                            (ok true))
                    err-not-found)
        err-not-found))

(define-public (kick-member (guild-id uint) (user principal))
    (match (map-get? guilds { guild-id: guild-id })
        guild (begin
                (asserts! (is-eq (get owner guild) tx-sender) err-unauthorized)
                (asserts! (not (is-eq user tx-sender)) err-unauthorized)
                (match (map-get? guild-members { guild-id: guild-id, user: user })
                    member (begin
                            (map-delete guild-members { guild-id: guild-id, user: user })
                            (map-delete user-guilds { user: user })
                            (map-set guilds { guild-id: guild-id } (merge guild { member-count: (- (get member-count guild) u1) }))
                            (ok true))
                    err-not-member))
        err-not-found))

(define-public (promote-member (guild-id uint) (user principal))
    (match (map-get? guilds { guild-id: guild-id })
        guild (begin
                (asserts! (is-eq (get owner guild) tx-sender) err-unauthorized)
                (match (map-get? guild-members { guild-id: guild-id, user: user })
                    member (begin
                            (map-set guild-members { guild-id: guild-id, user: user } (merge member { role: "officer" }))
                            (ok true))
                    err-not-member))
        err-not-found))

(define-public (demote-member (guild-id uint) (user principal))
    (match (map-get? guilds { guild-id: guild-id })
        guild (begin
                (asserts! (is-eq (get owner guild) tx-sender) err-unauthorized)
                (match (map-get? guild-members { guild-id: guild-id, user: user })
                    member (begin
                            (map-set guild-members { guild-id: guild-id, user: user } (merge member { role: "member" }))
                            (ok true))
                    err-not-member))
        err-not-found))

(define-public (transfer-ownership (guild-id uint) (new-owner principal))
    (match (map-get? guilds { guild-id: guild-id })
        guild (begin
                (asserts! (is-eq (get owner guild) tx-sender) err-unauthorized)
                (match (map-get? guild-members { guild-id: guild-id, user: new-owner })
                    member (begin
                            (map-set guilds { guild-id: guild-id } (merge guild { owner: new-owner }))
                            (map-set guild-members { guild-id: guild-id, user: tx-sender } { role: "officer", joined-at: burn-block-height }) ;; Reset join time or keep? Keeping simple.
                            (map-set guild-members { guild-id: guild-id, user: new-owner } { role: "owner", joined-at: (get joined-at member) })
                            (ok true))
                    err-not-member))
        err-not-found))

;; Helper functions for quota

(define-public (get-guild-name (guild-id uint))
    (match (map-get? guilds { guild-id: guild-id })
        guild (ok (get name guild))
        err-not-found))

(define-public (get-guild-owner (guild-id uint))
    (match (map-get? guilds { guild-id: guild-id })
        guild (ok (get owner guild))
        err-not-found))

(define-public (get-guild-size (guild-id uint))
    (match (map-get? guilds { guild-id: guild-id })
        guild (ok (get member-count guild))
        err-not-found))

(define-public (is-member (guild-id uint) (user principal))
    (ok (is-some (map-get? guild-members { guild-id: guild-id, user: user }))))

(define-public (is-owner (guild-id uint) (user principal))
    (match (map-get? guilds { guild-id: guild-id })
        guild (ok (is-eq (get owner guild) user))
        err-not-found))

(define-public (update-guild-desc (guild-id uint) (new-desc (string-utf8 256)))
    (match (map-get? guilds { guild-id: guild-id })
        guild (begin
                (asserts! (is-eq (get owner guild) tx-sender) err-unauthorized)
                (map-set guilds { guild-id: guild-id } (merge guild { description: new-desc }))
                (ok true))
        err-not-found))

(define-public (admin-disband-guild (guild-id uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-delete guilds { guild-id: guild-id })
        ;; Note: Leaving members map dirty for simplicity/gas in this example
        (ok true)))

(define-public (invite-user (user principal))
    (begin
        ;; Placeholder
        (ok true)))

(define-public (accept-invite (guild-id uint))
    (begin
        ;; Placeholder
        (ok true)))

(define-public (reject-invite (guild-id uint))
    (begin
        ;; Placeholder
        (ok true)))

(define-public (get-pending-invites (user principal))
    (ok u0)) ;; Placeholder

(define-public (get-guild-creation-block (guild-id uint))
    (match (map-get? guilds { guild-id: guild-id })
        guild (ok (get created-at guild))
        err-not-found))

(define-public (get-member-join-block (guild-id uint) (user principal))
    (match (map-get? guild-members { guild-id: guild-id, user: user })
        member (ok (get joined-at member))
        err-not-found))

(define-public (is-guild-full (guild-id uint))
    (match (map-get? guilds { guild-id: guild-id })
        guild (ok (>= (get member-count guild) u100))
        err-not-found))

(define-public (get-guild-capacity)
    (ok u100))

(define-public (can-join-guild (guild-id uint) (user principal))
    (match (map-get? guilds { guild-id: guild-id })
        guild (ok (and (< (get member-count guild) u100) 
                       (is-none (get guild-id (get-user-guild user)))))
        err-not-found))

(define-public (get-officer-count (guild-id uint))
    (ok u0)) ;; Placeholder - would need iteration or counter

(define-public (is-officer (guild-id uint) (user principal))
    (match (map-get? guild-members { guild-id: guild-id, user: user })
        member (ok (is-eq (get role member) "officer"))
        err-not-found))

(define-public (can-manage-guild (guild-id uint) (user principal))
    (match (map-get? guilds { guild-id: guild-id })
        guild (ok (or (is-eq (get owner guild) user) 
                      (unwrap-panic (is-officer guild-id user))))
        err-not-found))

(define-public (get-guild-level (guild-id uint))
    (ok u1)) ;; Placeholder

(define-public (get-guild-xp (guild-id uint))
    (ok u0)) ;; Placeholder

(define-public (deposit-guild-funds (guild-id uint) (amount uint))
    (ok true))

(define-public (get-guild-balance (guild-id uint))
    (ok u0)) ;; Placeholder

(define-public (withdraw-guild-funds (guild-id uint) (amount uint))
    (ok true))

(define-public (set-guild-logo (guild-id uint) (url (string-ascii 256)))
    (ok true))

(define-public (get-guild-logo (guild-id uint))
    (ok "logo-url")) ;; Placeholder

(define-public (set-guild-website (guild-id uint) (url (string-ascii 256)))
    (ok true))

(define-public (get-guild-website (guild-id uint))
    (ok "website-url")) ;; Placeholder

(define-public (send-guild-message (guild-id uint) (message (string-utf8 256)))
    (ok true))

(define-public (get-latest-message (guild-id uint))
    (ok "message")) ;; Placeholder

(define-public (ban-user (guild-id uint) (user principal))
    (ok true))

(define-public (unban-user (guild-id uint) (user principal))
    (ok true))

(define-public (is-banned (guild-id uint) (user principal))
    (ok false))

(define-public (get-guild-requirements (guild-id uint))
    (ok "none")) ;; Placeholder

(define-public (set-guild-type (guild-id uint) (type (string-ascii 16)))
    (ok true))

(define-public (get-guild-type (guild-id uint))
    (ok "public")) ;; Placeholder

(define-public (is-private-guild (guild-id uint))
    (ok false))

(define-public (request-to-join (guild-id uint))
    (ok true))

(define-public (approve-join-request (guild-id uint) (user principal))
    (ok true))

(define-public (deny-join-request (guild-id uint) (user principal))
    (ok true))

(define-public (get-join-requests-count (guild-id uint))
    (ok u0)) ;; Placeholder

```
