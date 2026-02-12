;; This is a Cofund helper contract that provides state management for all Cofund vaults.
;; It provides the ability to manage users, policies, & assists in executing transactions/transfers.
;; Only specific contracts (such as active helper contracts) & callers (such as ) can call into this contract.

;; cons
;; errs
(define-constant ERR_UNAUTHORIZED_USER (err u200))
(define-constant ERR_USER_EXISTS (err u201))
(define-constant ERR_ADDRESS_EXISTS (err u202))
(define-constant ERR_KEY_EXISTS (err u203))
(define-constant ERR_INVALID_INVITE (err u204))
(define-constant ERR_INVITE_REPLAY (err u205))
(define-constant ERR_INVITE_EXPIRED (err u206))
(define-constant ERR_INVITE_EXISTS (err u207))
(define-constant ERR_INVALID_PREIMAGE (err u208))
(define-constant ERR_INACTIVE_USER (err u209))
(define-constant ERR_INVALID_USER (err u210))
(define-constant ERR_INVALID_POSITION (err u211))
(define-constant ERR_MIN_ADMINS (err u212))
(define-constant ERR_UNAUTHORIZED_CALLER (err u213))
(define-constant ERR_POLICY_REPLAY (err u214))
(define-constant ERR_INVALID_POLICY (err u215))
(define-constant ERR_AUTHID_REPLAY (err u216))
(define-constant ERR_INVALID_CLIENT (err u217))  
(define-constant ERR_INVALID_TIER (err u218))      
(define-constant ERR_EMPTY_TIER_NAME (err u219))   
(define-constant ERR_FEE_TOO_HIGH (err u220))     
(define-constant ERR_INVALID_CONTRACT_NAME (err u221))
(define-constant ERR_INVALID_CONTRACT_ADDRESS (err u222))
(define-constant ERR_MIGRATION_NOT_SET (err u223))
(define-constant ERR_MIGRATION_LOCKED (err u224))
(define-constant ERR_MIGRATION_ALREADY_SET (err u225))


;; data maps
;; helper-contracts
;; active helper contracts
(define-map helper-contracts
    (string-ascii 128)
    principal
)
(map-set helper-contracts "users" .cf-helpers-users-v0)
(map-set helper-contracts "policies" .cf-helpers-policies-v0)
(map-set helper-contracts "gov" .cf-helpers-gov-v0)
(define-map cofund-admins
    principal
    bool
)
;; Track Cofund admin count for governance operations
(define-data-var cofund-admin-count uint u0)

(define-map cofund-policy-types
    (string-ascii 128)
    bool
)
;; Initialize deployer as the only Cofund admin
(map-set cofund-admins tx-sender true)
(var-set cofund-admin-count u1)
(map-set cofund-policy-types "Contractor_Stipend" true)
(map-set cofund-policy-types "Crypto_Onramp" true)
(map-set cofund-policy-types "Business_Invoice" true)
(map-set cofund-policy-types "Operational_Expense" true)
(map-set cofund-policy-types "Treasury_Management" true)
(define-map client
    (buff 32)
    bool
)
;; invites
;; predetermined invites for adding users
(define-map invites
    {
        client-id: (buff 32),
        invite-hash: (buff 32),
    }
    {
        activated: bool,
        is-admin: bool,
        user-id: (string-ascii 64),
        user-position: (string-ascii 128),
        expire-height: uint,
    }
)
;; policies
;; predetermined policies for vault executions
(define-map policies
    {
        client-id: (buff 32),
        policy: (string-ascii 64),
    }
    {
        active: bool,
        title: (string-ascii 128),
        type: (string-ascii 128),
        signers: (list 35 (buff 33)),
        threshold: uint,
        transaction: (optional {
            wrapper: principal,
            function: (string-ascii 32),
        }),
        transfer: (optional {
            max-amount: uint,
            token: principal,
            recipients: (optional (list 50 principal)),
        }),
    }
)
;; users
;; users registered with a vault
(define-map users
    {
        client-id: (buff 32),
        user-id: (string-ascii 64),
    }
    {
        address: principal,
        key: (buff 33),
        position: (string-ascii 128),
        active: bool,
        is-admin: bool,
    }
)
;; auth-ids
;; used auth-ids to avoid signature replays
(define-map auth-ids
    {
        client-id: (buff 32),
        contract: principal,
        auth-id: (string-ascii 64),
    }
    bool
)
(define-map users-by-address
    principal
    {
        client-id: (buff 32),
        user-id: (string-ascii 64),
    }
)
(define-map users-by-key
    (buff 33)
    {
        client-id: (buff 32),
        user-id: (string-ascii 64),
    }
)
;; active admins per client
(define-map active-admins
    (buff 32)
    uint
)

;; subscription tier management
;; Map tier name to fee in basis points (1 bps = 0.01%)
(define-map subscription-tiers (string-ascii 32) uint)

;; Map client-id to their subscription tier
(define-map client-subscription (buff 32) (string-ascii 32))

;; Fee recipient address for subscription fees
;; TODO: MAINNET - Replace this testnet address with production fee recipient before deployment
;; WARNING: This testnet address will receive all fees if not updated
(define-data-var cf-fee-recipient principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Migration settings (single-use seeding contract)
(define-data-var migration-writer (optional principal) none)
(define-data-var migration-complete bool false)

;; Initialize default subscription tiers
(map-set subscription-tiers "FREE" u250)      ;; 2.5%
(map-set subscription-tiers "TEAM" u125)      ;; 1.25%
(map-set subscription-tiers "BUSINESS" u0)    ;; 0%

;; read-only functions
(define-read-only (get-active-helper (type (string-ascii 128)))
    (map-get? helper-contracts type)
)
(define-read-only (get-policy
        (client-id (buff 32))
        (policy-id (string-ascii 64))
    )
    (map-get? policies {
        client-id: client-id,
        policy: policy-id,
    })
)
(define-read-only (get-user
        (client-id (buff 32))
        (user-id (string-ascii 64))
    )
    (map-get? users {
        client-id: client-id,
        user-id: user-id,
    })
)
(define-read-only (get-user-id-by-address (address principal))
    (map-get? users-by-address address)
)
(define-read-only (get-user-id-by-key (key (buff 33)))
    (map-get? users-by-key key)
)
(define-read-only (get-active-admins (client-id (buff 32)))
    (map-get? active-admins client-id)
)

(define-read-only (get-invite
        (client-id (buff 32))
        (invite-hash (buff 32))
    )
    (map-get? invites {
        client-id: client-id,
        invite-hash: invite-hash,
    })
)
(define-read-only (get-policy-type (policy-type (string-ascii 128)))
    (map-get? cofund-policy-types policy-type)
)
(define-read-only (get-used-auth-ids
        (client-id (buff 32))
        (auth-id (string-ascii 64))
    )
    (map-get? auth-ids {
        client-id: client-id,
        contract: contract-caller,
        auth-id: auth-id,
    })
)

(define-read-only (is-cofund-admin (caller principal))
    (is-some (map-get? cofund-admins caller))
)

;; Get Cofund admin count
(define-read-only (get-cofund-admin-count)
    (var-get cofund-admin-count)
)

;; -------------------------------------------------------------------
;;                      GOV HELPER STORAGE SETTERS
;; -------------------------------------------------------------------
;; All validation logic lives in cf-helpers-gov-v0 - these are pure storage setters

;; set-cofund-admin
;; Set Cofund admin status (only callable by gov helper)
;; @param admin: The principal to set as admin
;; @param status: true to add, false to remove
(define-public (set-cofund-admin (admin principal) (status bool))
    (begin
        ;; Only gov helper can call this
        (asserts! (is-eq contract-caller (unwrap-panic (map-get? helper-contracts "gov")))
            ERR_UNAUTHORIZED_CALLER
        )
        (if status
            (map-set cofund-admins admin true)
            (map-delete cofund-admins admin)
        )
        (ok true)
    )
)

;; increment-cofund-admin-count
;; Increment Cofund admin count (only callable by gov helper)
(define-public (increment-cofund-admin-count)
    (begin
        ;; Only gov helper can call this
        (asserts! (is-eq contract-caller (unwrap-panic (map-get? helper-contracts "gov")))
            ERR_UNAUTHORIZED_CALLER
        )
        (var-set cofund-admin-count (+ (var-get cofund-admin-count) u1))
        (ok true)
    )
)

;; decrement-cofund-admin-count
;; Decrement Cofund admin count (only callable by gov helper)
(define-public (decrement-cofund-admin-count)
    (begin
        ;; Only gov helper can call this
        (asserts! (is-eq contract-caller (unwrap! (map-get? helper-contracts "gov") ERR_UNAUTHORIZED_CALLER))
            ERR_UNAUTHORIZED_CALLER
        )
        (var-set cofund-admin-count (- (var-get cofund-admin-count) u1))
        (ok true)
    )
)

;; subscription tier read-only functions
;; Get fee recipient address
(define-read-only (get-fee-recipient-address)
    (var-get cf-fee-recipient)
)

;; Get fee bps for a tier
(define-read-only (get-subscription-tier-fee (tier (string-ascii 32)))
    (map-get? subscription-tiers tier)
)

;; Get client's fee in basis points (convenience function for vault/wrappers)
(define-read-only (get-client-fee-bps (client-id (buff 32)))
    (match (map-get? client-subscription client-id)
        tier (default-to u0 (get-subscription-tier-fee tier))
        u0
    )
)

;; -------------------------------------------------------------------
;;                           MIGRATION SUPPORT
;; -------------------------------------------------------------------
;; A dedicated migration contract can seed state via these helpers.

(define-private (assert-migration-authorized)
  (begin
    (asserts! (not (var-get migration-complete)) ERR_MIGRATION_LOCKED)
    (asserts! (is-some (var-get migration-writer)) ERR_MIGRATION_NOT_SET)
    (asserts!
      (is-eq (var-get migration-writer) (some contract-caller))
      ERR_UNAUTHORIZED_CALLER
    )
    (ok true)
  )
)

;; One-time authorization for a migration contract (Cofund admin only)
(define-public (set-migration-writer (migration principal))
  (begin
    (asserts! (is-some (map-get? cofund-admins tx-sender))
      ERR_UNAUTHORIZED_CALLER
    )
    (asserts! (is-none (var-get migration-writer))
      ERR_MIGRATION_ALREADY_SET
    )
    (var-set migration-writer (some migration))
    (ok true)
  )
)

;; Seed a client with optional tier and admin count
(define-public (migration-set-client
    (client-id (buff 32))
    (tier (optional (string-ascii 32)))
    (admin-count (optional uint))
  )
  (begin
    (try! (assert-migration-authorized))
    (map-set client client-id true)
    (match tier t (map-set client-subscription client-id t) true)
    (match admin-count c (map-set active-admins client-id c) true)
    (ok true)
  )
)

;; Seed or update client subscription tier directly
(define-public (migration-set-client-subscription (client-id (buff 32)) (tier (string-ascii 32)))
  (begin
    (try! (assert-migration-authorized))
    (map-set client-subscription client-id tier)
    (ok true)
  )
)

;; Seed or update the active admin counter for a client
(define-public (migration-set-active-admins (client-id (buff 32)) (count uint))
  (begin
    (try! (assert-migration-authorized))
    (map-set active-admins client-id count)
    (ok true)
  )
)

;; Seed a user and its reverse lookups
(define-public (migration-set-user
    (client-id (buff 32))
    (user-id (string-ascii 64))
    (address principal)
    (key (buff 33))
    (position (string-ascii 128))
    (active bool)
    (is-admin bool)
  )
  (begin
    (try! (assert-migration-authorized))
    (map-set users {
      client-id: client-id,
      user-id: user-id,
    } {
      address: address,
      key: key,
      position: position,
      active: active,
      is-admin: is-admin,
    })
    (map-set users-by-address address {
      client-id: client-id,
      user-id: user-id,
    })
    (map-set users-by-key key {
      client-id: client-id,
      user-id: user-id,
    })
    (ok true)
  )
)

;; Seed a policy directly
(define-public (migration-set-policy
    (client-id (buff 32))
    (policy-id (string-ascii 64))
    (active bool)
    (policy-title (string-ascii 128))
    (policy-type (string-ascii 128))
    (policy-signers (list 35 (buff 33)))
    (policy-threshold uint)
    (policy-transaction (optional {
      wrapper: principal,
      function: (string-ascii 32),
    }))
    (policy-transfer (optional {
      max-amount: uint,
      token: principal,
      recipients: (optional (list 50 principal)),
    }))
  )
  (begin
    (try! (assert-migration-authorized))
    (map-set policies {
      client-id: client-id,
      policy: policy-id,
    } {
      active: active,
      title: policy-title,
      type: policy-type,
      signers: policy-signers,
      threshold: policy-threshold,
      transaction: policy-transaction,
      transfer: policy-transfer,
    })
    (ok true)
  )
)

;; Seed policy types (used for late additions during migration)
(define-public (migration-set-policy-type (type (string-ascii 128)))
  (begin
    (try! (assert-migration-authorized))
    (map-set cofund-policy-types type true)
    (ok true)
  )
)

;; One-way lock after migration is complete
(define-public (complete-migration)
  (begin
    (asserts! (is-eq (var-get migration-writer) (some contract-caller))
      ERR_UNAUTHORIZED_CALLER
    )
    (var-set migration-complete true)
    (ok true)
  )
)

;; policy functions
;; activate-policy
;; This function activates a new policy for a given client ID. Each policy is one of two types: transaction or transfer.
;; @param client-id; The client's ID
;; @param caller-id; The caller's ID
;; @param policy-id; The new policy's ID
;; @param policy-type; The policy's type
;; @param policy-signers; The signer set for this policy
;; @param policy-threshold; The threshold for this policy
;; @param policy-transaction; The transaction optional tuple used for generic transactions
;; @param policy-transfer; The transfer optional tuple used for SIP10 token transfers
(define-public (activate-policy
        (client-id (buff 32))
        (caller-id (string-ascii 64))
        (policy-id (string-ascii 64))
        (policy-title (string-ascii 128))
        (policy-type (string-ascii 128))
        (policy-signers (list 35 (buff 33)))
        (policy-threshold uint)
        (policy-transaction (optional {
            wrapper: principal,
            function: (string-ascii 32),
        }))
        (policy-transfer (optional {
            max-amount: uint,
            token: principal,
            recipients: (optional (list 50 principal)),
        }))
    )
    (let ((caller (unwrap! (get-user client-id caller-id) ERR_INVALID_USER)))
        ;; Protocol check
        (asserts!
            (is-eq (some contract-caller) (map-get? helper-contracts "policies"))
            ERR_UNAUTHORIZED_CALLER
        )
        ;; Check that caller is active
        (asserts! (get active caller) ERR_INACTIVE_USER)
        ;; Check that tx-sender is user-id & is an admin
        (asserts!
            (and (is-eq tx-sender (get address caller)) (get is-admin caller))
            ERR_UNAUTHORIZED_USER
        )
        ;; Check that policy is not already active
        (asserts!
            (is-none (map-get? policies {
                client-id: client-id,
                policy: policy-id,
            }))
            ERR_POLICY_REPLAY
        )
        ;; Check that policy type is supported
        (asserts! (is-some (map-get? cofund-policy-types policy-type))
            ERR_INVALID_POLICY
        )
        ;; Activate policy
        (map-set policies {
            client-id: client-id,
            policy: policy-id,
        } {
            active: true,
            title: policy-title,
            type: policy-type,
            signers: policy-signers,
            threshold: policy-threshold,
            transaction: policy-transaction,
            transfer: policy-transfer,
        })
        (print {
            topic: "Policy Activated",
            client-id: client-id,
            policy-id: policy-id,
        })
        (ok true)
    )
)
;; deactivate-policy
;; This function deactivates an active policy for a given client ID.
;; @param client-id; The client's ID
;; @param caller-id; The caller's ID
;; @param policy-id; The policy's ID
(define-public (deactivate-policy
        (client-id (buff 32))
        (caller-id (string-ascii 64))
        (policy-id (string-ascii 64))
    )
    (let (
            (caller (unwrap! (get-user client-id caller-id) ERR_INVALID_USER))
            (policy (unwrap! (get-policy client-id policy-id) ERR_INVALID_POLICY))
        )
        ;; Protocol check
        (asserts!
            (is-eq (some contract-caller) (map-get? helper-contracts "policies"))
            ERR_UNAUTHORIZED_CALLER
        )
        ;; Check that caller is active
        (asserts! (get active caller) ERR_INACTIVE_USER)
        ;; Check that tx-sender is user-id & is an admin
        (asserts!
            (and (is-eq tx-sender (get address caller)) (get is-admin caller))
            ERR_UNAUTHORIZED_USER
        )
        ;; Deactivate policy
        (map-set policies {
            client-id: client-id,
            policy: policy-id,
        }
            (merge policy { active: false })
        )
        (print {
            topic: "Policy Deactivated",
            client-id: client-id,
            policy-id: policy-id,
        })
        (ok true)
    )
)
;; user functions
;; add-user-invite
;; This function adds a new user invite to the invites map. The invite is used to add a new user to the vault
;; that expires after a certain height (~1 hr).
;; @param client-id; The client's ID
;; @param invite-hash; The invite hash
;; @param new-user-id; The new user's ID
;; @param new-user-position; The new user's position
(define-public (add-user-invite
        (client-id (buff 32))
        (caller-id (string-ascii 64))
        (invite-hash (buff 32))
        (new-user-id (string-ascii 64))
        (new-user-position (string-ascii 128))
        (new-user-is-admin bool)
    )
    (let ((caller (unwrap! (get-user client-id caller-id) ERR_INVALID_USER)))
        ;; Protocol check
        (asserts!
            (is-eq (some contract-caller) (map-get? helper-contracts "users"))
            ERR_UNAUTHORIZED_CALLER
        )
        ;; Check that caller is active
        (asserts! (get active caller) ERR_INACTIVE_USER)
        ;; If adding an admin, caller must also be an admin
        (asserts! (or (not new-user-is-admin) (get is-admin caller)) ERR_UNAUTHORIZED_USER)
        ;; Check that new user id does not exist
        (asserts! (is-none (get-user client-id new-user-id)) ERR_USER_EXISTS)
        ;; Check that invite hash does not exist
        (asserts! (is-none (get-invite client-id invite-hash)) ERR_INVITE_EXISTS)
        ;; Add invite-hash
        (map-set invites {
            client-id: client-id,
            invite-hash: invite-hash,
        } {
            activated: false,
            is-admin: new-user-is-admin,
            user-id: new-user-id,
            user-position: new-user-position,
            expire-height: (+ burn-block-height u144),
        })
        ;; Print outcome
        (print {
            topic: "Invite Added",
            client-id: client-id,
            invite-hash: invite-hash,
            new-user-id: new-user-id,
            new-user-position: new-user-position,
        })
        (ok true)
    )
)
;; add-user-invite-complete
;; This function completes the user invite process by adding the new user to the users map.
;; @param client-id; The client's ID
;; @param invite-hash; The invite hash
;; @param invite-preimage-id; The invite preimage ID
;; @param new-user-key; The new user's key
(define-public (add-user-invite-complete
        (client-id (buff 32))
        (invite-hash (buff 32))
        (invite-preimage-id uint)
        (new-user-key (buff 33))
    )
    (let ((invite (unwrap! (get-invite client-id invite-hash) ERR_INVALID_INVITE)))
        ;; Protocol check
        (asserts!
            (is-eq (some contract-caller) (map-get? helper-contracts "users"))
            ERR_UNAUTHORIZED_CALLER
        )
        ;; Check that address isn't already registered anywhere
        (asserts! (is-none (get-user-id-by-address tx-sender)) ERR_ADDRESS_EXISTS)
        ;; Check that key isn't already registered anywhere
        (asserts! (is-none (get-user-id-by-key new-user-key)) ERR_KEY_EXISTS)
        ;; Check that invite has not been activated
        (asserts! (not (get activated invite)) ERR_INVITE_REPLAY)
        ;; Check that invite has not expired
        (asserts! (<= burn-block-height (get expire-height invite))
            ERR_INVITE_EXPIRED
        )
        ;; Check hashed preimage against invite-hash
        (asserts!
            (is-eq
                (sha256 (concat
                    (sha256 (unwrap-panic (to-consensus-buff? invite-preimage-id)))
                    (sha256 (unwrap-panic (to-consensus-buff? client-id)))
                ))
                invite-hash
            )
            ERR_INVALID_PREIMAGE
        )
        ;; Update users map
        (map-set users {
            client-id: client-id,
            user-id: (get user-id invite),
        } {
            address: tx-sender,
            key: new-user-key,
            position: (get user-position invite),
            active: true,
            is-admin: (get is-admin invite),
        })
        ;; If new user is an admin, increment active-admins counter
        (if (get is-admin invite)
            (map-set active-admins client-id
                (+ (default-to u0 (get-active-admins client-id)) u1)
            )
            true
        )
        ;; Update users-by-address map
        (map-set users-by-address tx-sender {
            client-id: client-id,
            user-id: (get user-id invite),
        })
        ;; Update users-by-key map
        (map-set users-by-key new-user-key {
            client-id: client-id,
            user-id: (get user-id invite),
        })
        ;; Update invites map
        (map-set invites {
            client-id: client-id,
            invite-hash: invite-hash,
        }
            (merge invite { activated: true })
        )
        (print {
            topic: "Invite Completed",
            client-id: client-id,
            invite-hash: invite-hash,
            new-user-address: tx-sender,
            new-user-key: new-user-key,
        })
        (ok true)
    )
)
;; remove-user
;; This function removes a user from the users map. Only admins can remove users.
;; @param client-id; The client's ID
;; @param user-id; The caller's ID
;; @param removed-user-id; The removed user's ID
;; @param valid-signatures; An optional number of valid signatures (only required for removing admins)
(define-public (remove-user
        (client-id (buff 32))
        (user-id (string-ascii 64))
        (removed-user-id (string-ascii 64))
        (valid-signatures (optional uint))
    )
    (let (
            (caller (unwrap! (get-user client-id user-id) ERR_INVALID_USER))
            (removed-user (unwrap! (get-user client-id removed-user-id) ERR_INVALID_USER))
        )
        ;; Protocol check
        (asserts!
            (is-eq (some contract-caller) (map-get? helper-contracts "users"))
            ERR_UNAUTHORIZED_CALLER
        )
        ;; Check that caller is active
        (asserts! (get active caller) ERR_INACTIVE_USER)
        ;; Check that tx-sender is user-id & is an admin
        (asserts!
            (and (is-eq tx-sender (get address caller)) (get is-admin caller))
            ERR_UNAUTHORIZED_USER
        )
        ;; Check if attemping to remove admin or user
        (match valid-signatures
            signatures-verified (begin
                ;; Verify that removed-user is an admin
                (asserts! (get is-admin removed-user) ERR_INVALID_POSITION)
                ;; Get and validate active admins count, then decrement
                (let ((admin-count (unwrap! (get-active-admins client-id) ERR_MIN_ADMINS)))
                    ;; Check active admins greater than 2 (can never be 1 or 0)
                    (asserts! (>= admin-count u2) ERR_MIN_ADMINS)
                    ;; Decrement active-admins counter
                    (map-set active-admins client-id (- admin-count u1))
                )
            )
            (asserts! (not (get is-admin removed-user)) ERR_INVALID_POSITION)
        )
        ;; Update users map
        (map-set users {
            client-id: client-id,
            user-id: removed-user-id,
        }
            (merge removed-user { active: false })
        )
        (print {
            topic: "User Removed",
            client-id: client-id,
            user-id: user-id,
            removed-user-id: removed-user-id,
        })
        (ok true)
    )
)
;; rotate-user
;; This function rotates a user's address & key. Only admins can rotate users.
;; @param client-id; The client's ID
;; @param caller-id; The caller's ID
;; @param user-id; The user's ID
;; @param new-address; The new address for the user
;; @param new-key; The new key for the user
;; @param valid-signatures; An optional number of valid signatures (only required for rotating admins)
(define-public (rotate-user
        (client-id (buff 32))
        (caller-id (string-ascii 64))
        (user-id (string-ascii 64))
        (new-address principal)
        (new-key (buff 33))
        (valid-signatures (optional uint))
    )
    (let (
            (caller (unwrap! (get-user client-id caller-id) ERR_INVALID_USER))
            (rotated-user (unwrap! (get-user client-id user-id) ERR_INVALID_USER))
        )
        ;; Protocol check
        (asserts!
            (is-eq (some contract-caller) (map-get? helper-contracts "users"))
            ERR_UNAUTHORIZED_CALLER
        )
        ;; Check that caller is active
        (asserts! (get active caller) ERR_INACTIVE_USER)
        ;; Check that tx-sender is user-id & is an admin
        (asserts!
            (and (is-eq tx-sender (get address caller)) (get is-admin caller))
            ERR_UNAUTHORIZED_USER
        )
        ;; Check that new address does not exist
        (asserts! (is-none (get-user-id-by-address new-address))
            ERR_ADDRESS_EXISTS
        )
        ;; Check that new key does not exist
        (asserts! (is-none (get-user-id-by-key new-key)) ERR_KEY_EXISTS)
        ;; Extra check if rotating admin
        (match valid-signatures
            signatures-verified
            ;; Verify that rotated-user is an admin
            (asserts! (get is-admin rotated-user) ERR_INVALID_POSITION)
            (asserts! (not (get is-admin rotated-user)) ERR_INVALID_POSITION)
        )
        ;; Remove old reverse mappings
        (map-delete users-by-address (get address rotated-user))
        (map-delete users-by-key (get key rotated-user))
        ;; Update users-by-key map
        (map-set users-by-key new-key {
            client-id: client-id,
            user-id: user-id,
        })
        ;; Update users-by-address map
        (map-set users-by-address new-address {
            client-id: client-id,
            user-id: user-id,
        })
        ;; Update users map
        (map-set users {
            client-id: client-id,
            user-id: user-id,
        }
            (merge rotated-user {
                address: new-address,
                key: new-key,
            })
        )
        (print {
            topic: "User Key Rotated",
            client-id: client-id,
            user-id: user-id,
            new-key: new-key,
        })
        (ok true)
    )
)
;; set auth-id
;; This function updates the 'auth-ids' map so that signatures can't be replayed
(define-public (set-auth-id
        (client-id (buff 32))
        (contract-name (string-ascii 128))
        (auth-id (string-ascii 64))
    )
    (begin
        ;; Check that calling contract is either an active client vault or a helper contract
        (if (is-eq contract-name "vault")
            ;; Check that caller is either an active user in client or a cofund admin
            (asserts! (or 
                ;; Check that caller is an active user in client
                (is-eq (get client-id (unwrap! (map-get? users-by-address tx-sender) ERR_INVALID_USER)) client-id)
                ;; Check that caller is a cofund admin
                (is-some (map-get? cofund-admins tx-sender))) 
            ERR_INVALID_CONTRACT_ADDRESS)
            ;; Check that caller is a helper contract
            (asserts! (is-eq (unwrap! (map-get? helper-contracts contract-name) ERR_INVALID_CONTRACT_NAME) contract-caller) ERR_INVALID_CONTRACT_ADDRESS)
        )
        ;; update 'auth-ids' map
        (map-insert auth-ids {
            client-id: client-id,
            contract: contract-caller,
            auth-id: auth-id,
        }
            true
        )
        (ok true)
    )
)

;; Cofund admin functions
;; new-client
;; This function adds a new client to the helper-contracts map & creates an invite for 
;; the first admin currently registering.
;; @param client-id; The client's ID
;; @param invite-hash; The invite hash
;; @param new-user-id; The new user's ID
(define-public (new-client
        (client-id (buff 32))
        (invite-hash (buff 32))
        (admin-id (string-ascii 64))
        (client-tier (string-ascii 32))
    )
    (begin
        ;; Check that caller is a cofund admin
        (asserts! (is-some (map-get? cofund-admins tx-sender))
            ERR_UNAUTHORIZED_CALLER
        )
        ;; Check that tier exists
        (asserts! (is-some (map-get? subscription-tiers client-tier)) ERR_INVALID_TIER)
        ;; Check that client-id does not exist
        (asserts! (is-none (get-invite client-id invite-hash)) ERR_INVALID_INVITE)
        ;; Create new client
        (map-insert client client-id true)
        ;; Set client subscription tier
        (map-set client-subscription client-id client-tier)
        ;; Create new invite
        (map-set invites {
            client-id: client-id,
            invite-hash: invite-hash,
        } {
            activated: false,
            is-admin: true,
            user-id: admin-id,
            user-position: "admin",
            ;; TODO: Update to correct height (for testing purposes left at 600 bitcoin blocks)
            expire-height: (+ burn-block-height u600),
        })
        (print {
            topic: "New Client Created",
            client-id: client-id,
            invite-hash: invite-hash,
            tier: client-tier,
        })
        (ok true)
    )
)
;; add-policy-type
;; This function adds Cofund-supported policy types
;; @param type-name; The supported type name
(define-public (add-policy-type (type (string-ascii 128)))
    (begin
        ;; Check that caller is a cofund admin
        (asserts! (is-some (map-get? cofund-admins tx-sender))
            ERR_UNAUTHORIZED_CALLER
        )
        ;; Insert policy type into cofund-policy-types
        (map-set cofund-policy-types type true)
        (print {
            topic: "New Policy Type Created",
            policy-type: type,
        })
        (ok true)
    )
)

;; set-helper-contract
;; This function updates a helper contract address (Cofund admin only)
;; @param contract-type; The helper contract type (e.g., "users", "policies", "gov")
;; @param contract-address; The new contract address
(define-public (set-helper-contract (contract-type (string-ascii 128)) (contract-address principal))
    (begin
        ;; Check that caller is a cofund admin
        (asserts! (is-some (map-get? cofund-admins tx-sender))
            ERR_UNAUTHORIZED_CALLER
        )
        ;; Validate contract-type is not empty
        (asserts! (> (len contract-type) u0) ERR_INVALID_CONTRACT_NAME)
        (map-set helper-contracts contract-type contract-address)
        (print {
            topic: "Helper Contract Updated",
            contract-type: contract-type,
            contract-address: contract-address,
        })
        (ok true)
    )
)

;; Subscription tier management functions
;; set-fee-recipient-address
;; This function updates the fee recipient address (Cofund admin only)
;; @param new-recipient; The new fee recipient address
(define-public (set-fee-recipient-address (new-recipient principal))
    (begin
        ;; Check that caller is a cofund admin
        (asserts! (is-some (map-get? cofund-admins tx-sender))
            ERR_UNAUTHORIZED_CALLER
        )
        (var-set cf-fee-recipient new-recipient)
        (print {
            topic: "Fee Recipient Updated",
            new-recipient: new-recipient,
        })
        (ok true)
    )
)

;; set-subscription-tier
;; This function creates or updates a subscription tier (Cofund admin only)
;; @param tier; The tier name
;; @param fee-bps; The fee in basis points (max 1000 = 10%)
(define-public (set-subscription-tier (tier (string-ascii 32)) (fee-bps uint))
    (begin
        ;; Check that caller is a cofund admin
        (asserts! (is-some (map-get? cofund-admins tx-sender))
            ERR_UNAUTHORIZED_CALLER
        )
        ;; Validate tier name is not empty
        (asserts! (> (len tier) u0) ERR_EMPTY_TIER_NAME)
        ;; Validate fee is within reasonable bounds (max 10%)
        (asserts! (<= fee-bps u1000) ERR_FEE_TOO_HIGH)
        (map-set subscription-tiers tier fee-bps)
        (print {
            topic: "Subscription Tier Updated",
            tier: tier,
            fee-bps: fee-bps,
        })
        (ok true)
    )
)

;; set-client-subscription-tier
;; This function assigns a subscription tier to a client (Cofund admin only)
;; @param client-id; The client's ID
;; @param tier; The tier name to assign
(define-public (set-client-subscription-tier (client-id (buff 32)) (tier (string-ascii 32)))
    (begin
        ;; Check that caller is a cofund admin
        (asserts! (is-some (map-get? cofund-admins tx-sender))
            ERR_UNAUTHORIZED_CALLER
        )
        ;; Check that client exists
        (asserts! (is-some (map-get? client client-id)) ERR_INVALID_CLIENT)
        ;; Check that tier exists
        (asserts! (is-some (map-get? subscription-tiers tier)) ERR_INVALID_TIER)
        (map-set client-subscription client-id tier)
        (print {
            topic: "Client Tier Updated",
            client-id: client-id,
            tier: tier,
        })
        (ok true)
    )
)

;; TEST DATA START - For development/testing only
;; =====================================================================================
;; testco client registration
(map-insert client 0x16cbd0716887fd9259f39d403e19eb3436e3bdf3c17a37035cf0f8f0d7851e0b true)

;; testco policy 0 (transfer)
(map-set policies {
    client-id: 0x16cbd0716887fd9259f39d403e19eb3436e3bdf3c17a37035cf0f8f0d7851e0b,
    policy: "0",
} {
    active: true,
    title: "Test Payroll Policy",
    type: "Contractor_Stipend",
    signers: (list
        0x0390a5cac7c33fda49f70bc1b0866fa0ba7a9440d9de647fecb8132ceb76a94dfa
        0x03cd2cfdbd2ad9332828a7a13ef62cb999e063421c708e863a7ffed71fb61c88c9
    ),
    threshold: u2,
    transaction: none,
    transfer: (some {
        max-amount: u100000000,
        token: .sbtc-token-mock,
        recipients: none,
    }),
})
;; testco policy 1 (transaction)
(map-set policies {
    client-id: 0x16cbd0716887fd9259f39d403e19eb3436e3bdf3c17a37035cf0f8f0d7851e0b,
    policy: "1",
} {
    active: true,
    title: "Add To Balance Sheet",
    type: "Crypto_Deposit",
    signers: (list
        0x0390a5cac7c33fda49f70bc1b0866fa0ba7a9440d9de647fecb8132ceb76a94dfa
        0x03cd2cfdbd2ad9332828a7a13ef62cb999e063421c708e863a7ffed71fb61c88c9
    ),
    threshold: u2,
    transaction: (some {
        wrapper: .cf-wrappers-foobar-defi-v0,
        function: "mint-token",
    }),
    transfer: none,
})
(map-set policies {
    client-id: 0x16cbd0716887fd9259f39d403e19eb3436e3bdf3c17a37035cf0f8f0d7851e0b,
    policy: "2",
} {
    active: true,
    title: "Test Crypto Onramp",
    type: "Crypto_Onramp",
    signers: (list
        0x0390a5cac7c33fda49f70bc1b0866fa0ba7a9440d9de647fecb8132ceb76a94dfa
        0x03cd2cfdbd2ad9332828a7a13ef62cb999e063421c708e863a7ffed71fb61c88c9
    ),
    threshold: u2,
    transaction: none,
    transfer: (some {
        max-amount: u100000000,
        token: .sbtc-token-mock,
        recipients: (some (list tx-sender)),
    }),
})
;; testco user 0 (admin)
(map-set users {
    client-id: 0x16cbd0716887fd9259f39d403e19eb3436e3bdf3c17a37035cf0f8f0d7851e0b,
    user-id: "0",
} {
    address: tx-sender,
    key: 0x0390a5cac7c33fda49f70bc1b0866fa0ba7a9440d9de647fecb8132ceb76a94dfa,
    position: "admin",
    active: true,
    is-admin: true,
})
(map-set users-by-address tx-sender {
    client-id: 0x16cbd0716887fd9259f39d403e19eb3436e3bdf3c17a37035cf0f8f0d7851e0b,
    user-id: "0",
})
(map-set users-by-key
    0x0390a5cac7c33fda49f70bc1b0866fa0ba7a9440d9de647fecb8132ceb76a94dfa {
    client-id: 0x16cbd0716887fd9259f39d403e19eb3436e3bdf3c17a37035cf0f8f0d7851e0b,
    user-id: "0",
})
(map-set active-admins
    0x16cbd0716887fd9259f39d403e19eb3436e3bdf3c17a37035cf0f8f0d7851e0b u1
)
;; testco user 1 (employee - non-admin for testing)
(map-set users {
    client-id: 0x16cbd0716887fd9259f39d403e19eb3436e3bdf3c17a37035cf0f8f0d7851e0b,
    user-id: "1",
} {
    address: 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5,
    key: 0x03cd2cfdbd2ad9332828a7a13ef62cb999e063421c708e863a7ffed71fb61c88c9,
    position: "employee",
    active: true,
    is-admin: false,
})
(map-set users-by-address 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5 {
    client-id: 0x16cbd0716887fd9259f39d403e19eb3436e3bdf3c17a37035cf0f8f0d7851e0b,
    user-id: "1",
})
(map-set users-by-key
    0x03cd2cfdbd2ad9332828a7a13ef62cb999e063421c708e863a7ffed71fb61c88c9 {
    client-id: 0x16cbd0716887fd9259f39d403e19eb3436e3bdf3c17a37035cf0f8f0d7851e0b,
    user-id: "1",
})
;; testco subscription tier (FREE tier for testing)
(map-set client-subscription
    0x16cbd0716887fd9259f39d403e19eb3436e3bdf3c17a37035cf0f8f0d7851e0b
    "FREE"
)
;; =====================================================================================
;; TEST DATA END
;; =====================================================================================

