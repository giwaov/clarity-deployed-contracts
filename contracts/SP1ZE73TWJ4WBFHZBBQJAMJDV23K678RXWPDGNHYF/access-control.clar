;; Title: Access Control
;; Version: 2.0.0
;; Summary: Enhanced role-based access control for BlockPay ecosystem
;; Description: Manages Owner, Admin, and Employer roles with time-locked changes

;; ============================================
;; Constants - Error Codes
;; ============================================
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_ALREADY_EXISTS (err u1001))
(define-constant ERR_NOT_FOUND (err u1002))
(define-constant ERR_INVALID_ROLE (err u1003))
(define-constant ERR_TIMELOCK_ACTIVE (err u1004))
(define-constant ERR_TIMELOCK_NOT_READY (err u1005))
(define-constant ERR_CANNOT_REMOVE_SELF (err u1006))

;; ============================================
;; Constants - Configuration
;; ============================================
(define-constant TIMELOCK_BLOCKS u144) ;; ~24 hours at 10 min/block
(define-constant ROLE_OWNER "owner")
(define-constant ROLE_ADMIN "admin")
(define-constant ROLE_EMPLOYER "employer")

;; ============================================
;; Data Variables
;; ============================================
(define-data-var contract-owner principal tx-sender)
(define-data-var emergency-paused bool false)

;; ============================================
;; Data Maps - Roles
;; ============================================
(define-map admins principal bool)
(define-map employers principal bool)

;; ============================================
;; Data Maps - Time-locked Role Changes
;; ============================================
(define-map pending-role-changes
    { target: principal, role: (string-ascii 20) }
    { proposer: principal, action: (string-ascii 10), proposed-at: uint }
)

;; ============================================
;; Data Maps - Role History (Audit Trail)
;; ============================================
(define-map role-history
    principal
    (list 50 { role: (string-ascii 20), action: (string-ascii 10), block: uint, by: principal })
)

;; ============================================
;; Read-Only Functions - Role Checks
;; ============================================

(define-read-only (get-owner)
    (var-get contract-owner)
)

(define-read-only (is-owner (user principal))
    (is-eq user (var-get contract-owner))
)

(define-read-only (is-admin (user principal))
    (default-to false (map-get? admins user))
)

(define-read-only (is-employer (user principal))
    (default-to false (map-get? employers user))
)

(define-read-only (is-emergency-paused)
    (var-get emergency-paused)
)

;; Unified authorization check
(define-read-only (is-authorized (user principal) (required-role (string-ascii 20)))
    (if (is-eq required-role ROLE_OWNER)
        (is-owner user)
        (if (is-eq required-role ROLE_ADMIN)
            (or (is-owner user) (is-admin user))
            (if (is-eq required-role ROLE_EMPLOYER)
                (or (is-owner user) (is-admin user) (is-employer user))
                false
            )
        )
    )
)

;; Check if a role change is pending
(define-read-only (get-pending-role-change (target principal) (role (string-ascii 20)))
    (map-get? pending-role-changes { target: target, role: role })
)

;; Get role history for a principal
(define-read-only (get-role-history (user principal))
    (default-to (list) (map-get? role-history user))
)

;; ============================================
;; Private Functions - Helpers
;; ============================================

(define-private (add-to-history (user principal) (role (string-ascii 20)) (action (string-ascii 10)))
    (let
        (
            (current-history (default-to (list) (map-get? role-history user)))
            (new-entry { role: role, action: action, block: block-height, by: tx-sender })
        )
        (map-set role-history user (unwrap-panic (as-max-len? (append current-history new-entry) u50)))
    )
)

;; ============================================
;; Public Functions - Owner Management
;; ============================================

(define-public (set-owner (new-owner principal))
    (begin
        (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
        (asserts! (not (is-eq new-owner tx-sender)) ERR_CANNOT_REMOVE_SELF)
        (var-set contract-owner new-owner)
        (add-to-history new-owner ROLE_OWNER "grant")
        (ok true)
    )
)

;; ============================================
;; Public Functions - Admin Management
;; ============================================

(define-public (add-admin (admin principal))
    (begin
        (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
        (asserts! (not (is-admin admin)) ERR_ALREADY_EXISTS)
        (map-set admins admin true)
        (add-to-history admin ROLE_ADMIN "grant")
        (ok true)
    )
)

(define-public (remove-admin (admin principal))
    (begin
        (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
        (asserts! (is-admin admin) ERR_NOT_FOUND)
        (map-delete admins admin)
        (add-to-history admin ROLE_ADMIN "revoke")
        (ok true)
    )
)

;; ============================================
;; Public Functions - Employer Management
;; ============================================

(define-public (add-employer (employer principal))
    (begin
        (asserts! (or (is-owner tx-sender) (is-admin tx-sender)) ERR_UNAUTHORIZED)
        (asserts! (not (is-employer employer)) ERR_ALREADY_EXISTS)
        (map-set employers employer true)
        (add-to-history employer ROLE_EMPLOYER "grant")
        (ok true)
    )
)

(define-public (remove-employer (employer principal))
    (begin
        (asserts! (or (is-owner tx-sender) (is-admin tx-sender)) ERR_UNAUTHORIZED)
        (asserts! (is-employer employer) ERR_NOT_FOUND)
        (map-delete employers employer)
        (add-to-history employer ROLE_EMPLOYER "revoke")
        (ok true)
    )
)

;; ============================================
;; Public Functions - Time-locked Role Changes
;; ============================================

(define-public (propose-role-change (target principal) (role (string-ascii 20)) (action (string-ascii 10)))
    (begin
        (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
        (asserts! (is-none (get-pending-role-change target role)) ERR_TIMELOCK_ACTIVE)
        (map-set pending-role-changes
            { target: target, role: role }
            { proposer: tx-sender, action: action, proposed-at: block-height }
        )
        (ok true)
    )
)

(define-public (execute-role-change (target principal) (role (string-ascii 20)))
    (let
        (
            (pending (unwrap! (get-pending-role-change target role) ERR_NOT_FOUND))
            (proposed-at (get proposed-at pending))
            (action (get action pending))
        )
        (asserts! (>= block-height (+ proposed-at TIMELOCK_BLOCKS)) ERR_TIMELOCK_NOT_READY)
        
        ;; Execute the role change based on action
        (if (is-eq action "grant")
            (if (is-eq role ROLE_ADMIN)
                (map-set admins target true)
                (if (is-eq role ROLE_EMPLOYER)
                    (map-set employers target true)
                    false
                )
            )
            (if (is-eq action "revoke")
                (if (is-eq role ROLE_ADMIN)
                    (map-delete admins target)
                    (if (is-eq role ROLE_EMPLOYER)
                        (map-delete employers target)
                        false
                    )
                )
                false
            )
        )
        
        ;; Clean up pending change
        (map-delete pending-role-changes { target: target, role: role })
        (add-to-history target role action)
        (ok true)
    )
)

(define-public (cancel-role-change (target principal) (role (string-ascii 20)))
    (begin
        (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
        (asserts! (is-some (get-pending-role-change target role)) ERR_NOT_FOUND)
        (map-delete pending-role-changes { target: target, role: role })
        (ok true)
    )
)

;; ============================================
;; Public Functions - Emergency Controls
;; ============================================

(define-public (set-emergency-pause (paused bool))
    (begin
        (asserts! (or (is-owner tx-sender) (is-admin tx-sender)) ERR_UNAUTHORIZED)
        (var-set emergency-paused paused)
        (ok true)
    )
)
