;; bitpay-access-control
;; Role-based access control and emergency controls for BitPay protocol
;; Manages admin privileges, pausing, and authorization for all protocol contracts

;; constants
;;

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_NOT_CONTRACT_OWNER (err u201))
(define-constant ERR_ALREADY_ADMIN (err u202))
(define-constant ERR_NOT_ADMIN (err u203))
(define-constant ERR_PAUSED (err u204))
(define-constant ERR_NOT_PAUSED (err u205))
(define-constant ERR_PENDING_ADMIN_NOT_SET (err u206))
(define-constant ERR_NOT_PENDING_ADMIN (err u207))

;; Contract owner (immutable after deployment)
(define-constant CONTRACT_OWNER tx-sender)

;; data vars
;;

;; Protocol pause state
(define-data-var protocol-paused bool false)

;; Pending admin for two-step transfer
(define-data-var pending-admin (optional principal) none)

;; data maps
;;

;; Admin roles mapping
(define-map admins
    principal
    bool
)

;; Operator roles mapping (can perform certain operations but not admin functions)
(define-map operators
    principal
    bool
)

;; Authorized protocol contracts that can perform privileged operations
;; This prevents unauthorized contracts from calling sensitive functions
(define-map authorized-contracts
    principal
    bool
)

;; Initialize contract owner as first admin
(map-set admins CONTRACT_OWNER true)

;; public functions
;;

;; Add a new admin (only callable by existing admin)
;; @param new-admin: Principal to grant admin role
;; @returns: (ok true) on success
;; #[allow(unchecked_data)]
(define-public (add-admin (new-admin principal))
    (begin
        ;; Only admins can add other admins
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)

        ;; Check if already an admin
        (asserts! (not (is-admin new-admin)) ERR_ALREADY_ADMIN)

        ;; Grant admin role
        (map-set admins new-admin true)

        (print {
            event: "access-admin-added",
            admin: new-admin,
            added-by: tx-sender,
        })

        (ok true)
    )
)

;; Remove an admin (only callable by contract owner or self)
;; @param admin: Principal to revoke admin role from
;; @returns: (ok true) on success
;; #[allow(unchecked_data)]
(define-public (remove-admin (admin principal))
    (begin
        ;; Only contract owner or the admin themselves can remove admin role
        (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-eq tx-sender admin))
            ERR_NOT_CONTRACT_OWNER
        )

        ;; Check if target is actually an admin
        (asserts! (is-admin admin) ERR_NOT_ADMIN)

        ;; Revoke admin role
        (map-delete admins admin)

        (print {
            event: "access-admin-removed",
            admin: admin,
            removed-by: tx-sender,
        })

        (ok true)
    )
)

;; Add an operator
;; @param new-operator: Principal to grant operator role
;; @returns: (ok true) on success
;; #[allow(unchecked_data)]
(define-public (add-operator (new-operator principal))
    (begin
        ;; Only admins can add operators
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)

        ;; Grant operator role
        (map-set operators new-operator true)

        (print {
            event: "access-operator-added",
            operator: new-operator,
            added-by: tx-sender,
        })

        (ok true)
    )
)

;; Remove an operator
;; @param operator: Principal to revoke operator role from
;; @returns: (ok true) on success
;; #[allow(unchecked_data)]
(define-public (remove-operator (operator principal))
    (begin
        ;; Only admins can remove operators
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)

        ;; Revoke operator role
        (map-delete operators operator)

        (print {
            event: "access-operator-removed",
            operator: operator,
            removed-by: tx-sender,
        })

        (ok true)
    )
)

;; Authorize a contract to perform privileged operations
;; @param contract: Contract principal to authorize
;; @returns: (ok true) on success
;; #[allow(unchecked_data)]
(define-public (authorize-contract (contract principal))
    (begin
        ;; Only admins can authorize contracts
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)

        ;; Grant authorization
        (map-set authorized-contracts contract true)
        (print {
            event: "access-contract-authorized",
            contract: contract,
            authorized-by: tx-sender,
        })
        (ok true)
    )
)

;; Revoke contract authorization
;; @param contract: Contract principal to revoke authorization from
;; @returns: (ok true) on success
;; #[allow(unchecked_data)]
(define-public (revoke-contract (contract principal))
    (begin
        ;; Only admins can revoke contract authorization
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)

        ;; Revoke authorization
        (map-delete authorized-contracts contract)
        (print {
            event: "access-contract-revoked",
            contract: contract,
            revoked-by: tx-sender,
        })
        (ok true)
    )
)

;; Pause the protocol (emergency function)
;; Prevents stream creation but allows withdrawals
;; @returns: (ok true) on success
;; #[allow(unchecked_data)]
(define-public (pause-protocol)
    (begin
        ;; Only admins can pause
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)

        ;; Check not already paused
        (asserts! (not (var-get protocol-paused)) ERR_PAUSED)

        ;; Set paused state
        (var-set protocol-paused true)
        (print {
            event: "access-protocol-paused",
            paused-by: tx-sender,
        })
        (ok true)
    )
)

;; Unpause the protocol
;; @returns: (ok true) on success
;; #[allow(unchecked_data)]
(define-public (unpause-protocol)
    (begin
        ;; Only admins can unpause
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)

        ;; Check currently paused
        (asserts! (var-get protocol-paused) ERR_NOT_PAUSED)

        ;; Set unpaused state
        (var-set protocol-paused false)
        (print {
            event: "access-protocol-unpaused",
            unpaused-by: tx-sender,
        })
        (ok true)
    )
)

;; Initiate admin transfer (two-step process for safety)
;; @param new-admin: Principal to transfer admin role to
;; @returns: (ok true) on success
;; #[allow(unchecked_data)]
(define-public (initiate-admin-transfer (new-admin principal))
    (begin
        ;; Only contract owner can initiate transfer
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_CONTRACT_OWNER)

        ;; Set pending admin
        (var-set pending-admin (some new-admin))
        (print {
            event: "access-admin-transfer-initiated",
            from: CONTRACT_OWNER,
            to: new-admin,
        })
        (ok true)
    )
)

;; Accept admin transfer (must be called by pending admin)
;; @returns: (ok true) on success
;; #[allow(unchecked_data)]
(define-public (accept-admin-transfer)
    (let ((pending (var-get pending-admin)))
        (begin
            ;; Check pending admin is set
            (asserts! (is-some pending) ERR_PENDING_ADMIN_NOT_SET)

            ;; Check caller is the pending admin
            (asserts! (is-eq tx-sender (unwrap-panic pending))
                ERR_NOT_PENDING_ADMIN
            )

            ;; Grant admin role to new admin
            (map-set admins tx-sender true)

            ;; Clear pending admin
            (var-set pending-admin none)

            (print {
                event: "access-admin-transfer-completed",
                new-admin: tx-sender,
            })
            (ok true)
        )
    )
)

;; read only functions
;;

;; Check if a principal is an admin
;; @param user: Principal to check
;; @returns: true if admin, false otherwise
(define-read-only (is-admin (user principal))
    (default-to false (map-get? admins user))
)

;; Check if a principal is an operator
;; @param user: Principal to check
;; @returns: true if operator, false otherwise
(define-read-only (is-operator (user principal))
    (default-to false (map-get? operators user))
)

;; Check if protocol is paused
;; @returns: true if paused, false otherwise
(define-read-only (is-paused)
    (var-get protocol-paused)
)

;; Get contract owner
;; @returns: Contract owner principal
(define-read-only (get-contract-owner)
    CONTRACT_OWNER
)

;; Get pending admin (if any)
;; @returns: Optional pending admin principal
(define-read-only (get-pending-admin)
    (var-get pending-admin)
)

;; Check if user has admin or operator role
;; @param user: Principal to check
;; @returns: true if has any elevated role
(define-read-only (has-role (user principal))
    (or (is-admin user) (is-operator user))
)

;; Assert protocol is not paused (for use by other contracts)
;; @returns: (ok true) if not paused, error otherwise
(define-read-only (assert-not-paused)
    (if (var-get protocol-paused)
        ERR_PAUSED
        (ok true)
    )
)

;; Assert caller is admin (for use by other contracts)
;; @param caller: Principal to check
;; @returns: (ok true) if admin, error otherwise
(define-read-only (assert-is-admin (caller principal))
    (if (is-admin caller)
        (ok true)
        ERR_UNAUTHORIZED
    )
)

;; Assert caller is admin or operator (for use by other contracts)
;; @param caller: Principal to check
;; @returns: (ok true) if has role, error otherwise
(define-read-only (assert-has-role (caller principal))
    (if (has-role caller)
        (ok true)
        ERR_UNAUTHORIZED
    )
)

;; Check if a contract is authorized
;; @param contract: Principal to check
;; @returns: true if authorized, false otherwise
(define-read-only (is-authorized-contract (contract principal))
    (default-to false (map-get? authorized-contracts contract))
)

;; Assert contract is authorized (for use by other contracts)
;; @param contract: Principal to check
;; @returns: (ok true) if authorized, error otherwise
(define-read-only (assert-authorized-contract (contract principal))
    (if (is-authorized-contract contract)
        (ok true)
        ERR_UNAUTHORIZED
    )
)
