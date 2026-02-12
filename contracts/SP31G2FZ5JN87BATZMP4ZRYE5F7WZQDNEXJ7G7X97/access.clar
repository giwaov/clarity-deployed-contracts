;; ============================================================================
;; ACCESS.CLAR - Role-Based Access Control & Emergency Controls
;; ============================================================================
;; Manages system roles, emergency pause functionality, and parameter updates.
;; This contract is the central authority for access control across the system.
;; ============================================================================

;; ============================================================================
;; CONSTANTS
;; ============================================================================

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-ALREADY-INITIALIZED (err u1001))
(define-constant ERR-NOT-INITIALIZED (err u1002))
(define-constant ERR-SYSTEM-PAUSED (err u1003))
(define-constant ERR-INVALID-ROLE (err u1004))
(define-constant ERR-ROLE-ALREADY-GRANTED (err u1005))
(define-constant ERR-ROLE-NOT-GRANTED (err u1006))
(define-constant ERR-CANNOT-REVOKE-SELF (err u1007))
(define-constant ERR-ZERO-ADDRESS (err u1008))

;; Role identifiers (bitflags for efficient storage)
(define-constant ROLE-ADMIN u1)           ;; Can manage roles and parameters
(define-constant ROLE-ORACLE u2)          ;; Can post price updates
(define-constant ROLE-RELAYER u4)         ;; Can credit collateral from Chainhook
(define-constant ROLE-LIQUIDATOR u8)      ;; Can trigger liquidations (optional restriction)
(define-constant ROLE-FEE-COLLECTOR u16)  ;; Can withdraw collected fees
(define-constant ROLE-PAUSER u32)         ;; Can pause/unpause system

;; ============================================================================
;; DATA STORAGE
;; ============================================================================

;; Initialization flag
(define-data-var initialized bool false)

;; System pause state
(define-data-var system-paused bool false)

;; Pause timestamp for tracking
(define-data-var pause-block uint u0)

;; Contract deployer (initial admin)
(define-data-var deployer principal tx-sender)

;; Role assignments: principal -> role bitmap
(define-map roles principal uint)

;; Authorized contracts that can call privileged functions
(define-map authorized-contracts principal bool)

;; Emergency contacts for multi-sig scenarios (optional extension)
(define-map emergency-contacts principal bool)

;; ============================================================================
;; INITIALIZATION
;; ============================================================================

;; Initialize the access control system
;; Can only be called once by the deployer
(define-public (initialize (initial-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get deployer)) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get initialized)) ERR-ALREADY-INITIALIZED)
    (asserts! (not (is-eq initial-admin tx-sender)) ERR-ZERO-ADDRESS)
    
    ;; Grant all roles to initial admin
    (map-set roles initial-admin 
      (+ ROLE-ADMIN ROLE-ORACLE ROLE-RELAYER ROLE-LIQUIDATOR ROLE-FEE-COLLECTOR ROLE-PAUSER))
    
    ;; Also grant admin to deployer
    (map-set roles (var-get deployer) ROLE-ADMIN)
    
    (var-set initialized true)
    (print {event: "access-initialized", admin: initial-admin, deployer: (var-get deployer)})
    (ok true)))

;; ============================================================================
;; ROLE MANAGEMENT
;; ============================================================================

;; Check if a principal has a specific role
(define-read-only (has-role (account principal) (role uint))
  (let ((user-roles (default-to u0 (map-get? roles account))))
    (> (bit-and user-roles role) u0)))

;; Check if caller has admin role
(define-read-only (is-admin (account principal))
  (has-role account ROLE-ADMIN))

;; Check if caller has oracle role
(define-read-only (is-oracle (account principal))
  (has-role account ROLE-ORACLE))

;; Check if caller has relayer role
(define-read-only (is-relayer (account principal))
  (has-role account ROLE-RELAYER))

;; Check if caller has pauser role
(define-read-only (is-pauser (account principal))
  (has-role account ROLE-PAUSER))

;; Get all roles for a principal
(define-read-only (get-roles (account principal))
  (default-to u0 (map-get? roles account)))

;; Grant a role to a principal (admin only)
(define-public (grant-role (account principal) (role uint))
  (let ((current-roles (default-to u0 (map-get? roles account))))
    (asserts! (var-get initialized) ERR-NOT-INITIALIZED)
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-role role) ERR-INVALID-ROLE)
    
    ;; Check if role already granted
    (asserts! (is-eq (bit-and current-roles role) u0) ERR-ROLE-ALREADY-GRANTED)
    
    ;; Grant the role by OR-ing with existing roles
    (map-set roles account (bit-or current-roles role))
    
    (print {event: "role-granted", account: account, role: role, granter: tx-sender})
    (ok true)))

;; Revoke a role from a principal (admin only)
(define-public (revoke-role (account principal) (role uint))
  (let ((current-roles (default-to u0 (map-get? roles account))))
    (asserts! (var-get initialized) ERR-NOT-INITIALIZED)
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-role role) ERR-INVALID-ROLE)
    
    ;; Prevent admin from revoking their own admin role
    (asserts! (not (and (is-eq account tx-sender) (is-eq role ROLE-ADMIN))) ERR-CANNOT-REVOKE-SELF)
    
    ;; Check if role exists
    (asserts! (> (bit-and current-roles role) u0) ERR-ROLE-NOT-GRANTED)
    
    ;; Revoke the role by AND-ing with complement
    (map-set roles account (bit-and current-roles (bit-not role)))
    
    (print {event: "role-revoked", account: account, role: role, revoker: tx-sender})
    (ok true)))

;; Validate that role is a known role
(define-read-only (is-valid-role (role uint))
  (or (is-eq role ROLE-ADMIN)
      (is-eq role ROLE-ORACLE)
      (is-eq role ROLE-RELAYER)
      (is-eq role ROLE-LIQUIDATOR)
      (is-eq role ROLE-FEE-COLLECTOR)
      (is-eq role ROLE-PAUSER)))

;; ============================================================================
;; CONTRACT AUTHORIZATION
;; ============================================================================

;; Authorize a contract to call privileged functions
(define-public (authorize-contract (contract-principal principal))
  (begin
    (asserts! (var-get initialized) ERR-NOT-INITIALIZED)
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-set authorized-contracts contract-principal true)
    
    (print {event: "contract-authorized", contract: contract-principal, authorizer: tx-sender})
    (ok true)))

;; Revoke contract authorization
(define-public (revoke-contract (contract-principal principal))
  (begin
    (asserts! (var-get initialized) ERR-NOT-INITIALIZED)
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-delete authorized-contracts contract-principal)
    
    (print {event: "contract-revoked", contract: contract-principal, revoker: tx-sender})
    (ok true)))

;; Check if a contract is authorized
(define-read-only (is-authorized-contract (contract-principal principal))
  (default-to false (map-get? authorized-contracts contract-principal)))

;; ============================================================================
;; EMERGENCY CONTROLS
;; ============================================================================

;; Pause the entire system
(define-public (pause)
  (begin
    (asserts! (var-get initialized) ERR-NOT-INITIALIZED)
    (asserts! (or (is-pauser tx-sender) (is-admin tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get system-paused)) ERR-SYSTEM-PAUSED)
    
    (var-set system-paused true)
    (var-set pause-block block-height)
    
    (print {event: "system-paused", pauser: tx-sender, block: block-height})
    (ok true)))

;; Unpause the system (admin only for safety)
(define-public (unpause)
  (begin
    (asserts! (var-get initialized) ERR-NOT-INITIALIZED)
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (var-get system-paused) (err u1009)) ;; Not paused
    
    (var-set system-paused false)
    
    (print {event: "system-unpaused", unpauser: tx-sender, block: block-height, 
            paused-duration: (- block-height (var-get pause-block))})
    (ok true)))

;; Check if system is paused
(define-read-only (is-paused)
  (var-get system-paused))

;; Get pause info
(define-read-only (get-pause-info)
  {
    paused: (var-get system-paused),
    pause-block: (var-get pause-block),
    current-block: block-height
  })

;; ============================================================================
;; ACCESS CHECK HELPERS (for other contracts to call)
;; ============================================================================

;; Assert that system is not paused (for use in other contracts)
(define-read-only (check-not-paused)
  (not (var-get system-paused)))

;; Combined check: not paused AND has role
(define-read-only (can-execute (account principal) (required-role uint))
  (and (not (var-get system-paused))
       (has-role account required-role)))

;; Check if caller can perform oracle operations
(define-read-only (can-post-price (account principal))
  (and (not (var-get system-paused))
       (has-role account ROLE-ORACLE)))

;; Check if caller can credit collateral (relayer)
(define-read-only (can-credit-collateral (account principal))
  (and (not (var-get system-paused))
       (has-role account ROLE-RELAYER)))

;; ============================================================================
;; ADMIN INFO
;; ============================================================================

;; Get system info
(define-read-only (get-system-info)
  {
    initialized: (var-get initialized),
    paused: (var-get system-paused),
    deployer: (var-get deployer)
  })

;; Get role constants for reference
(define-read-only (get-role-constants)
  {
    admin: ROLE-ADMIN,
    oracle: ROLE-ORACLE,
    relayer: ROLE-RELAYER,
    liquidator: ROLE-LIQUIDATOR,
    fee-collector: ROLE-FEE-COLLECTOR,
    pauser: ROLE-PAUSER
  })
