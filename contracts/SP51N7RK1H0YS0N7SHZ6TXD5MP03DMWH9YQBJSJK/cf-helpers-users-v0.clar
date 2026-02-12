;; This is a Cofund helper contract that provides a wrapper around the state contract to manage users.
;; The current version provides the ability to add, remove, & rotate users.

;; cons
(define-constant SIP018_MSG_PREFIX 0x534950303138)
(define-constant HASH_LENGTH u32)
(define-constant KEY_LENGTH u33)

;; errs
(define-constant ERR_INVALID_PARAMS (err u301))
(define-constant ERR_THRESHOLD_NOT_MET (err u302))
(define-constant ERR_INVALID_LENGTH (err u303))
(define-constant ERR_INVALID_SIGNATURE (err u304))
(define-constant ERR_AUTH_ID_REPLAY (err u305))
(define-constant ERR_SIGNER_NOT_ADMIN (err u306))
(define-constant ERR_DUPLICATE_SIGNATURE (err u307))
(define-constant ERR_SIGNER_NOT_REGISTERED (err u308))
(define-constant ERR_SIGNER_WRONG_CLIENT (err u309))
(define-constant ERR_SIGNER_NOT_FOUND (err u310))
(define-constant ERR_SIGNER_INACTIVE (err u311))
(define-constant ERR_CALLER_NOT_REGISTERED (err u312))
(define-constant ERR_FORWARDING_FORBIDDEN (err u313))
(define-constant ERR_CALLER_ID_MISMATCH (err u314))
(define-constant ERR_CLIENT_ID_MISMATCH (err u315))
(define-constant ERR_CALLER_NOT_ADMIN (err u316))

;; add-user-invite-wrapper
;; This function, if successful, adds a new user to the users map.
;; The interface offers two different ways of securely inviting a user based on whether caller is inviting an admin or non-admin.
;; An admin can simply call to add any position *other* than admin or an admin can call to add a new admin by passing in a list of signatures.
;; @param client-id; The client's ID
;; @param caller-id; The caller's ID
;; @param user-id; The new user's ID
;; @param user-position; The new user's position
;; @param invite-hash; The invite hash
;; @param admin-auth-optional; The admin auth optional
;; @param admin-optional-signed-data; The admin optional signed data
(define-public (add-user-invite-wrapper (client-id (buff 32))
                          (caller-id (string-ascii 64))
                          (user-id (string-ascii 64))
                          (user-is-admin bool)
                          (user-position (string-ascii 128))
                          (invite-hash (buff 32))
                          (admin-auth-optional (optional (string-ascii 64)))
                          (admin-optional-signed-data (optional (list 35 {signer: (buff 33), signature: (buff 65)}))))
    (let (
        (user-id-by-address (unwrap! (contract-call? .cf-helpers-state-v0 get-user-id-by-address tx-sender) ERR_CALLER_NOT_REGISTERED))
        (sender-caller-id (get user-id user-id-by-address))
        (sender-client-id (get client-id user-id-by-address))
        (user (unwrap! 
            (contract-call? .cf-helpers-state-v0 get-user (get client-id user-id-by-address) sender-caller-id)
            ERR_CALLER_NOT_REGISTERED))
        ) 
        ;; Check that caller is both tx-sender & contract-caller (calling through a contract)
        (asserts! (is-eq contract-caller tx-sender) ERR_FORWARDING_FORBIDDEN)
        ;; If adding an admin, signatures MUST be provided
        (asserts! 
            (is-eq sender-caller-id caller-id)
            ERR_CALLER_ID_MISMATCH
        )
        (asserts! (is-eq client-id sender-client-id) ERR_CLIENT_ID_MISMATCH)
        (asserts! 
            (get is-admin user)
            ERR_CALLER_NOT_ADMIN)
        ;; Execute non-admin or admin path
        (match admin-optional-signed-data
            signed-data
            (begin
                ;; Verify both admin-id-optional & admin-auth-optional were passed in
                (asserts! (is-some admin-auth-optional) ERR_INVALID_PARAMS)
                ;; Adding an admin, verification steps required
                ;; Verify signatures
                ;; Check that all signatures are valid & all signers are in the policy
                (try! (verify-admin-signature "Add" client-id  user-id (unwrap-panic admin-auth-optional) signed-data))
                ;; Check number of active admins
                (if (> (unwrap-panic (contract-call? .cf-helpers-state-v0 get-active-admins client-id)) u1)
                    ;; > 1, threshold required
                    (asserts! (>= (len signed-data) u2) ERR_THRESHOLD_NOT_MET)
                    ;; < 2, no threshold required
                    true
                )
                true
            )
            true
        )
        ;; Call into state contract to complete admin invite
        (try! (contract-call? .cf-helpers-state-v0 add-user-invite client-id caller-id invite-hash user-id user-position user-is-admin))
        (print {
            topic: "User Invite Added",
            client-id: client-id,
            caller-id: caller-id,
            user-id: user-id,
            user-position: user-position,
            invite-hash: invite-hash
        })
        (ok true)
    )
)
;; add-user-completion
;; This function, if successful, completes the user invite process by registering their address & key. 
;; It's important to note that this function is only callable by the new user.
;; @param client-id; The client's ID
;; @param caller-id; The caller's ID
;; @param invite-hash; The invite hash
;; @param invite-preimage-id; The invite preimage ID
;; @param new-user-key; The new user's key
(define-public (add-user-invite-complete-wrapper (client-id (buff 32))
                          (invite-hash (buff 32))
                          (invite-preimage-id uint)
                          (new-user-key (buff 33)))
    (begin
        ;; Check that all byte lengths are correct
        (asserts! (and (is-eq (len client-id) HASH_LENGTH) (is-eq (len invite-hash) HASH_LENGTH) (is-eq (len new-user-key) KEY_LENGTH)) ERR_INVALID_LENGTH)
        ;; Check that tx-sender is the new user address & tx-sender is the contract-caller
        (asserts! (is-eq (some contract-caller) (some tx-sender)) ERR_FORWARDING_FORBIDDEN)
        ;; Attempt to complete invite & add user
        (try! (contract-call? .cf-helpers-state-v0 add-user-invite-complete client-id invite-hash invite-preimage-id new-user-key))
        (ok true)
    )
)
;; remove-user-wrapper
;; This function, if successful, removes a user from the users map. 
;; This function also offers two security paths based on whether the removed-id is an admin or not.
;; @param client-id; The client's ID
;; @param user-id; The caller's ID
;; @param removed-user-id; The removed user's ID
;; @param admin-auth-optional; The admin auth optional
(define-public (remove-user-wrapper (client-id (buff 32))
                          (user-id (string-ascii 64))
                          (removed-user-id (string-ascii 64))
                          (admin-auth-optional (optional (string-ascii 64)))
                          (admin-optional-signed-data (optional (list 35 {signer: (buff 33), signature: (buff 65)}))))
    (begin
        ;; Check that client-id is correct length
        (asserts! (is-eq (len client-id) HASH_LENGTH) ERR_INVALID_LENGTH)
        ;; Check that caller is both tx-sender & contract-caller
        (asserts! (is-eq (some contract-caller) (some tx-sender)) ERR_FORWARDING_FORBIDDEN)
        (match admin-optional-signed-data
            signed-data
            (begin
                ;; Verify both admin-id-optional & admin-auth-optional were passed in
                (asserts! (is-some admin-auth-optional) ERR_INVALID_PARAMS)
                ;; Verify signatures
                ;; Check that all signatures are valid & all signers are in the policy
                (try! (verify-admin-signature "Remove"  client-id user-id (unwrap-panic admin-auth-optional) signed-data))
                ;; Check that signing threshold is met (2)
                (asserts! (>= (len signed-data) u2) ERR_THRESHOLD_NOT_MET)
                ;; Call into state contract to remove user
                (try! (contract-call? .cf-helpers-state-v0 remove-user client-id user-id removed-user-id (some (len signed-data))))
            )
            ;; Call into state contract to remove user
            (try! (contract-call? .cf-helpers-state-v0 remove-user client-id user-id removed-user-id none))
        )
        (print {
            topic: "User Removed",
            client-id: client-id,
            caller-id: user-id,
            removed-user-id: removed-user-id
        })
        (ok true)
    )
)
;; rotate-user-items
;; This function, if successful, rotates a user's address & key. 
;; This function also offers two security paths based on whether the user-id is an admin or not.
;; @param client-id; The client's ID
;; @param caller-id; The caller's ID
;; @param user-id; The user's ID
;; @param new-user-address; The new user's address
;; @param new-user-key; The new user's key
;; @param admin-auth-optional; The admin auth optional
;; @param admin-optional-signed-data; The admin optional signed data
(define-public (rotate-user-wrapper (client-id (buff 32))
                          (caller-id (string-ascii 64))
                          (user-id (string-ascii 64))
                          (new-user-address principal)
                          (new-user-key (buff 33))
                          (admin-auth-optional (optional (string-ascii 64)))
                          (admin-optional-signed-data (optional (list 35 {signer: (buff 33), signature: (buff 65)}))))
    (begin
        ;; Check that client-id is correct length
        (asserts! (is-eq (len client-id) HASH_LENGTH) ERR_INVALID_LENGTH)
        ;; Check that caller is both tx-sender & contract-caller
        (asserts! (is-eq (some contract-caller) (some tx-sender)) ERR_FORWARDING_FORBIDDEN)
        (match admin-optional-signed-data
            signed-data
            (begin
                ;; Verify both admin-id-optional & admin-auth-optional were passed in
                (asserts! (is-some admin-auth-optional) ERR_INVALID_PARAMS)
                ;; Verify signatures
                ;; Check that all signatures are valid & all signers are in the policy
                (try! (verify-admin-signature "Rotate" client-id user-id (unwrap-panic admin-auth-optional) signed-data))
                ;; Check that signing threshold is met (2)
                (asserts! (>= (len signed-data) u2) ERR_THRESHOLD_NOT_MET)
                ;; Call into state contract to rotate user items
                (try! (contract-call? .cf-helpers-state-v0 rotate-user client-id caller-id user-id new-user-address new-user-key (some (len signed-data))))
            )
            ;; Call into state contract to rotate user items
            (try! (contract-call? .cf-helpers-state-v0 rotate-user client-id caller-id user-id new-user-address new-user-key none))
        )
        (ok true)
    )
)

;; verify-admin-signature
;; This function & the it's helpers verify a batch of signatures reserved for admin actions.
;; This includes adding, removing, or rotating *admins*.
;; @param type; The type of action
;; @param admin-id; The admin's ID
;; @param auth-id; The auth ID
;; @param signed-data; The signed data
(define-private (verify-admin-signature (type (string-ascii 32))
                                    (client-id (buff 32))
                                    (admin-id (string-ascii 64))
                                    (auth-id (string-ascii 64))
                                    (signed-data (list 35 {signer: (buff 33), signature: (buff 65)})))
    (begin
        ;; verify fresh auth-id
        (asserts! (is-none (contract-call? .cf-helpers-state-v0 get-used-auth-ids client-id auth-id)) ERR_AUTH_ID_REPLAY)
        ;; Check that all signatures are valid, all signers are admins, and no duplicate signers
        (try! (fold verify-admin-signature-helper signed-data (ok {client-id: client-id, type: type, admin-id: admin-id, auth-id: auth-id, seen-signers: (list)})))
        ;; update auth-id
        (unwrap! (contract-call? .cf-helpers-state-v0 set-auth-id client-id "users" auth-id) ERR_AUTH_ID_REPLAY)
        (ok true)
    )
)
;; verify-admin-signature-helper
;; This function verifies an individual signature from the list of signatures for an attempted action.
;; @param signed-data; The signed data
;; @param signed-response; The signed response which includes items needed to recreate the message hash
(define-private (verify-admin-signature-helper (signed-data {signer: (buff 33), signature: (buff 65)})
                                  (signed-response (response {client-id: (buff 32), type: (string-ascii 32), admin-id: (string-ascii 64), auth-id: (string-ascii 64), seen-signers: (list 35 (buff 33))} uint)))
    (match signed-response
        ok-response
        (let (
            ;; Look up user by their signing key
            (signer-user-id (contract-call? .cf-helpers-state-v0 get-user-id-by-key (get signer signed-data)))
        )
            ;; verify no duplicate signers
            (asserts! (is-none (index-of? (get seen-signers ok-response) (get signer signed-data))) ERR_DUPLICATE_SIGNATURE)
            ;; verify signature
            (asserts! (read-valid-admin-signature (get type ok-response) (get admin-id ok-response) (get auth-id ok-response) (get signature signed-data) (get signer signed-data)) ERR_INVALID_SIGNATURE)
            ;; verify signer is a registered user
            (asserts! (is-some signer-user-id) ERR_SIGNER_NOT_REGISTERED)
            ;; verify signer belongs to this client and is an active admin
            (let (
                (signer-info (unwrap-panic signer-user-id))
                (signer-user (contract-call? .cf-helpers-state-v0 get-user (get client-id signer-info) (get user-id signer-info)))
            )
                ;; verify signer belongs to same client
                (asserts! (is-eq (get client-id signer-info) (get client-id ok-response)) ERR_SIGNER_WRONG_CLIENT)
                ;; verify signer user exists and is active admin
                (asserts! (is-some signer-user) ERR_SIGNER_NOT_FOUND)
                (let ((user-data (unwrap-panic signer-user)))
                    (asserts! (get active user-data) ERR_SIGNER_INACTIVE)
                    (asserts! (get is-admin user-data) ERR_SIGNER_NOT_ADMIN)
                )
            )
            ;; Return with signer added to seen-signers list
            (ok (merge ok-response {seen-signers: (unwrap-panic (as-max-len? (append (get seen-signers ok-response) (get signer signed-data)) u35))}))
        )
        err-response
        (err err-response)
    )
)

;; read-valid-admin-signature
;; This helper function reads & validates an individual signature with 'secp256k1-verify'. This is a read-only
;; so for off-chain testing purposes.
;; @param type; The type of action ("add", "remove", "rotate")
;; @param admin-id; The admin's ID
;; @param auth-id; The auth ID
;; @param signature; The signature
;; @param signer-key; The signer's key
(define-read-only (read-valid-admin-signature (type (string-ascii 32))
                                        (admin-id (string-ascii 64))
                                        (auth-id (string-ascii 64))
                                        (signature (buff 65))
                                        (signer-key (buff 33)))

        (secp256k1-verify (get-admin-signature-message-hash type admin-id auth-id) signature signer-key)
)

;; get-admin-signature-message-hash
;; Generate a message hash for validating a signer key. The message hash follows SIP018 for signing structured data.
;; The domain is `{ name: "cofund-signer", version: "1.0.0", chain-id: chain-id }`.
;; The message is '{ admin-id: admin-id, auth-id: auth-id, type: type }'.
;; @param type; The type of action ("add", "remove", "rotate")
;; @param admin-id; The admin's ID
;; @param auth-id; The auth ID
(define-read-only (get-admin-signature-message-hash (type (string-ascii 32))
                                                    (admin-id (string-ascii 64))
                                                    (auth-id (string-ascii 64)))
  (sha256 (concat
    SIP018_MSG_PREFIX
    (concat
      (sha256 (unwrap-panic (to-consensus-buff? { name: "cofund-signer", version: "1.0.0", chain-id: u1 })))
      (sha256 (unwrap-panic
        (to-consensus-buff? {
          admin-id: admin-id,
          auth-id: auth-id,
          type: type,
        })))
    ))
  )
)