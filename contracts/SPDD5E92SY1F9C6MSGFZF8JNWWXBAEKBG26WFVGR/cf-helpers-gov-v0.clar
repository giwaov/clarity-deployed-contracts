;; cf-helpers-gov-v0
;; Governance helper for Cofund Admin management
;; Supports add, remove, and rotate operations for keys
;; This contract manages ONLY Cofund Admins, NOT vault admins

;; -------------------------------------------------------------------
;;                              ERRORS
;; -------------------------------------------------------------------
(define-constant ERR_UNAUTHORIZED_CALLER (err u600))
(define-constant ERR_ADMIN_EXISTS (err u601))
(define-constant ERR_NOT_ADMIN (err u602))
(define-constant ERR_LAST_ADMIN (err u603))
(define-constant ERR_SELF_REMOVAL (err u604))

;; -------------------------------------------------------------------
;;                          PUBLIC FUNCTIONS
;; -------------------------------------------------------------------

;; add-cofund-admin
;; Add a new Cofund admin
;; Only existing Cofund admins can call this function
;; @param new-admin: The principal to add as a Cofund admin
(define-public (add-cofund-admin (new-admin principal))
    (begin
        ;; Check that caller is a Cofund admin
        (asserts! (contract-call? .cf-helpers-state-v0 is-cofund-admin tx-sender)
            ERR_UNAUTHORIZED_CALLER
        )
        ;; Check that new admin is not already an admin
        (asserts! (not (contract-call? .cf-helpers-state-v0 is-cofund-admin new-admin))
            ERR_ADMIN_EXISTS
        )
        ;; Set new admin status
        (try! (contract-call? .cf-helpers-state-v0 set-cofund-admin new-admin true))
        ;; Increment admin count
        (try! (contract-call? .cf-helpers-state-v0 increment-cofund-admin-count))
        ;; Print event
        (print {
            topic: "Cofund Admin Added",
            new-admin: new-admin,
            added-by: tx-sender,
        })
        (ok true)
    )
)

;; remove-cofund-admin
;; Remove a Cofund admin 
;; Only existing Cofund admins can call this function
;; Cannot remove yourself, cannot remove the last admin
;; @param admin-to-remove: The principal to remove as a Cofund admin
(define-public (remove-cofund-admin (admin-to-remove principal))
    (begin
        ;; Check that caller is a Cofund admin
        (asserts! (contract-call? .cf-helpers-state-v0 is-cofund-admin tx-sender)
            ERR_UNAUTHORIZED_CALLER
        )
        ;; Cannot remove yourself
        (asserts! (not (is-eq tx-sender admin-to-remove))
            ERR_SELF_REMOVAL
        )
        ;; Check that the admin to remove exists
        (asserts! (contract-call? .cf-helpers-state-v0 is-cofund-admin admin-to-remove)
            ERR_NOT_ADMIN
        )
        ;; Ensure at least 1 admin remains after removal
        (asserts! (> (contract-call? .cf-helpers-state-v0 get-cofund-admin-count) u1)
            ERR_LAST_ADMIN
        )
        ;; Remove admin status
        (try! (contract-call? .cf-helpers-state-v0 set-cofund-admin admin-to-remove false))
        ;; Decrement admin count
        (try! (contract-call? .cf-helpers-state-v0 decrement-cofund-admin-count))
        ;; Print event
        (print {
            topic: "Cofund Admin Removed",
            admin: admin-to-remove,
            removed-by: tx-sender,
        })
        (ok true)
    )
)

;; rotate-cofund-admin
;; Rotate own admin key to a new address
;; Caller's admin status is revoked, new-admin gains admin status
;; Count remains unchanged
;; @param new-admin: The new principal to transfer admin privileges to
(define-public (rotate-cofund-admin (new-admin principal))
    (let (
        (old-admin tx-sender)
    )
        ;; Check that caller is a Cofund admin
        (asserts! (contract-call? .cf-helpers-state-v0 is-cofund-admin old-admin)
            ERR_UNAUTHORIZED_CALLER
        )
        ;; Check that new admin is not already an admin
        (asserts! (not (contract-call? .cf-helpers-state-v0 is-cofund-admin new-admin))
            ERR_ADMIN_EXISTS
        )
        ;; Revoke old admin status
        (try! (contract-call? .cf-helpers-state-v0 set-cofund-admin old-admin false))
        ;; Grant new admin status
        (try! (contract-call? .cf-helpers-state-v0 set-cofund-admin new-admin true))
        ;; Count unchanged (no increment/decrement)
        ;; Print event
        (print {
            topic: "Cofund Admin Rotated",
            old-admin: old-admin,
            new-admin: new-admin,
        })
        (ok true)
    )
)

;; -------------------------------------------------------------------
;;                         READ-ONLY FUNCTIONS
;; -------------------------------------------------------------------

;; is-admin
;; Check if address is a Cofund admin
;; @param addr: The principal to check
(define-read-only (is-admin (addr principal))
    (contract-call? .cf-helpers-state-v0 is-cofund-admin addr)
)

;; admin-count
;; Get total number of Cofund admins
(define-read-only (admin-count)
    (contract-call? .cf-helpers-state-v0 get-cofund-admin-count)
)
