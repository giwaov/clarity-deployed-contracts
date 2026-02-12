---
title: "Trait profile-registry-v6"
draft: true
---
```
;; profile-registry.clar
;; User profile management system

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-name (err u103))

;; Data Maps
(define-map profiles
    { user: principal }
    {
        username: (string-ascii 48),
        bio: (string-utf8 256),
        avatar-url: (string-ascii 256),
        created-at: uint,
        updated-at: uint,
        reputation: uint,
        is-verified: bool,
    }
)

(define-map username-registry
    { username: (string-ascii 48) }
    { owner: principal }
)
(define-map user-settings
    { user: principal }
    {
        notifications: bool,
        public-profile: bool,
        theme: (string-ascii 16),
    }
)
(define-map social-links
    { user: principal }
    {
        twitter: (string-ascii 64),
        discord: (string-ascii 64),
        website: (string-ascii 128),
    }
)

;; Variables
(define-data-var profile-count uint u0)
(define-data-var registration-fee uint u1000000)

;; Read-only functions

(define-read-only (get-profile (user principal))
    (map-get? profiles { user: user })
)

(define-read-only (get-username-owner (username (string-ascii 48)))
    (get owner (map-get? username-registry { username: username }))
)

(define-read-only (get-user-settings (user principal))
    (default-to {
        notifications: true,
        public-profile: true,
        theme: "light",
    }
        (map-get? user-settings { user: user })
    )
)

(define-read-only (get-social-links (user principal))
    (map-get? social-links { user: user })
)

(define-read-only (get-profile-count)
    (var-get profile-count)
)

(define-read-only (get-registration-fee)
    (var-get registration-fee)
)

(define-read-only (is-username-taken (username (string-ascii 48)))
    (is-some (map-get? username-registry { username: username }))
)

;; Public functions

(define-public (register-profile
        (username (string-ascii 48))
        (bio (string-utf8 256))
    )
    (begin
        (asserts! (is-none (map-get? profiles { user: tx-sender }))
            err-already-exists
        )
        (asserts! (is-none (map-get? username-registry { username: username }))
            err-already-exists
        )
        (asserts! (> (len username) u2) err-invalid-name)

        (map-set profiles { user: tx-sender } {
            username: username,
            bio: bio,
            avatar-url: "",
            created-at: burn-block-height,
            updated-at: burn-block-height,
            reputation: u0,
            is-verified: false,
        })
        (map-set username-registry { username: username } { owner: tx-sender })
        (var-set profile-count (+ (var-get profile-count) u1))
        (ok true)
    )
)

(define-public (update-bio (new-bio (string-utf8 256)))
    (match (map-get? profiles { user: tx-sender })
        profile (begin
            (map-set profiles { user: tx-sender }
                (merge profile {
                    bio: new-bio,
                    updated-at: burn-block-height,
                })
            )
            (ok true)
        )
        err-not-found
    )
)

(define-public (update-avatar (new-url (string-ascii 256)))
    (match (map-get? profiles { user: tx-sender })
        profile (begin
            (map-set profiles { user: tx-sender }
                (merge profile {
                    avatar-url: new-url,
                    updated-at: burn-block-height,
                })
            )
            (ok true)
        )
        err-not-found
    )
)

(define-public (set-user-settings
        (notifications bool)
        (public-profile bool)
        (theme (string-ascii 16))
    )
    (begin
        (map-set user-settings { user: tx-sender } {
            notifications: notifications,
            public-profile: public-profile,
            theme: theme,
        })
        (ok true)
    )
)

(define-public (update-social-links
        (twitter (string-ascii 64))
        (discord (string-ascii 64))
        (website (string-ascii 128))
    )
    (begin
        (map-set social-links { user: tx-sender } {
            twitter: twitter,
            discord: discord,
            website: website,
        })
        (ok true)
    )
)

(define-public (verify-user (user principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (match (map-get? profiles { user: user })
            profile (begin
                (map-set profiles { user: user }
                    (merge profile { is-verified: true })
                )
                (ok true)
            )
            err-not-found
        )
    )
)

(define-public (unverify-user (user principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (match (map-get? profiles { user: user })
            profile (begin
                (map-set profiles { user: user }
                    (merge profile { is-verified: false })
                )
                (ok true)
            )
            err-not-found
        )
    )
)

(define-public (add-reputation
        (user principal)
        (amount uint)
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (match (map-get? profiles { user: user })
            profile (begin
                (map-set profiles { user: user }
                    (merge profile { reputation: (+ (get reputation profile) amount) })
                )
                (ok true)
            )
            err-not-found
        )
    )
)

(define-public (slash-reputation
        (user principal)
        (amount uint)
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (match (map-get? profiles { user: user })
            profile (begin
                (let ((current-rep (get reputation profile)))
                    (map-set profiles { user: user }
                        (merge profile { reputation: (if (> current-rep amount)
                            (- current-rep amount)
                            u0
                        ) }
                        ))
                    (ok true)
                )
            )
            err-not-found
        )
    )
)

(define-public (set-registration-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set registration-fee new-fee)
        (ok true)
    )
)

;; Helper functions for quota

(define-public (get-user-reputation (user principal))
    (match (map-get? profiles { user: user })
        profile (ok (get reputation profile))
        err-not-found
    )
)

(define-public (is-user-verified (user principal))
    (match (map-get? profiles { user: user })
        profile (ok (get is-verified profile))
        err-not-found
    )
)

(define-public (get-user-theme (user principal))
    (ok (get theme (get-user-settings user)))
)

(define-public (has-public-profile (user principal))
    (ok (get public-profile (get-user-settings user)))
)

(define-public (wants-notifications (user principal))
    (ok (get notifications (get-user-settings user)))
)

(define-public (get-twitter-link (user principal))
    (match (map-get? social-links { user: user })
        links (ok (get twitter links))
        (ok "")
    )
)

(define-public (get-discord-link (user principal))
    (match (map-get? social-links { user: user })
        links (ok (get discord links))
        (ok "")
    )
)

(define-public (get-website-link (user principal))
    (match (map-get? social-links { user: user })
        links (ok (get website links))
        (ok "")
    )
)

(define-public (delete-profile)
    (match (map-get? profiles { user: tx-sender })
        profile (begin
            (map-delete profiles { user: tx-sender })
            (map-delete username-registry { username: (get username profile) })
            (var-set profile-count (- (var-get profile-count) u1))
            (ok true)
        )
        err-not-found
    )
)

(define-public (admin-delete-profile (user principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (match (map-get? profiles { user: user })
            profile (begin
                (map-delete profiles { user: user })
                (map-delete username-registry { username: (get username profile) })
                (var-set profile-count (- (var-get profile-count) u1))
                (ok true)
            )
            err-not-found
        )
    )
)

(define-public (check-username-length (username (string-ascii 48)))
    (ok (len username))
)

(define-public (is-long-bio (user principal))
    (match (map-get? profiles { user: user })
        profile (ok (> (len (get bio profile)) u100))
        err-not-found
    )
)

(define-public (is-new-user (user principal))
    (match (map-get? profiles { user: user })
        profile (ok (< (- burn-block-height (get created-at profile)) u1000))
        err-not-found
    )
)

(define-public (get-account-age (user principal))
    (match (map-get? profiles { user: user })
        profile (ok (- burn-block-height (get created-at profile)))
        err-not-found
    )
)

(define-public (update-username (new-username (string-ascii 48)))
    (match (map-get? profiles { user: tx-sender })
        profile (begin
            (asserts!
                (is-none (map-get? username-registry { username: new-username }))
                err-already-exists
            )
            (map-delete username-registry { username: (get username profile) })
            (map-set username-registry { username: new-username } { owner: tx-sender })
            (map-set profiles { user: tx-sender }
                (merge profile {
                    username: new-username,
                    updated-at: burn-block-height,
                })
            )
            (ok true)
        )
        err-not-found
    )
)

(define-public (hello-world)
    (ok "Hello World")
)

(define-public (echo-string (msg (string-ascii 20)))
    (ok msg)
)

(define-public (concat-strings
        (a (string-ascii 20))
        (b (string-ascii 20))
    )
    (ok (concat a b))
)

(define-public (is-contract-owner-check)
    (ok (is-eq tx-sender contract-owner))
)

(define-public (get-block-info-time)
    ;; (ok (get-block-info? time (- burn-block-height u1)))
    (ok u0)
    ;; FIXME: get-block-info? is unresolved in Clarity 4
)

(define-public (get-block-info-header-hash)
    (ok (get-burn-block-info? header-hash (- burn-block-height u1)))
)

(define-public (get-block-info-burnchain-header-hash)
    ;; (ok (get-burn-block-info? burnchain-header-hash (- burn-block-height u1)))
    (ok none)
    ;; FIXME: burnchain-header-hash not supported in get-burn-block-info?
)

(define-public (get-block-info-id-header-hash)
    ;; (ok (get-burn-block-info? id-header-hash (- burn-block-height u1)))
    (ok none)
    ;; FIXME: id-header-hash not supported in get-burn-block-info?
)

(define-public (get-block-info-miner-address)
    ;; (ok (get-burn-block-info? miner-address (- burn-block-height u1)))
    (ok none)
    ;; FIXME: miner-address not supported in get-burn-block-info?
)

(define-public (get-block-info-vrf-seed)
    ;; (ok (get-burn-block-info? vrf-seed (- burn-block-height u1)))
    (ok none)
    ;; FIXME: vrf-seed not supported in get-burn-block-info?
)

(define-public (check-principal (p principal))
    (ok p)
)

(define-public (check-uint (u uint))
    (ok u)
)

(define-public (check-int (i int))
    (ok i)
)

(define-public (check-bool (b bool))
    (ok b)
)

(define-public (check-buff (b (buff 10)))
    (ok b)
)

(define-public (check-list (l (list 10 uint)))
    (ok l)
)

(define-public (check-tuple (t {
    a: uint,
    b: bool,
}))
    (ok t)
)

(define-public (check-optional (o (optional uint)))
    (ok o)
)

(define-public (check-response (r (response uint uint)))
    (ok r)
)

(define-public (noop)
    (ok true)
)

```
