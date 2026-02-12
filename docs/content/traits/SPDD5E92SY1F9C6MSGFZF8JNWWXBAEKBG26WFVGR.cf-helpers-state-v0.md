---
title: "Trait cf-helpers-state-v0"
draft: true
---
```
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

;; Initialize default subscription tiers
(map-set subscription-tiers "FREE" u250)      ;; 2.5%
(map-set subscription-tiers "TEAM" u125)      ;; 1.25%
(map-set subscription-tiers "BUSINESS" u0)    ;; 0%

;; TODO: MAINNET - Remove all test data below (lines until "read-only functions" comment)
;; =====================================================================================
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

;; TODO: MAINNET - Review and remove migration data below if not needed
;; =====================================================================================
;; MIGRATION DATA (already commented out) - Review before mainnet deployment
;; =====================================================================================
;; COFUND State Migration - ORGANIZED BY CLIENT
;; Generated: 2025-12-31T17:18:37.375Z
;; Source: SP3EDVXPRGV4QFAAKJSHN0MFD2T0DAFW9ZZMXJWKH

;; CLIENT 1: cf-vault-setdevv6-v0
;; ID: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
;; Users: 19 | Admins: 4 | Policies: 24

;; --- Client Registration ---
(map-set client 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc true)

;; --- Active Admin Count ---
(map-set active-admins 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc u4)

;; --- Users (19) ---
;; Lead Engineer [ADMIN]
(map-set users {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "7396c57d-142b-4347-8180-0c0b088c0cfc"}
  {address: 'SP3ASDZZ5CKTK48KY8JEKXW93CD9J28GXG6C2A86T, key: 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9, position: "Lead Engineer", active: true, is-admin: true})
;; Frontend Engineer
(map-set users {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "e0503057-61f5-445d-9c36-30949002389b"}
  {address: 'SPBG14D0PB8AW404D9HV2T8MTNTZ7TWGVNHGPC51, key: 0x0268a54270b0853683a82fd296c4eba7f8d026dfe1f0cef8501ab5326ed52c7da2, position: "Frontend Engineer", active: true, is-admin: false})
;; Founder [ADMIN]
(map-set users {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "095007f6-1d21-409f-8ab8-ccfe7d50fb2a"}
  {address: 'SP13C2S8A51CM80V0D6KKMAJBQ6H85ZG05XD8FSDD, key: 0x03eb66f287acce5e54b947773f9749f4f1b1db05c2a1c911b0ce11d29b1949edf7, position: "Founder", active: true, is-admin: true})
;; Software Engineer
(map-set users {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "9447d49f-c0d5-4531-af68-e5b393619fe0"}
  {address: 'SP361WPGWE4G7V4YBE68RA6H4T62MVZ59KP7TV83S, key: 0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7, position: "Software Engineer", active: true, is-admin: false})
;; Bitcoin Engineer
(map-set users {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "c0f9af8c-d6c1-4917-ab69-04d39c3801f9"}
  {address: 'SPSEWYZPPNBNYSATD6NX39DA9D741RPY3DQ62H38, key: 0x0389b7269733631ee0bbb1a8fedb1b697fde2db82c5897b2df5bee799369594f85, position: "Bitcoin Engineer", active: true, is-admin: false})
;; Business Analyst
(map-set users {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "4bf86105-b1a8-4045-bf9f-ae180f5fe3c5"}
  {address: 'SP12MYRAZ3AMT5DRYEGR6TCHHZYAJ38NW362W821K, key: 0x024627db4edbcb542f34fd08abdc3ef8b451030f176efba4dce1eb055d6fad7ff1, position: "Business Analyst", active: true, is-admin: false})
;; Software Engineer
(map-set users {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "805052fa-a009-4243-a82d-93fcdba68132"}
  {address: 'SP2RBX2BSCRFRCC5G6H7ESSK9M9JZZEC7ANKKKXC, key: 0x030fcee6b52058c589458c4b95d886985202cc6be9b6fa3d3d4d8bc947cab7ba1c, position: "Software Engineer", active: true, is-admin: false})
;; Tester
(map-set users {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "0ab51ca7-48bb-4aec-84f2-c880eed8e6a4"}
  {address: 'SP1FTZ7DTK7K3C28F63D6W1TVF5P7TDWHR69D6K2H, key: 0x02da41c589793234b59861bc2f607bf1d268384762a568b2e6fb48127615cc3e30, position: "Tester", active: true, is-admin: false})
;; Bitcoin Engineer
(map-set users {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "7b57dd34-ca7c-4cb6-b31a-60c89398d1d8"}
  {address: 'SP2K1ZPKB5J1DYYW0SYJQQ5MF4EZQKES2Q056673K, key: 0x020471d94d1876bb256bb897e3ff369000d9698fbe767c46e7f92827e40bc3c9b2, position: "Bitcoin Engineer", active: true, is-admin: false})
;; Tester
(map-set users {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "9501201a-6d55-4b19-8697-927026d6d19c"}
  {address: 'SP33PJ63KJTP1MDDKYJEM02D7SKJP148YS97Y6S93, key: 0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c, position: "Tester", active: true, is-admin: false})
;; Tester
(map-set users {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "5420d656-e72a-4af6-b221-08bb1a41de24"}
  {address: 'SP17A0ND1QF0YY2G77NGZRWCKAP9RGTSCBH9H87ZM, key: 0x029326adc1c69b92c2101ba44c5d8cacdffa29f534e017b3f7a8f3e06351524a10, position: "Tester", active: true, is-admin: false})
;; Tester
(map-set users {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "335ba3f7-fa4d-481a-ac48-36eadb1c81d0"}
  {address: 'SP20F2DEMEV7VCDQD3Q3E4PFZ44NRW86833DBKEVE, key: 0x027a794d285733aa672657e808213930d0fc410c41952e014df299ee6e94ff2f43, position: "Tester", active: true, is-admin: false})
;; Smart Contract Engineer
(map-set users {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "6dba8d80-534e-439c-b375-fb4bf7d3402c"}
  {address: 'SP3RG4WRZKKD51JYS8R3JZFGCKE4D8NFYNF6CP7T6, key: 0x0315f9bd5dbcee6b166bac1f90eef0326aac6e1f9161bcc857647f49409e29ff96, position: "Smart Contract Engineer", active: true, is-admin: false})
;; Business Analyst
(map-set users {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "2e3c609b-ead8-4003-8fdf-f11267ecf243"}
  {address: 'SP2AR14D4DK2B8XCV9TYY5RRAE7JTKXF8NB614EZV, key: 0x03c009052c203d8c3eb605067e7956373a6cd94e1ce94e8e00efdc1ed14ffd2103, position: "Business Analyst", active: true, is-admin: false})
;; Tester
(map-set users {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "848ebbab-79ce-4d22-8e36-d4324b8a8d6a"}
  {address: 'SPWNGYG35C5PDD2VQMTAC4R3QWRH7SYS29H26M45, key: 0x0270a962de549b589f958335816ba5e31963a75c81bb1f91b3e31002dd9ed8dedd, position: "Tester", active: true, is-admin: false})
;; Accountant [ADMIN]
(map-set users {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "bcff2432-3f23-490d-8431-e43d0a664da3"}
  {address: 'SP1QXXDDC3SCSZ79QS31VNBDAMP0NWW8PCTBBAYJY, key: 0x02171bd62c7aa710d110c786fd613f13b8793332719f3efdf9cfb4f0536f78f69c, position: "Accountant", active: true, is-admin: true})
;; testing Sspecialist
(map-set users {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "4e2ad508-9827-41ae-9dc0-35c588ffe45f"}
  {address: 'SP1QXXDDC3SCSZ79QS31VNBDAMP0NWW8PCTBBAYJY, key: 0x02171bd62c7aa710d110c786fd613f13b8793332719f3efdf9cfb4f0536f78f69c, position: "testing Sspecialist", active: true, is-admin: false})
;; Marketing Specialist [ADMIN]
(map-set users {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "56461f7c-04e6-459b-849f-c330093e730c"}
  {address: 'SP3CXGZ7RFQXEWRS18AKS6PJK1BEGH0DFXDM9FR52, key: 0x02e76eabaa2745e2c6fdab2ca19e176d278dadde2dba7ab576e0b52df556129448, position: "Marketing Specialist", active: true, is-admin: true})
;; Brand Director
(map-set users {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "016ffdc6-2673-4173-9f43-0a189fae3a28"}
  {address: 'SP33PJ63KJTP1MDDKYJEM02D7SKJP148YS97Y6S93, key: 0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c, position: "Brand Director", active: true, is-admin: false})

;; --- Users by Address ---
(map-set users-by-address 'SP3ASDZZ5CKTK48KY8JEKXW93CD9J28GXG6C2A86T {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "7396c57d-142b-4347-8180-0c0b088c0cfc"})
(map-set users-by-address 'SPBG14D0PB8AW404D9HV2T8MTNTZ7TWGVNHGPC51 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "e0503057-61f5-445d-9c36-30949002389b"})
(map-set users-by-address 'SP13C2S8A51CM80V0D6KKMAJBQ6H85ZG05XD8FSDD {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "095007f6-1d21-409f-8ab8-ccfe7d50fb2a"})
(map-set users-by-address 'SP361WPGWE4G7V4YBE68RA6H4T62MVZ59KP7TV83S {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "9447d49f-c0d5-4531-af68-e5b393619fe0"})
(map-set users-by-address 'SPSEWYZPPNBNYSATD6NX39DA9D741RPY3DQ62H38 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "c0f9af8c-d6c1-4917-ab69-04d39c3801f9"})
(map-set users-by-address 'SP12MYRAZ3AMT5DRYEGR6TCHHZYAJ38NW362W821K {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "4bf86105-b1a8-4045-bf9f-ae180f5fe3c5"})
(map-set users-by-address 'SP2RBX2BSCRFRCC5G6H7ESSK9M9JZZEC7ANKKKXC {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "805052fa-a009-4243-a82d-93fcdba68132"})
(map-set users-by-address 'SP1FTZ7DTK7K3C28F63D6W1TVF5P7TDWHR69D6K2H {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "0ab51ca7-48bb-4aec-84f2-c880eed8e6a4"})
(map-set users-by-address 'SP2K1ZPKB5J1DYYW0SYJQQ5MF4EZQKES2Q056673K {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "7b57dd34-ca7c-4cb6-b31a-60c89398d1d8"})
(map-set users-by-address 'SP33PJ63KJTP1MDDKYJEM02D7SKJP148YS97Y6S93 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "9501201a-6d55-4b19-8697-927026d6d19c"})
(map-set users-by-address 'SP17A0ND1QF0YY2G77NGZRWCKAP9RGTSCBH9H87ZM {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "5420d656-e72a-4af6-b221-08bb1a41de24"})
(map-set users-by-address 'SP20F2DEMEV7VCDQD3Q3E4PFZ44NRW86833DBKEVE {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "335ba3f7-fa4d-481a-ac48-36eadb1c81d0"})
(map-set users-by-address 'SP3RG4WRZKKD51JYS8R3JZFGCKE4D8NFYNF6CP7T6 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "6dba8d80-534e-439c-b375-fb4bf7d3402c"})
(map-set users-by-address 'SP2AR14D4DK2B8XCV9TYY5RRAE7JTKXF8NB614EZV {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "2e3c609b-ead8-4003-8fdf-f11267ecf243"})
(map-set users-by-address 'SPWNGYG35C5PDD2VQMTAC4R3QWRH7SYS29H26M45 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "848ebbab-79ce-4d22-8e36-d4324b8a8d6a"})
(map-set users-by-address 'SP1QXXDDC3SCSZ79QS31VNBDAMP0NWW8PCTBBAYJY {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "bcff2432-3f23-490d-8431-e43d0a664da3"})
(map-set users-by-address 'SP1QXXDDC3SCSZ79QS31VNBDAMP0NWW8PCTBBAYJY {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "4e2ad508-9827-41ae-9dc0-35c588ffe45f"})
(map-set users-by-address 'SP3CXGZ7RFQXEWRS18AKS6PJK1BEGH0DFXDM9FR52 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "56461f7c-04e6-459b-849f-c330093e730c"})
(map-set users-by-address 'SP33PJ63KJTP1MDDKYJEM02D7SKJP148YS97Y6S93 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "016ffdc6-2673-4173-9f43-0a189fae3a28"})

;; --- Users by Key ---
(map-set users-by-key 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "7396c57d-142b-4347-8180-0c0b088c0cfc"})
(map-set users-by-key 0x0268a54270b0853683a82fd296c4eba7f8d026dfe1f0cef8501ab5326ed52c7da2 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "e0503057-61f5-445d-9c36-30949002389b"})
(map-set users-by-key 0x03eb66f287acce5e54b947773f9749f4f1b1db05c2a1c911b0ce11d29b1949edf7 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "095007f6-1d21-409f-8ab8-ccfe7d50fb2a"})
(map-set users-by-key 0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "9447d49f-c0d5-4531-af68-e5b393619fe0"})
(map-set users-by-key 0x0389b7269733631ee0bbb1a8fedb1b697fde2db82c5897b2df5bee799369594f85 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "c0f9af8c-d6c1-4917-ab69-04d39c3801f9"})
(map-set users-by-key 0x024627db4edbcb542f34fd08abdc3ef8b451030f176efba4dce1eb055d6fad7ff1 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "4bf86105-b1a8-4045-bf9f-ae180f5fe3c5"})
(map-set users-by-key 0x030fcee6b52058c589458c4b95d886985202cc6be9b6fa3d3d4d8bc947cab7ba1c {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "805052fa-a009-4243-a82d-93fcdba68132"})
(map-set users-by-key 0x02da41c589793234b59861bc2f607bf1d268384762a568b2e6fb48127615cc3e30 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "0ab51ca7-48bb-4aec-84f2-c880eed8e6a4"})
(map-set users-by-key 0x020471d94d1876bb256bb897e3ff369000d9698fbe767c46e7f92827e40bc3c9b2 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "7b57dd34-ca7c-4cb6-b31a-60c89398d1d8"})
(map-set users-by-key 0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "9501201a-6d55-4b19-8697-927026d6d19c"})
(map-set users-by-key 0x029326adc1c69b92c2101ba44c5d8cacdffa29f534e017b3f7a8f3e06351524a10 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "5420d656-e72a-4af6-b221-08bb1a41de24"})
(map-set users-by-key 0x027a794d285733aa672657e808213930d0fc410c41952e014df299ee6e94ff2f43 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "335ba3f7-fa4d-481a-ac48-36eadb1c81d0"})
(map-set users-by-key 0x0315f9bd5dbcee6b166bac1f90eef0326aac6e1f9161bcc857647f49409e29ff96 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "6dba8d80-534e-439c-b375-fb4bf7d3402c"})
(map-set users-by-key 0x03c009052c203d8c3eb605067e7956373a6cd94e1ce94e8e00efdc1ed14ffd2103 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "2e3c609b-ead8-4003-8fdf-f11267ecf243"})
(map-set users-by-key 0x0270a962de549b589f958335816ba5e31963a75c81bb1f91b3e31002dd9ed8dedd {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "848ebbab-79ce-4d22-8e36-d4324b8a8d6a"})
(map-set users-by-key 0x02171bd62c7aa710d110c786fd613f13b8793332719f3efdf9cfb4f0536f78f69c {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "bcff2432-3f23-490d-8431-e43d0a664da3"})
(map-set users-by-key 0x02171bd62c7aa710d110c786fd613f13b8793332719f3efdf9cfb4f0536f78f69c {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "4e2ad508-9827-41ae-9dc0-35c588ffe45f"})
(map-set users-by-key 0x02e76eabaa2745e2c6fdab2ca19e176d278dadde2dba7ab576e0b52df556129448 {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "56461f7c-04e6-459b-849f-c330093e730c"})
(map-set users-by-key 0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, user-id: "016ffdc6-2673-4173-9f43-0a189fae3a28"})

;; --- Policies (24) ---
;; STX Test Deposit [TRANSACTION] - Threshold: 2/7
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "a2e6ae25-3f4b-4251-885b-7aebfb832393"}
  {active: true, title: "STX Test Deposit", type: "Crypto_Onramp", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x03eb66f287acce5e54b947773f9749f4f1b1db05c2a1c911b0ce11d29b1949edf7 0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7 0x0389b7269733631ee0bbb1a8fedb1b697fde2db82c5897b2df5bee799369594f85 0x024627db4edbcb542f34fd08abdc3ef8b451030f176efba4dce1eb055d6fad7ff1 0x030fcee6b52058c589458c4b95d886985202cc6be9b6fa3d3d4d8bc947cab7ba1c), threshold: u2, transaction: none, transfer: none})
;; Test Operational Expense [TRANSACTION] - Threshold: 2/5
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "d99f014d-047c-48e8-aeb1-282fa4acbb7a"}
  {active: true, title: "Test Operational Expense", type: "Operational_Expense", signers: (list 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x024627db4edbcb542f34fd08abdc3ef8b451030f176efba4dce1eb055d6fad7ff1 0x030fcee6b52058c589458c4b95d886985202cc6be9b6fa3d3d4d8bc947cab7ba1c 0x03eb66f287acce5e54b947773f9749f4f1b1db05c2a1c911b0ce11d29b1949edf7 0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7), threshold: u2, transaction: none, transfer: none})
;; Rijdael Reimbursement [TRANSACTION] - Threshold: 2/3
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "05c20e74-78ab-47e5-8bbe-6848697968c0"}
  {active: true, title: "Rijdael Reimbursement", type: "Operational_Expense", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x02da41c589793234b59861bc2f607bf1d268384762a568b2e6fb48127615cc3e30), threshold: u2, transaction: none, transfer: none})
;; Tiny Text Expense [TRANSACTION] - Threshold: 2/4
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "dcdcd474-b111-4a7e-b6a7-61512a8846ae"}
  {active: true, title: "Tiny Text Expense", type: "Operational_Expense", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x03eb66f287acce5e54b947773f9749f4f1b1db05c2a1c911b0ce11d29b1949edf7 0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7 0x024627db4edbcb542f34fd08abdc3ef8b451030f176efba4dce1eb055d6fad7ff1), threshold: u2, transaction: none, transfer: none})
;; Jake Deposit Test [TRANSACTION] - Threshold: 2/4
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "af9287c8-0ab9-49cb-bf00-e7494117bd83"}
  {active: true, title: "Jake Deposit Test", type: "Crypto_Onramp", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x03eb66f287acce5e54b947773f9749f4f1b1db05c2a1c911b0ce11d29b1949edf7 0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c), threshold: u2, transaction: none, transfer: none})
;; Jake Test Expense [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "74eaee08-8acf-4c85-85f0-30b28bb0fbb9"}
  {active: true, title: "Jake Test Expense", type: "Operational_Expense", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c), threshold: u2, transaction: none, transfer: none})
;; Pete Deposit Test [TRANSACTION] - Threshold: 2/4
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "0f6dc8a7-168b-4e36-ae98-dd880271b796"}
  {active: true, title: "Pete Deposit Test", type: "Crypto_Onramp", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x03eb66f287acce5e54b947773f9749f4f1b1db05c2a1c911b0ce11d29b1949edf7 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x029326adc1c69b92c2101ba44c5d8cacdffa29f534e017b3f7a8f3e06351524a10), threshold: u2, transaction: none, transfer: none})
;; Intern Stipend [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "151afd1d-6e2e-4260-8df5-39f6c89d2e47"}
  {active: true, title: "Intern Stipend", type: "Contractor_Stipend", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x029326adc1c69b92c2101ba44c5d8cacdffa29f534e017b3f7a8f3e06351524a10), threshold: u2, transaction: none, transfer: none})
;; Liquidium Test [TRANSACTION] - Threshold: 2/4
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "afdd53be-088f-49a5-bb01-b0b17fa7ab17"}
  {active: true, title: "Liquidium Test", type: "Crypto_Onramp", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x03eb66f287acce5e54b947773f9749f4f1b1db05c2a1c911b0ce11d29b1949edf7 0x027a794d285733aa672657e808213930d0fc410c41952e014df299ee6e94ff2f43), threshold: u2, transaction: none, transfer: none})
;; Liquidium Conference Expenses [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "492ce8b0-f859-4190-98bd-84c334757f89"}
  {active: true, title: "Liquidium Conference Expenses", type: "Operational_Expense", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x027a794d285733aa672657e808213930d0fc410c41952e014df299ee6e94ff2f43), threshold: u2, transaction: none, transfer: none})
;; CoreDAO Test [TRANSACTION] - Threshold: 2/6
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "a2e3a19b-cd0a-409a-bf9a-95f2739f3c10"}
  {active: true, title: "CoreDAO Test", type: "Crypto_Onramp", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x03eb66f287acce5e54b947773f9749f4f1b1db05c2a1c911b0ce11d29b1949edf7 0x024627db4edbcb542f34fd08abdc3ef8b451030f176efba4dce1eb055d6fad7ff1 0x030fcee6b52058c589458c4b95d886985202cc6be9b6fa3d3d4d8bc947cab7ba1c 0x020471d94d1876bb256bb897e3ff369000d9698fbe767c46e7f92827e40bc3c9b2), threshold: u2, transaction: none, transfer: none})
;; Hermetica Test [TRANSACTION] - Threshold: 2/4
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "1b20c90e-f1b2-40c5-9c9a-2d6068e9b36d"}
  {active: true, title: "Hermetica Test", type: "Crypto_Onramp", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x0270a962de549b589f958335816ba5e31963a75c81bb1f91b3e31002dd9ed8dedd 0x020471d94d1876bb256bb897e3ff369000d9698fbe767c46e7f92827e40bc3c9b2), threshold: u2, transaction: none, transfer: none})
;; Hermetica Expense Test [TRANSACTION] - Threshold: 2/3
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "e2e72674-07ea-4b57-8a7b-50707913c578"}
  {active: true, title: "Hermetica Expense Test", type: "Operational_Expense", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x0270a962de549b589f958335816ba5e31963a75c81bb1f91b3e31002dd9ed8dedd), threshold: u2, transaction: none, transfer: none})
;; Bitflow Signup Discount [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "ce8ebdfc-9955-45c5-b5a7-3f8c7adca7a9"}
  {active: true, title: "Bitflow Signup Discount", type: "Business_Invoice", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9), threshold: u2, transaction: none, transfer: none})
;; Metalend Testing [TRANSACTION] - Threshold: 3/4
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "466c0723-9331-47ed-beac-75ce4597eed6"}
  {active: true, title: "Metalend Testing", type: "Operational_Expense", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x0270a962de549b589f958335816ba5e31963a75c81bb1f91b3e31002dd9ed8dedd 0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7), threshold: u3, transaction: none, transfer: none})
;; Client Small Reimbursement [TRANSACTION] - Threshold: 2/5
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "bdad55ba-9ba9-4684-be3a-a9ce01ee3392"}
  {active: true, title: "Client Small Reimbursement", type: "Operational_Expense", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7 0x020471d94d1876bb256bb897e3ff369000d9698fbe767c46e7f92827e40bc3c9b2 0x0315f9bd5dbcee6b166bac1f90eef0326aac6e1f9161bcc857647f49409e29ff96), threshold: u2, transaction: none, transfer: none})
;; Office Supplies [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "69c78237-f088-4d8c-ab8a-c1124d3b85e5"}
  {active: true, title: "Office Supplies", type: "Operational_Expense", signers: (list 0x02171bd62c7aa710d110c786fd613f13b8793332719f3efdf9cfb4f0536f78f69c 0x02e76eabaa2745e2c6fdab2ca19e176d278dadde2dba7ab576e0b52df556129448), threshold: u2, transaction: none, transfer: none})
;; Rootstock Test [TRANSACTION] - Threshold: 4/5
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "adca5284-6529-429c-b935-cb30b2444b17"}
  {active: true, title: "Rootstock Test", type: "Operational_Expense", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x0270a962de549b589f958335816ba5e31963a75c81bb1f91b3e31002dd9ed8dedd 0x03c009052c203d8c3eb605067e7956373a6cd94e1ce94e8e00efdc1ed14ffd2103 0x029326adc1c69b92c2101ba44c5d8cacdffa29f534e017b3f7a8f3e06351524a10), threshold: u4, transaction: none, transfer: none})
;; Stephen Davis Stipend [TRANSACTION] - Threshold: 2/4
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "2b5abd27-ff65-4e75-9c4c-75abc0ab5d54"}
  {active: true, title: "Stephen Davis Stipend", type: "Contractor_Stipend", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x020471d94d1876bb256bb897e3ff369000d9698fbe767c46e7f92827e40bc3c9b2 0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7), threshold: u2, transaction: none, transfer: none})
;; STX Biweekly Stipend [TRANSACTION] - Threshold: 2/7
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "6f560e20-3b48-4309-8da5-182db2abd507"}
  {active: true, title: "STX Biweekly Stipend", type: "Crypto_Onramp", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7 0x020471d94d1876bb256bb897e3ff369000d9698fbe767c46e7f92827e40bc3c9b2 0x0315f9bd5dbcee6b166bac1f90eef0326aac6e1f9161bcc857647f49409e29ff96 0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c 0x03c009052c203d8c3eb605067e7956373a6cd94e1ce94e8e00efdc1ed14ffd2103), threshold: u2, transaction: none, transfer: none})
;; Hz Stipend Biweekly - STX [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "a5e52202-8935-4f8b-8ae4-c73af4a65157"}
  {active: true, title: "Hz Stipend Biweekly - STX", type: "Contractor_Stipend", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9), threshold: u2, transaction: none, transfer: none})
;; Chigala Stipend Biweekly - STX [TRANSACTION] - Threshold: 2/3
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "bc357e77-2f63-4d8c-b022-334e661b409c"}
  {active: true, title: "Chigala Stipend Biweekly - STX", type: "Contractor_Stipend", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7), threshold: u2, transaction: none, transfer: none})
;; STX Deposit Test Rapha [TRANSACTION] - Threshold: 2/7
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "b94aff39-8b49-43ad-82c4-a08c28fdf37d"}
  {active: true, title: "STX Deposit Test Rapha", type: "Crypto_Onramp", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7 0x0315f9bd5dbcee6b166bac1f90eef0326aac6e1f9161bcc857647f49409e29ff96 0x03c009052c203d8c3eb605067e7956373a6cd94e1ce94e8e00efdc1ed14ffd2103 0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c 0x020471d94d1876bb256bb897e3ff369000d9698fbe767c46e7f92827e40bc3c9b2), threshold: u2, transaction: none, transfer: none})
;; ClarityWG Expenses [TRANSACTION] - Threshold: 2/4
(map-set policies {client-id: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc, policy: "27f4b6d5-5cf1-40a7-8087-0d1e32a3f76c"}
  {active: true, title: "ClarityWG Expenses", type: "Operational_Expense", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c 0x0315f9bd5dbcee6b166bac1f90eef0326aac6e1f9161bcc857647f49409e29ff96), threshold: u2, transaction: none, transfer: none})


;; 
;; CLIENT 2: cf-vault-setdevx-v0
;; ID: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
;; Users: 12 | Admins: 5 | Policies: 15
;; 

;; --- Client Registration ---
(map-set client 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e true)

;; --- Active Admin Count ---
(map-set active-admins 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e u5)

;; --- Users (12) ---
;; CTO [ADMIN]
(map-set users {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "237c0633-6fb1-4f6e-9ef4-a5c1392c31c1"}
  {address: 'SP3ASDZZ5CKTK48KY8JEKXW93CD9J28GXG6C2A86T, key: 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9, position: "CTO", active: true, is-admin: true})
;; Business Development Analyst [ADMIN]
(map-set users {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "38ffd350-4e85-41d9-9aef-f7ae084e6ac9"}
  {address: 'SP2E3GBVAYEHMBDZ8G58AYVJFT0H8NGZG22GFKDNQ, key: 0x02bdf7fe05a9fb9b82e7b38dab3781bc4cbe3c594edf48b5be155b75051d6fe4f4, position: "Business Development Analyst", active: true, is-admin: true})
;; Fullstack Engineer
(map-set users {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "3371ea4b-955f-445a-9589-0613a7629c68"}
  {address: 'SP361WPGWE4G7V4YBE68RA6H4T62MVZ59KP7TV83S, key: 0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7, position: "Fullstack Engineer", active: true, is-admin: false})
;; Product Designer
(map-set users {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "a34a17b8-5142-4e27-8abb-5c6dc212b951"}
  {address: 'SPCM39VTTFM1G1MHQQ3X5504BTZECBTET8EVHP58, key: 0x038b08f2985ad8dd8971daccda7ba4de7e31844b4172f5ed03e7a2ff64cf12258f, position: "Product Designer", active: true, is-admin: false})
;; Owner [ADMIN]
(map-set users {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "e539116e-ac24-4364-ac1a-2c88966d6d67"}
  {address: 'SP1BAVATC1KCYT1NVXXDY0G0CWJ1WRQGZ6N2ZZSH0, key: 0x03993c60ec21483462225c83d8156b9ed901f6ff4544044afe427ec68fb5dfb89b, position: "Owner", active: true, is-admin: true})
;; Bitcoin Engineer
(map-set users {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "3a637814-0f9a-484c-9e22-5a776137f4d7"}
  {address: 'SP3TH7WKZCDJDPYZWMF5KCZ881K9AWRRG2DP7KXJQ, key: 0x03be23e1bc5ea3af7ade14ce0e664fdd172ff849b78f29219ba229a80227b092e4, position: "Bitcoin Engineer", active: true, is-admin: false})
;; Blockchain Engineer
(map-set users {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "e8ae226a-14e4-465c-9149-1903502d6788"}
  {address: 'SP1M0XPQCCX02BT5AA5JR5RMJ098HYGND6FZAXAYH, key: 0x03495ba35af51bf9a7578e89af42a0e526a692f4f9c6b896d8b8e5203f52a7a03a, position: "Blockchain Engineer", active: true, is-admin: false})
;; Brand Director
(map-set users {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "4e11e8f0-2f29-4c39-ae90-8c261f315cc1"}
  {address: 'SP33PJ63KJTP1MDDKYJEM02D7SKJP148YS97Y6S93, key: 0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c, position: "Brand Director", active: true, is-admin: false})
;; Marketing Specialist [ADMIN]
(map-set users {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "27d6df91-86ac-4bca-ba3f-b755afc34fe5"}
  {address: 'SP3XPQ93W05QMBR3FHVAV0E6VGWF0ZA4XZCK6SZ24, key: 0x036d77820314c8cf4742d8a48d87547e22ce98d7a9c19ddee40fcec2497fde74e5, position: "Marketing Specialist", active: true, is-admin: true})
;; Accountant [ADMIN]
(map-set users {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "8725ee7e-952d-49f0-8313-10bdba540d02"}
  {address: 'SP3KC624YG0QB45XVW302T6GTS69F18W3Q517CKF0, key: 0x0261d80ea65409d0b4d430351e79297d9fee8828f33b740e146c365690c73c5f85, position: "Accountant", active: true, is-admin: true})
;; Tester
(map-set users {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "c204c6ca-253b-4b23-a77a-974e77c4df64"}
  {address: 'SP2MZJ2V90P4QYBWDDSNG6MJZGT3VPRYQYXKVRJAM, key: 0x02fc9857149fcc278f01267edc9f16361fba99441293255a6b3ec83eab0cab2f9e, position: "Tester", active: true, is-admin: false})
;; SetDev Engineer
(map-set users {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "b2934ec4-7b52-4f46-9a69-2b21b92705ac"}
  {address: 'SP1YQR9EBHFRDYWYZ4T591GWVM0PRKJXTCW570FWZ, key: 0x03c2657685b87a2ea61fdebcef4e9e18ec7ccffb80ec45db689c3de924be2a65ab, position: "SetDev Engineer", active: true, is-admin: false})

;; --- Users by Address ---
(map-set users-by-address 'SP3ASDZZ5CKTK48KY8JEKXW93CD9J28GXG6C2A86T {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "237c0633-6fb1-4f6e-9ef4-a5c1392c31c1"})
(map-set users-by-address 'SP2E3GBVAYEHMBDZ8G58AYVJFT0H8NGZG22GFKDNQ {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "38ffd350-4e85-41d9-9aef-f7ae084e6ac9"})
(map-set users-by-address 'SP361WPGWE4G7V4YBE68RA6H4T62MVZ59KP7TV83S {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "3371ea4b-955f-445a-9589-0613a7629c68"})
(map-set users-by-address 'SPCM39VTTFM1G1MHQQ3X5504BTZECBTET8EVHP58 {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "a34a17b8-5142-4e27-8abb-5c6dc212b951"})
(map-set users-by-address 'SP1BAVATC1KCYT1NVXXDY0G0CWJ1WRQGZ6N2ZZSH0 {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "e539116e-ac24-4364-ac1a-2c88966d6d67"})
(map-set users-by-address 'SP3TH7WKZCDJDPYZWMF5KCZ881K9AWRRG2DP7KXJQ {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "3a637814-0f9a-484c-9e22-5a776137f4d7"})
(map-set users-by-address 'SP1M0XPQCCX02BT5AA5JR5RMJ098HYGND6FZAXAYH {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "e8ae226a-14e4-465c-9149-1903502d6788"})
(map-set users-by-address 'SP33PJ63KJTP1MDDKYJEM02D7SKJP148YS97Y6S93 {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "4e11e8f0-2f29-4c39-ae90-8c261f315cc1"})
(map-set users-by-address 'SP3XPQ93W05QMBR3FHVAV0E6VGWF0ZA4XZCK6SZ24 {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "27d6df91-86ac-4bca-ba3f-b755afc34fe5"})
(map-set users-by-address 'SP3KC624YG0QB45XVW302T6GTS69F18W3Q517CKF0 {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "8725ee7e-952d-49f0-8313-10bdba540d02"})
(map-set users-by-address 'SP2MZJ2V90P4QYBWDDSNG6MJZGT3VPRYQYXKVRJAM {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "c204c6ca-253b-4b23-a77a-974e77c4df64"})
(map-set users-by-address 'SP1YQR9EBHFRDYWYZ4T591GWVM0PRKJXTCW570FWZ {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "b2934ec4-7b52-4f46-9a69-2b21b92705ac"})

;; --- Users by Key ---
(map-set users-by-key 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "237c0633-6fb1-4f6e-9ef4-a5c1392c31c1"})
(map-set users-by-key 0x02bdf7fe05a9fb9b82e7b38dab3781bc4cbe3c594edf48b5be155b75051d6fe4f4 {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "38ffd350-4e85-41d9-9aef-f7ae084e6ac9"})
(map-set users-by-key 0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7 {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "3371ea4b-955f-445a-9589-0613a7629c68"})
(map-set users-by-key 0x038b08f2985ad8dd8971daccda7ba4de7e31844b4172f5ed03e7a2ff64cf12258f {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "a34a17b8-5142-4e27-8abb-5c6dc212b951"})
(map-set users-by-key 0x03993c60ec21483462225c83d8156b9ed901f6ff4544044afe427ec68fb5dfb89b {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "e539116e-ac24-4364-ac1a-2c88966d6d67"})
(map-set users-by-key 0x03be23e1bc5ea3af7ade14ce0e664fdd172ff849b78f29219ba229a80227b092e4 {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "3a637814-0f9a-484c-9e22-5a776137f4d7"})
(map-set users-by-key 0x03495ba35af51bf9a7578e89af42a0e526a692f4f9c6b896d8b8e5203f52a7a03a {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "e8ae226a-14e4-465c-9149-1903502d6788"})
(map-set users-by-key 0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "4e11e8f0-2f29-4c39-ae90-8c261f315cc1"})
(map-set users-by-key 0x036d77820314c8cf4742d8a48d87547e22ce98d7a9c19ddee40fcec2497fde74e5 {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "27d6df91-86ac-4bca-ba3f-b755afc34fe5"})
(map-set users-by-key 0x0261d80ea65409d0b4d430351e79297d9fee8828f33b740e146c365690c73c5f85 {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "8725ee7e-952d-49f0-8313-10bdba540d02"})
(map-set users-by-key 0x02fc9857149fcc278f01267edc9f16361fba99441293255a6b3ec83eab0cab2f9e {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "c204c6ca-253b-4b23-a77a-974e77c4df64"})
(map-set users-by-key 0x03c2657685b87a2ea61fdebcef4e9e18ec7ccffb80ec45db689c3de924be2a65ab {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, user-id: "b2934ec4-7b52-4f46-9a69-2b21b92705ac"})

;; --- Policies (15) ---
;; Stipend Deposit (STX) [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, policy: "83530861-224e-4880-a5f6-db44f65e4c07"}
  {active: true, title: "Stipend Deposit (STX)", type: "Contractor_Stipend", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9), threshold: u2, transaction: none, transfer: none})
;; Stipend Deposit Real (STX) [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, policy: "c4565041-e066-4aa4-a76b-6f4994128d45"}
  {active: true, title: "Stipend Deposit Real (STX)", type: "Crypto_Onramp", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9), threshold: u2, transaction: none, transfer: none})
;; Hz Biweekly Stipend (STX) [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, policy: "aa6bed3a-be93-42d7-8243-fb4f564ebc44"}
  {active: true, title: "Hz Biweekly Stipend (STX)", type: "Contractor_Stipend", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9), threshold: u2, transaction: none, transfer: none})
;; Chigala Biweekly Stipend (STX) [TRANSACTION] - Threshold: 2/3
(map-set policies {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, policy: "194f39cd-1080-4a8a-9bb7-975131913d4c"}
  {active: true, title: "Chigala Biweekly Stipend (STX)", type: "Contractor_Stipend", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7), threshold: u2, transaction: none, transfer: none})
;; Bitflow Stacks DEX [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, policy: "68b7aa2f-2276-4579-8d7b-22c27706dd99"}
  {active: true, title: "Bitflow Stacks DEX", type: "Treasury_Management", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9), threshold: u2, transaction: none, transfer: none})
;; Test Expense [TRANSACTION] - Threshold: 2/5
(map-set policies {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, policy: "9ff5d94e-b85b-4cfe-8b2f-3da03210d114"}
  {active: true, title: "Test Expense", type: "Operational_Expense", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x02bdf7fe05a9fb9b82e7b38dab3781bc4cbe3c594edf48b5be155b75051d6fe4f4 0x03993c60ec21483462225c83d8156b9ed901f6ff4544044afe427ec68fb5dfb89b 0x03be23e1bc5ea3af7ade14ce0e664fdd172ff849b78f29219ba229a80227b092e4), threshold: u2, transaction: none, transfer: none})
;; Test STX Deposit [TRANSACTION] - Threshold: 2/7
(map-set policies {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, policy: "aa3c2fb2-acf2-46d6-bc20-034989fbe74c"}
  {active: true, title: "Test STX Deposit", type: "Crypto_Onramp", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x02bdf7fe05a9fb9b82e7b38dab3781bc4cbe3c594edf48b5be155b75051d6fe4f4 0x03993c60ec21483462225c83d8156b9ed901f6ff4544044afe427ec68fb5dfb89b 0x03be23e1bc5ea3af7ade14ce0e664fdd172ff849b78f29219ba229a80227b092e4 0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7 0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c), threshold: u2, transaction: none, transfer: none})
;; Test Reimbursement [TRANSACTION] - Threshold: 2/6
(map-set policies {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, policy: "7143977e-04a8-4ee0-84ab-3c391d4862c6"}
  {active: true, title: "Test Reimbursement", type: "Operational_Expense", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x03993c60ec21483462225c83d8156b9ed901f6ff4544044afe427ec68fb5dfb89b 0x03be23e1bc5ea3af7ade14ce0e664fdd172ff849b78f29219ba229a80227b092e4 0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7 0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c), threshold: u2, transaction: none, transfer: none})
;; Shakti Test Deposit [TRANSACTION] - Threshold: 2/7
(map-set policies {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, policy: "55d19e12-c345-4b37-bff4-1e5b78251f7b"}
  {active: true, title: "Shakti Test Deposit", type: "Crypto_Onramp", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x02bdf7fe05a9fb9b82e7b38dab3781bc4cbe3c594edf48b5be155b75051d6fe4f4 0x03993c60ec21483462225c83d8156b9ed901f6ff4544044afe427ec68fb5dfb89b 0x03495ba35af51bf9a7578e89af42a0e526a692f4f9c6b896d8b8e5203f52a7a03a 0x03be23e1bc5ea3af7ade14ce0e664fdd172ff849b78f29219ba229a80227b092e4 0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7), threshold: u2, transaction: none, transfer: none})
;; Shakti Test [TRANSACTION] - Threshold: 2/8
(map-set policies {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, policy: "7dc12649-ff07-47c4-92a9-642b4399823b"}
  {active: true, title: "Shakti Test", type: "Operational_Expense", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x02bdf7fe05a9fb9b82e7b38dab3781bc4cbe3c594edf48b5be155b75051d6fe4f4 0x03993c60ec21483462225c83d8156b9ed901f6ff4544044afe427ec68fb5dfb89b 0x03be23e1bc5ea3af7ade14ce0e664fdd172ff849b78f29219ba229a80227b092e4 0x03495ba35af51bf9a7578e89af42a0e526a692f4f9c6b896d8b8e5203f52a7a03a 0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7 0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c), threshold: u2, transaction: none, transfer: none})
;; Quick Deposit Test [TRANSACTION] - Threshold: 4/5
(map-set policies {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, policy: "e305f478-a399-4ab7-b284-e1c23fe54544"}
  {active: true, title: "Quick Deposit Test", type: "Crypto_Onramp", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x02bdf7fe05a9fb9b82e7b38dab3781bc4cbe3c594edf48b5be155b75051d6fe4f4 0x03993c60ec21483462225c83d8156b9ed901f6ff4544044afe427ec68fb5dfb89b 0x03be23e1bc5ea3af7ade14ce0e664fdd172ff849b78f29219ba229a80227b092e4), threshold: u4, transaction: none, transfer: none})
;; Stipend Jake STX [TRANSACTION] - Threshold: 2/3
(map-set policies {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, policy: "02b33fd1-9952-4843-b04a-506f4cde38f7"}
  {active: true, title: "Stipend Jake STX", type: "Contractor_Stipend", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c), threshold: u2, transaction: none, transfer: none})
;; Hackathon Winner Test [TRANSACTION] - Threshold: 2/6
(map-set policies {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, policy: "6b4458f7-d18f-45e3-998d-ec97eed5a524"}
  {active: true, title: "Hackathon Winner Test", type: "Operational_Expense", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x02bdf7fe05a9fb9b82e7b38dab3781bc4cbe3c594edf48b5be155b75051d6fe4f4 0x03993c60ec21483462225c83d8156b9ed901f6ff4544044afe427ec68fb5dfb89b 0x03be23e1bc5ea3af7ade14ce0e664fdd172ff849b78f29219ba229a80227b092e4 0x03495ba35af51bf9a7578e89af42a0e526a692f4f9c6b896d8b8e5203f52a7a03a), threshold: u2, transaction: none, transfer: none})
;; Gina Test Example [TRANSACTION] - Threshold: 2/3
(map-set policies {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, policy: "789ac960-b3b9-4620-b7e9-793e25a30377"}
  {active: true, title: "Gina Test Example", type: "Operational_Expense", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x02bdf7fe05a9fb9b82e7b38dab3781bc4cbe3c594edf48b5be155b75051d6fe4f4), threshold: u2, transaction: none, transfer: none})
;; Q1 - 26\' Grants [TRANSACTION] - Threshold: 2/6
(map-set policies {client-id: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e, policy: "646e5a3b-06c4-487a-b904-2228b489553f"}
  {active: true, title: "Q1 - 26 Grants", type: "Operational_Expense", signers: (list 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba 0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9 0x02bdf7fe05a9fb9b82e7b38dab3781bc4cbe3c594edf48b5be155b75051d6fe4f4 0x03993c60ec21483462225c83d8156b9ed901f6ff4544044afe427ec68fb5dfb89b 0x03495ba35af51bf9a7578e89af42a0e526a692f4f9c6b896d8b8e5203f52a7a03a 0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7), threshold: u2, transaction: none, transfer: none})


;; 
;; CLIENT 3: cf-vault-mainneteer-sep-v0
;; ID: 0x116e3be46f3288a45b8216c4ba197e4cfa47867b3ab535a2e07aa5bab0a4e933
;; Users: 2 | Admins: 1 | Policies: 0
;; 

;; --- Client Registration ---
(map-set client 0x116e3be46f3288a45b8216c4ba197e4cfa47867b3ab535a2e07aa5bab0a4e933 true)

;; --- Active Admin Count ---
(map-set active-admins 0x116e3be46f3288a45b8216c4ba197e4cfa47867b3ab535a2e07aa5bab0a4e933 u1)

;; --- Users (2) ---
;; test helper
(map-set users {client-id: 0x116e3be46f3288a45b8216c4ba197e4cfa47867b3ab535a2e07aa5bab0a4e933, user-id: "ca6fda56-0b68-479c-829e-33116be63e1d"}
  {address: 'SP1E3EHX70RRZASSSSFDZ6HY334HFY4A5JZMAH5QK, key: 0x02b6c2ec6c6bae67df8d7a0c76549581d0c2df1db803b1863c3781e25e00cba5f2, position: "test helper", active: true, is-admin: false})
;; CEO [ADMIN]
(map-set users {client-id: 0x116e3be46f3288a45b8216c4ba197e4cfa47867b3ab535a2e07aa5bab0a4e933, user-id: "28507383-1134-41ab-8982-4268d797ead3"}
  {address: 'SPY9ZGWGXFPP3P4VP41GF1PJNSTGHF1PA457T95K, key: 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba, position: "CEO", active: true, is-admin: true})

;; --- Users by Address ---
(map-set users-by-address 'SP1E3EHX70RRZASSSSFDZ6HY334HFY4A5JZMAH5QK {client-id: 0x116e3be46f3288a45b8216c4ba197e4cfa47867b3ab535a2e07aa5bab0a4e933, user-id: "ca6fda56-0b68-479c-829e-33116be63e1d"})
(map-set users-by-address 'SPY9ZGWGXFPP3P4VP41GF1PJNSTGHF1PA457T95K {client-id: 0x116e3be46f3288a45b8216c4ba197e4cfa47867b3ab535a2e07aa5bab0a4e933, user-id: "28507383-1134-41ab-8982-4268d797ead3"})

;; --- Users by Key ---
(map-set users-by-key 0x02b6c2ec6c6bae67df8d7a0c76549581d0c2df1db803b1863c3781e25e00cba5f2 {client-id: 0x116e3be46f3288a45b8216c4ba197e4cfa47867b3ab535a2e07aa5bab0a4e933, user-id: "ca6fda56-0b68-479c-829e-33116be63e1d"})
(map-set users-by-key 0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba {client-id: 0x116e3be46f3288a45b8216c4ba197e4cfa47867b3ab535a2e07aa5bab0a4e933, user-id: "28507383-1134-41ab-8982-4268d797ead3"})


;; 
;; CLIENT 4: cf-vault-bff-pool-test-9-25-v0
;; ID: 0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5
;; Users: 2 | Admins: 2 | Policies: 4
;; 

;; --- Client Registration ---
(map-set client 0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5 true)

;; --- Active Admin Count ---
(map-set active-admins 0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5 u2)

;; --- Users (2) ---
;; rsar [ADMIN]
(map-set users {client-id: 0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5, user-id: "5d8a0e81-616d-4f3c-b566-55789191d960"}
  {address: 'SPMM93EWFYEMGFYC2C32VY2W4J8XARHB25JE8BR, key: 0x02e3734f53c46b574386c3d5aa176fe77385b4d2d1d7d18b8bd657a5ed92b1d732, position: "rsar", active: true, is-admin: true})
;; rsar [ADMIN]
(map-set users {client-id: 0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5, user-id: "03075972-d8db-4bb5-b9ec-24ce928b4638"}
  {address: 'SPMM93EWFYEMGFYC2C32VY2W4J8XARHB25JE8BR, key: 0x02e3734f53c46b574386c3d5aa176fe77385b4d2d1d7d18b8bd657a5ed92b1d732, position: "rsar", active: true, is-admin: true})

;; --- Users by Address ---
(map-set users-by-address 'SPMM93EWFYEMGFYC2C32VY2W4J8XARHB25JE8BR {client-id: 0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5, user-id: "5d8a0e81-616d-4f3c-b566-55789191d960"})
(map-set users-by-address 'SPMM93EWFYEMGFYC2C32VY2W4J8XARHB25JE8BR {client-id: 0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5, user-id: "03075972-d8db-4bb5-b9ec-24ce928b4638"})

;; --- Users by Key ---
(map-set users-by-key 0x02e3734f53c46b574386c3d5aa176fe77385b4d2d1d7d18b8bd657a5ed92b1d732 {client-id: 0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5, user-id: "5d8a0e81-616d-4f3c-b566-55789191d960"})
(map-set users-by-key 0x02e3734f53c46b574386c3d5aa176fe77385b4d2d1d7d18b8bd657a5ed92b1d732 {client-id: 0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5, user-id: "03075972-d8db-4bb5-b9ec-24ce928b4638"})

;; --- Policies (4) ---
;; Bitflow Stacks Pool [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5, policy: "5432a7e3-d602-494f-988c-bf40fd7e7127"}
  {active: true, title: "Bitflow Stacks Pool", type: "Treasury_Management", signers: (list 0x02b2755a3b842fb5d9dbb2a509fe43b43abb4352ba4add8560f10f59541dbea75c 0x02e3734f53c46b574386c3d5aa176fe77385b4d2d1d7d18b8bd657a5ed92b1d732), threshold: u2, transaction: none, transfer: none})
;; Bitflow Stacks DEX [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5, policy: "542d7e24-2dcd-482f-bf13-966a15c9b9fa"}
  {active: true, title: "Bitflow Stacks DEX", type: "Treasury_Management", signers: (list 0x02b2755a3b842fb5d9dbb2a509fe43b43abb4352ba4add8560f10f59541dbea75c 0x02e3734f53c46b574386c3d5aa176fe77385b4d2d1d7d18b8bd657a5ed92b1d732), threshold: u2, transaction: none, transfer: none})
;; usdh send [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5, policy: "b0eddc56-d3c2-49b1-b7e6-f79683893342"}
  {active: true, title: "usdh send", type: "Contractor_Stipend", signers: (list 0x02b2755a3b842fb5d9dbb2a509fe43b43abb4352ba4add8560f10f59541dbea75c 0x02e3734f53c46b574386c3d5aa176fe77385b4d2d1d7d18b8bd657a5ed92b1d732), threshold: u2, transaction: none, transfer: none})
;; usdh send [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5, policy: "c0c55cfe-b400-472c-b8dc-fe3800657924"}
  {active: true, title: "usdh send", type: "Contractor_Stipend", signers: (list 0x02b2755a3b842fb5d9dbb2a509fe43b43abb4352ba4add8560f10f59541dbea75c 0x02e3734f53c46b574386c3d5aa176fe77385b4d2d1d7d18b8bd657a5ed92b1d732), threshold: u2, transaction: none, transfer: none})


;; 
;; CLIENT 5: cf-vault-bitflow-v0
;; ID: 0x6b06827743347d7d6366b7239bdfc9203bd9a643d34ad847ad6d0cf6a11fd05b
;; Users: 1 | Admins: 0 | Policies: 2
;; 

;; --- Client Registration ---
(map-set client 0x6b06827743347d7d6366b7239bdfc9203bd9a643d34ad847ad6d0cf6a11fd05b true)

;; --- Users (1) ---
;; Entity
(map-set users {client-id: 0x6b06827743347d7d6366b7239bdfc9203bd9a643d34ad847ad6d0cf6a11fd05b, user-id: "32680492-a2ce-4ca1-b483-5737a0583a9a"}
  {address: 'SP331EPPKGZJT7KRX16TM0TVYZVQZ36ZD71BJZT29, key: 0x03273de779d1a94c5c217091fdf56e8d928d814595f6e3529f66ab2f4c515234a9, position: "Entity", active: true, is-admin: false})

;; --- Users by Address ---
(map-set users-by-address 'SP331EPPKGZJT7KRX16TM0TVYZVQZ36ZD71BJZT29 {client-id: 0x6b06827743347d7d6366b7239bdfc9203bd9a643d34ad847ad6d0cf6a11fd05b, user-id: "32680492-a2ce-4ca1-b483-5737a0583a9a"})

;; --- Users by Key ---
(map-set users-by-key 0x03273de779d1a94c5c217091fdf56e8d928d814595f6e3529f66ab2f4c515234a9 {client-id: 0x6b06827743347d7d6366b7239bdfc9203bd9a643d34ad847ad6d0cf6a11fd05b, user-id: "32680492-a2ce-4ca1-b483-5737a0583a9a"})

;; --- Policies (2) ---
;; STX 1  [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x6b06827743347d7d6366b7239bdfc9203bd9a643d34ad847ad6d0cf6a11fd05b, policy: "7643e79c-7372-4823-8a7e-8b9154e32991"}
  {active: true, title: "STX 1 ", type: "Crypto_Onramp", signers: (list 0x02901e15611a16f38cb38bea48ae301fd52558bb6ae59026586251548ab1d18406 0x03273de779d1a94c5c217091fdf56e8d928d814595f6e3529f66ab2f4c515234a9), threshold: u2, transaction: none, transfer: none})
;; Marketing Rewards Distribution [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x6b06827743347d7d6366b7239bdfc9203bd9a643d34ad847ad6d0cf6a11fd05b, policy: "caf2d033-d42a-4371-a253-a7937f36ca90"}
  {active: true, title: "Marketing Rewards Distribution", type: "Operational_Expense", signers: (list 0x02901e15611a16f38cb38bea48ae301fd52558bb6ae59026586251548ab1d18406 0x03273de779d1a94c5c217091fdf56e8d928d814595f6e3529f66ab2f4c515234a9), threshold: u2, transaction: none, transfer: none})


;; 
;; CLIENT 6: cf-vault-gazma-v0
;; ID: 0xb10ea53cbbb2a5f0e83186e3b034f75fce1c177b3acbb316e565f32525bffe21
;; Users: 1 | Admins: 1 | Policies: 2
;; 

;; --- Client Registration ---
(map-set client 0xb10ea53cbbb2a5f0e83186e3b034f75fce1c177b3acbb316e565f32525bffe21 true)

;; --- Active Admin Count ---
(map-set active-admins 0xb10ea53cbbb2a5f0e83186e3b034f75fce1c177b3acbb316e565f32525bffe21 u1)

;; --- Users (1) ---
;; sub [ADMIN]
(map-set users {client-id: 0xb10ea53cbbb2a5f0e83186e3b034f75fce1c177b3acbb316e565f32525bffe21, user-id: "0bd6b659-2f1f-4b7f-83f2-af3afe352136"}
  {address: 'SPT5ZYYSY8ZEVHHHWH6RVK4GT47ZMFRY5PPQCMPR, key: 0x03bd199370c01d119ea15624050bf5575eb3e7a55e5b9b149ee042cc57ffecef67, position: "sub", active: true, is-admin: true})

;; --- Users by Address ---
(map-set users-by-address 'SPT5ZYYSY8ZEVHHHWH6RVK4GT47ZMFRY5PPQCMPR {client-id: 0xb10ea53cbbb2a5f0e83186e3b034f75fce1c177b3acbb316e565f32525bffe21, user-id: "0bd6b659-2f1f-4b7f-83f2-af3afe352136"})

;; --- Users by Key ---
(map-set users-by-key 0x03bd199370c01d119ea15624050bf5575eb3e7a55e5b9b149ee042cc57ffecef67 {client-id: 0xb10ea53cbbb2a5f0e83186e3b034f75fce1c177b3acbb316e565f32525bffe21, user-id: "0bd6b659-2f1f-4b7f-83f2-af3afe352136"})

;; --- Policies (2) ---
;; stx [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0xb10ea53cbbb2a5f0e83186e3b034f75fce1c177b3acbb316e565f32525bffe21, policy: "e7acd027-358f-421a-a38d-86fdfcd81c72"}
  {active: true, title: "stx", type: "Crypto_Onramp", signers: (list 0x030b1c1431f0686d04ef78cecb68e33e70ee4181ddc9e24766aec79048047f0d84 0x03bd199370c01d119ea15624050bf5575eb3e7a55e5b9b149ee042cc57ffecef67), threshold: u2, transaction: none, transfer: none})
;; Bitflow Swap v2 [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0xb10ea53cbbb2a5f0e83186e3b034f75fce1c177b3acbb316e565f32525bffe21, policy: "c814d380-beab-4a60-9c75-6f399dbd6789"}
  {active: true, title: "Bitflow Swap v2", type: "Operational_Expense", signers: (list 0x030b1c1431f0686d04ef78cecb68e33e70ee4181ddc9e24766aec79048047f0d84 0x03bd199370c01d119ea15624050bf5575eb3e7a55e5b9b149ee042cc57ffecef67), threshold: u2, transaction: none, transfer: none})


;; 
;; CLIENT 7: cf-vault-vdsfvre-v0
;; ID: 0x72f59d10b521849f22e60791429ace2f54980e37f80c847ae36bfb61b92ab0f4
;; Users: 1 | Admins: 1 | Policies: 4
;; 

;; --- Client Registration ---
(map-set client 0x72f59d10b521849f22e60791429ace2f54980e37f80c847ae36bfb61b92ab0f4 true)

;; --- Active Admin Count ---
(map-set active-admins 0x72f59d10b521849f22e60791429ace2f54980e37f80c847ae36bfb61b92ab0f4 u1)

;; --- Users (1) ---
;; asdgasdt [ADMIN]
(map-set users {client-id: 0x72f59d10b521849f22e60791429ace2f54980e37f80c847ae36bfb61b92ab0f4, user-id: "132d75ca-9a77-47e3-89ad-cedf3d555db3"}
  {address: 'SPT5ZYYSY8ZEVHHHWH6RVK4GT47ZMFRY5PPQCMPR, key: 0x03bd199370c01d119ea15624050bf5575eb3e7a55e5b9b149ee042cc57ffecef67, position: "asdgasdt", active: true, is-admin: true})

;; --- Users by Address ---
(map-set users-by-address 'SPT5ZYYSY8ZEVHHHWH6RVK4GT47ZMFRY5PPQCMPR {client-id: 0x72f59d10b521849f22e60791429ace2f54980e37f80c847ae36bfb61b92ab0f4, user-id: "132d75ca-9a77-47e3-89ad-cedf3d555db3"})

;; --- Users by Key ---
(map-set users-by-key 0x03bd199370c01d119ea15624050bf5575eb3e7a55e5b9b149ee042cc57ffecef67 {client-id: 0x72f59d10b521849f22e60791429ace2f54980e37f80c847ae36bfb61b92ab0f4, user-id: "132d75ca-9a77-47e3-89ad-cedf3d555db3"})

;; --- Policies (4) ---
;; Bitflow Stacks DEX [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x72f59d10b521849f22e60791429ace2f54980e37f80c847ae36bfb61b92ab0f4, policy: "0b0bdfc4-9947-4dce-82d4-c75c2408d7ad"}
  {active: true, title: "Bitflow Stacks DEX", type: "Treasury_Management", signers: (list 0x030b1c1431f0686d04ef78cecb68e33e70ee4181ddc9e24766aec79048047f0d84 0x03bd199370c01d119ea15624050bf5575eb3e7a55e5b9b149ee042cc57ffecef67), threshold: u2, transaction: none, transfer: none})
;; onramp stx [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x72f59d10b521849f22e60791429ace2f54980e37f80c847ae36bfb61b92ab0f4, policy: "cc2ac5cc-5c16-4ea7-a683-d9d76a259eba"}
  {active: true, title: "onramp stx", type: "Crypto_Onramp", signers: (list 0x030b1c1431f0686d04ef78cecb68e33e70ee4181ddc9e24766aec79048047f0d84 0x03bd199370c01d119ea15624050bf5575eb3e7a55e5b9b149ee042cc57ffecef67), threshold: u2, transaction: none, transfer: none})
;; Bitflow Stacks DEX [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x72f59d10b521849f22e60791429ace2f54980e37f80c847ae36bfb61b92ab0f4, policy: "66f87402-7a9e-4050-8c60-1e7cbe4d0c0e"}
  {active: true, title: "Bitflow Stacks DEX", type: "Treasury_Management", signers: (list 0x030b1c1431f0686d04ef78cecb68e33e70ee4181ddc9e24766aec79048047f0d84 0x03bd199370c01d119ea15624050bf5575eb3e7a55e5b9b149ee042cc57ffecef67), threshold: u2, transaction: none, transfer: none})
;; Bitflow Stacks Pool [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x72f59d10b521849f22e60791429ace2f54980e37f80c847ae36bfb61b92ab0f4, policy: "bd09b870-8c8d-4699-943c-dc44ea00bc28"}
  {active: true, title: "Bitflow Stacks Pool", type: "Treasury_Management", signers: (list 0x030b1c1431f0686d04ef78cecb68e33e70ee4181ddc9e24766aec79048047f0d84 0x03bd199370c01d119ea15624050bf5575eb3e7a55e5b9b149ee042cc57ffecef67), threshold: u2, transaction: none, transfer: none})


;; 
;; CLIENT 8: cf-vault-bern-v0
;; ID: 0x323ffa49fe23683712e89c19c1247ab948d2cad411f11e76b83d7c6ca3855b08
;; Users: 1 | Admins: 1 | Policies: 2
;; 

;; --- Client Registration ---
(map-set client 0x323ffa49fe23683712e89c19c1247ab948d2cad411f11e76b83d7c6ca3855b08 true)

;; --- Active Admin Count ---
(map-set active-admins 0x323ffa49fe23683712e89c19c1247ab948d2cad411f11e76b83d7c6ca3855b08 u1)

;; --- Users (1) ---
;; CEO [ADMIN]
(map-set users {client-id: 0x323ffa49fe23683712e89c19c1247ab948d2cad411f11e76b83d7c6ca3855b08, user-id: "8753cbc7-d17c-459f-91f2-eb3d86d7217e"}
  {address: 'SP3E9KREM0AZ289XFM1N763XP2MMK70ER8V01F4GV, key: 0x0356ae5fdffcf403798f37bd7f74bfe06074a83a372cc525b672d97c900028bc9c, position: "CEO", active: true, is-admin: true})

;; --- Users by Address ---
(map-set users-by-address 'SP3E9KREM0AZ289XFM1N763XP2MMK70ER8V01F4GV {client-id: 0x323ffa49fe23683712e89c19c1247ab948d2cad411f11e76b83d7c6ca3855b08, user-id: "8753cbc7-d17c-459f-91f2-eb3d86d7217e"})

;; --- Users by Key ---
(map-set users-by-key 0x0356ae5fdffcf403798f37bd7f74bfe06074a83a372cc525b672d97c900028bc9c {client-id: 0x323ffa49fe23683712e89c19c1247ab948d2cad411f11e76b83d7c6ca3855b08, user-id: "8753cbc7-d17c-459f-91f2-eb3d86d7217e"})

;; --- Policies (2) ---
;; Onramp [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x323ffa49fe23683712e89c19c1247ab948d2cad411f11e76b83d7c6ca3855b08, policy: "73ac18b6-e140-4c3c-9d33-e156332fd96b"}
  {active: true, title: "Onramp", type: "Crypto_Onramp", signers: (list 0x03dc307626ee8a3325c84792ee42053e1131846501d9d744d43b657e080f23df80 0x0356ae5fdffcf403798f37bd7f74bfe06074a83a372cc525b672d97c900028bc9c), threshold: u2, transaction: none, transfer: none})
;; Contractor Pizza party [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x323ffa49fe23683712e89c19c1247ab948d2cad411f11e76b83d7c6ca3855b08, policy: "ec8f8779-57c6-480a-9e3a-8a54ce7e3861"}
  {active: true, title: "Contractor Pizza party", type: "Contractor_Stipend", signers: (list 0x0356ae5fdffcf403798f37bd7f74bfe06074a83a372cc525b672d97c900028bc9c 0x03dc307626ee8a3325c84792ee42053e1131846501d9d744d43b657e080f23df80), threshold: u2, transaction: none, transfer: none})


;; 
;; CLIENT 9: cf-vault-stackslabs-v0
;; ID: 0x67237a2fa68610e811b956fe9cf5588bd0f4da958231d76ae00ba7de529f3fca
;; Users: 1 | Admins: 1 | Policies: 2
;; 

;; --- Client Registration ---
(map-set client 0x67237a2fa68610e811b956fe9cf5588bd0f4da958231d76ae00ba7de529f3fca true)

;; --- Active Admin Count ---
(map-set active-admins 0x67237a2fa68610e811b956fe9cf5588bd0f4da958231d76ae00ba7de529f3fca u1)

;; --- Users (1) ---
;; Chief of Staff [ADMIN]
(map-set users {client-id: 0x67237a2fa68610e811b956fe9cf5588bd0f4da958231d76ae00ba7de529f3fca, user-id: "7bef551d-db03-4a99-9be2-381740b8130a"}
  {address: 'SP2J647E7HX31YP9N9VFM2M3T2Y426E0DR8VZWG9S, key: 0x03c0ebc8ab9079a18e5807b7aa544f43b02d0b5627b5ecdc37b4b5e1dcf9ded0e4, position: "Chief of Staff", active: true, is-admin: true})

;; --- Users by Address ---
(map-set users-by-address 'SP2J647E7HX31YP9N9VFM2M3T2Y426E0DR8VZWG9S {client-id: 0x67237a2fa68610e811b956fe9cf5588bd0f4da958231d76ae00ba7de529f3fca, user-id: "7bef551d-db03-4a99-9be2-381740b8130a"})

;; --- Users by Key ---
(map-set users-by-key 0x03c0ebc8ab9079a18e5807b7aa544f43b02d0b5627b5ecdc37b4b5e1dcf9ded0e4 {client-id: 0x67237a2fa68610e811b956fe9cf5588bd0f4da958231d76ae00ba7de529f3fca, user-id: "7bef551d-db03-4a99-9be2-381740b8130a"})

;; --- Policies (2) ---
;; AsignaDeposit [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x67237a2fa68610e811b956fe9cf5588bd0f4da958231d76ae00ba7de529f3fca, policy: "2a29d35b-5972-49ec-a5b4-86980d1a99dc"}
  {active: true, title: "AsignaDeposit", type: "Crypto_Onramp", signers: (list 0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c 0x03c0ebc8ab9079a18e5807b7aa544f43b02d0b5627b5ecdc37b4b5e1dcf9ded0e4), threshold: u2, transaction: none, transfer: none})
;; Contractor Stipend Test [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x67237a2fa68610e811b956fe9cf5588bd0f4da958231d76ae00ba7de529f3fca, policy: "06e65460-b61b-433a-8e0f-10380ccfa60b"}
  {active: true, title: "Contractor Stipend Test", type: "Contractor_Stipend", signers: (list 0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c 0x03c0ebc8ab9079a18e5807b7aa544f43b02d0b5627b5ecdc37b4b5e1dcf9ded0e4), threshold: u2, transaction: none, transfer: none})


;; 
;; CLIENT 10: cf-vault-slacklabso-v0
;; ID: 0xd99c4f2b986e9c8077a7e3d3323badb3cacded1f44f3a2f6397b3e61a2153f41
;; Users: 1 | Admins: 1 | Policies: 2
;; 

;; --- Client Registration ---
(map-set client 0xd99c4f2b986e9c8077a7e3d3323badb3cacded1f44f3a2f6397b3e61a2153f41 true)

;; --- Active Admin Count ---
(map-set active-admins 0xd99c4f2b986e9c8077a7e3d3323badb3cacded1f44f3a2f6397b3e61a2153f41 u1)

;; --- Users (1) ---
;; CTO [ADMIN]
(map-set users {client-id: 0xd99c4f2b986e9c8077a7e3d3323badb3cacded1f44f3a2f6397b3e61a2153f41, user-id: "8ba53135-68b0-4f28-87f1-fb470b3528a9"}
  {address: 'SP372JN80DAFF88A1M5WWK6W4Z3C09J2QCC58V40X, key: 0x0381a3620f2d6270a2ca4f64dc23e7b1f65145622c159bdecf87ceed9f83ea8f54, position: "CTO", active: true, is-admin: true})

;; --- Users by Address ---
(map-set users-by-address 'SP372JN80DAFF88A1M5WWK6W4Z3C09J2QCC58V40X {client-id: 0xd99c4f2b986e9c8077a7e3d3323badb3cacded1f44f3a2f6397b3e61a2153f41, user-id: "8ba53135-68b0-4f28-87f1-fb470b3528a9"})

;; --- Users by Key ---
(map-set users-by-key 0x0381a3620f2d6270a2ca4f64dc23e7b1f65145622c159bdecf87ceed9f83ea8f54 {client-id: 0xd99c4f2b986e9c8077a7e3d3323badb3cacded1f44f3a2f6397b3e61a2153f41, user-id: "8ba53135-68b0-4f28-87f1-fb470b3528a9"})

;; --- Policies (2) ---
;; First Fund [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0xd99c4f2b986e9c8077a7e3d3323badb3cacded1f44f3a2f6397b3e61a2153f41, policy: "2f79f283-0a5e-4434-ab6b-7d6b1e866be3"}
  {active: true, title: "First Fund", type: "Crypto_Onramp", signers: (list 0x026ea2bce965881ada6cf223cb8bb714dea1025cce1d9b52bb4fad02c0fa6c91ff 0x0381a3620f2d6270a2ca4f64dc23e7b1f65145622c159bdecf87ceed9f83ea8f54), threshold: u2, transaction: none, transfer: none})
;; Hackathon Winner [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0xd99c4f2b986e9c8077a7e3d3323badb3cacded1f44f3a2f6397b3e61a2153f41, policy: "6e86ec9f-a5ad-4d56-a965-fbbb9d1e3160"}
  {active: true, title: "Hackathon Winner", type: "Operational_Expense", signers: (list 0x026ea2bce965881ada6cf223cb8bb714dea1025cce1d9b52bb4fad02c0fa6c91ff 0x0381a3620f2d6270a2ca4f64dc23e7b1f65145622c159bdecf87ceed9f83ea8f54), threshold: u2, transaction: none, transfer: none})


;; 
;; CLIENT 11: cf-vault-thecompany-v1
;; ID: 0xe63d87a47c506c6af71526f3d207eb2a0899d3d25481dcd70c88ca3fc68fe767
;; Users: 1 | Admins: 1 | Policies: 2
;; 

;; --- Client Registration ---
(map-set client 0xe63d87a47c506c6af71526f3d207eb2a0899d3d25481dcd70c88ca3fc68fe767 true)

;; --- Active Admin Count ---
(map-set active-admins 0xe63d87a47c506c6af71526f3d207eb2a0899d3d25481dcd70c88ca3fc68fe767 u1)

;; --- Users (1) ---
;; CFO [ADMIN]
(map-set users {client-id: 0xe63d87a47c506c6af71526f3d207eb2a0899d3d25481dcd70c88ca3fc68fe767, user-id: "8c6ac39a-f5c0-44d0-85de-e69cf39bcbdc"}
  {address: 'SP1PAZR29JZV186AN8TBTCAHB0MSSKQ3B5VS7MVG5, key: 0x037bd95193ceea1a1e8640ed17ee42f0ded6014916ff8f0c4a83bd18c5cb60cf6b, position: "CFO", active: true, is-admin: true})

;; --- Users by Address ---
(map-set users-by-address 'SP1PAZR29JZV186AN8TBTCAHB0MSSKQ3B5VS7MVG5 {client-id: 0xe63d87a47c506c6af71526f3d207eb2a0899d3d25481dcd70c88ca3fc68fe767, user-id: "8c6ac39a-f5c0-44d0-85de-e69cf39bcbdc"})

;; --- Users by Key ---
(map-set users-by-key 0x037bd95193ceea1a1e8640ed17ee42f0ded6014916ff8f0c4a83bd18c5cb60cf6b {client-id: 0xe63d87a47c506c6af71526f3d207eb2a0899d3d25481dcd70c88ca3fc68fe767, user-id: "8c6ac39a-f5c0-44d0-85de-e69cf39bcbdc"})

;; --- Policies (2) ---
;; Initial Onramp [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0xe63d87a47c506c6af71526f3d207eb2a0899d3d25481dcd70c88ca3fc68fe767, policy: "9413a0ce-504a-4c82-88cc-fc3025624d4d"}
  {active: true, title: "Initial Onramp", type: "Crypto_Onramp", signers: (list 0x032920ce1196cf15be5469036a790d1d07ca3cb80dec71d2c42fc61cd648446d46 0x037bd95193ceea1a1e8640ed17ee42f0ded6014916ff8f0c4a83bd18c5cb60cf6b), threshold: u2, transaction: none, transfer: none})
;; test Send demo  [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0xe63d87a47c506c6af71526f3d207eb2a0899d3d25481dcd70c88ca3fc68fe767, policy: "e05f5a17-943a-4cc8-bc82-4c1b5ec5c728"}
  {active: true, title: "test Send demo ", type: "Operational_Expense", signers: (list 0x032920ce1196cf15be5469036a790d1d07ca3cb80dec71d2c42fc61cd648446d46 0x037bd95193ceea1a1e8640ed17ee42f0ded6014916ff8f0c4a83bd18c5cb60cf6b), threshold: u2, transaction: none, transfer: none})


;; 
;; CLIENT 12: cf-vault-stacks-labs-v1
;; ID: 0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81
;; Users: 1 | Admins: 1 | Policies: 5
;; 

;; --- Client Registration ---
(map-set client 0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81 true)

;; --- Active Admin Count ---
(map-set active-admins 0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81 u1)

;; --- Users (1) ---
;; Chief of Staff [ADMIN]
(map-set users {client-id: 0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81, user-id: "a242301f-1437-469f-94bc-67c88b97d36e"}
  {address: 'SP18H0DSF6820PWR8REEHFY84NT2PGNQK2NPJNA3Y, key: 0x025de5a5a3415b06a4ba7db4cd83f01138e5364252e592b82ee19e43a89207198d, position: "Chief of Staff", active: true, is-admin: true})

;; --- Users by Address ---
(map-set users-by-address 'SP18H0DSF6820PWR8REEHFY84NT2PGNQK2NPJNA3Y {client-id: 0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81, user-id: "a242301f-1437-469f-94bc-67c88b97d36e"})

;; --- Users by Key ---
(map-set users-by-key 0x025de5a5a3415b06a4ba7db4cd83f01138e5364252e592b82ee19e43a89207198d {client-id: 0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81, user-id: "a242301f-1437-469f-94bc-67c88b97d36e"})

;; --- Policies (5) ---
;; Test Deposit [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81, policy: "7c79eb9e-b16c-4939-8be6-71721c1f1a81"}
  {active: true, title: "Test Deposit", type: "Crypto_Onramp", signers: (list 0x038d7bf5b05d93124721bb3c06dfa2b2d8160586f69d37314a4abf8d01dabaa055 0x025de5a5a3415b06a4ba7db4cd83f01138e5364252e592b82ee19e43a89207198d), threshold: u2, transaction: none, transfer: none})
;; Test Spend [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81, policy: "ff86a7b9-b37a-4d73-a526-6bd3934cdc67"}
  {active: true, title: "Test Spend", type: "Operational_Expense", signers: (list 0x038d7bf5b05d93124721bb3c06dfa2b2d8160586f69d37314a4abf8d01dabaa055 0x025de5a5a3415b06a4ba7db4cd83f01138e5364252e592b82ee19e43a89207198d), threshold: u2, transaction: none, transfer: none})
;; General Onramping [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81, policy: "299c4a6a-2230-4add-a00c-6884b74420c0"}
  {active: true, title: "General Onramping", type: "Crypto_Onramp", signers: (list 0x038d7bf5b05d93124721bb3c06dfa2b2d8160586f69d37314a4abf8d01dabaa055 0x025de5a5a3415b06a4ba7db4cd83f01138e5364252e592b82ee19e43a89207198d), threshold: u2, transaction: none, transfer: none})
;; STX Spend [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81, policy: "b7863cae-06c2-496c-974c-d9d481ded65c"}
  {active: true, title: "STX Spend", type: "Contractor_Stipend", signers: (list 0x038d7bf5b05d93124721bb3c06dfa2b2d8160586f69d37314a4abf8d01dabaa055 0x025de5a5a3415b06a4ba7db4cd83f01138e5364252e592b82ee19e43a89207198d), threshold: u2, transaction: none, transfer: none})
;; sBTC Spend [TRANSACTION] - Threshold: 2/2
(map-set policies {client-id: 0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81, policy: "0c005fdf-7d28-4d65-9dae-2c679d62fde5"}
  {active: true, title: "sBTC Spend", type: "Contractor_Stipend", signers: (list 0x038d7bf5b05d93124721bb3c06dfa2b2d8160586f69d37314a4abf8d01dabaa055 0x025de5a5a3415b06a4ba7db4cd83f01138e5364252e592b82ee19e43a89207198d), threshold: u2, transaction: none, transfer: none})


;; CLIENT 13: unknown-vault
;; ID: 0x98740df51ad4051bcfaaf388b578797ebd1034fec0af526878154477c3f9a11a
;; Users: 0 | Admins: 0 | Policies: 0

;; --- Client Registration ---
(map-set client 0x98740df51ad4051bcfaaf388b578797ebd1034fec0af526878154477c3f9a11a true)


;; GLOBAL POLICY TYPES
(map-set cofund-policy-types "Treasury_Management" true)

```
