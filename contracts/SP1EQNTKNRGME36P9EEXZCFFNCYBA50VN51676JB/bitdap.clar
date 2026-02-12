;; title: Bitdap Pass
;; version: 0.1.0
;; summary: Bitdap Pass - tiered membership NFT collection on Stacks.
;; description: >
;;   Bitdap Pass is a non-fungible token (NFT) collection that represents
;;   access passes to the Bitdap ecosystem. Each pass belongs to a tier
;;   (Basic, Pro, or VIP), which can be used by off-chain services or
;;   other contracts to gate features and experiences.
;;
;;   - Collection name: Bitdap Pass
;;   - Tiers: Basic, Pro, VIP
;;   - 1 owner per token-id, non-fractional NFTs
;;   - Future milestones will define minting, transfer logic, and metadata
;;     for each tier.
;;
;;   - mint-event: emitted when a pass is minted (token-id, owner, tier)
;;   - transfer-event: emitted when ownership changes (token-id, from, to)
;;   - burn-event: emitted when a pass is burned (token-id, owner, tier)

;; traits
;; - Trait definitions can be added here (e.g., SIP-009) for interface compatibility.

;; token definitions
;; - Bitdap Pass uses uint token-ids (u1, u2, ...) to identify each NFT.
;; - Each token-id is associated with exactly one owner and one tier.
;;

;; constants
;; - Collection-wide configuration, tier identifiers, and error codes.

;; Error codes
(define-constant ERR-INVALID-TIER (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-NOT-OWNER (err u102))
(define-constant ERR-SELF-TRANSFER (err u103))
(define-constant ERR-MAX-SUPPLY (err u104))
(define-constant ERR-MAX-TIER-SUPPLY (err u105))

;; Tiers are represented as uints for compact on-chain storage.
(define-constant TIER-BASIC u1)
(define-constant TIER-PRO u2)
(define-constant TIER-VIP u3)

;; Collection-wide and per-tier maximum supplies.
;; These are conservative defaults that can be adjusted in future versions.
(define-constant MAX-SUPPLY u10000)
(define-constant MAX-BASIC-SUPPLY u7000)
(define-constant MAX-PRO-SUPPLY u2500)
(define-constant MAX-VIP-SUPPLY u500)

;; data vars
;; - Global counters for token-ids and total supply.

;; Next token-id to mint (starts at u1).
(define-data-var next-token-id uint u1)

;; Total number of Bitdap Pass NFTs currently in circulation.
(define-data-var total-supply uint u0)

;; data maps
;; - Storage for token ownership, metadata, and per-tier supply.

;; token-id -> owner principal
(define-map token-owners
    { token-id: uint }
    { owner: principal }
)

;; token-id -> metadata (tier and optional off-chain URI)
(define-map token-metadata
    { token-id: uint }
    {
        tier: uint,
        uri: (optional (string-utf8 256)),
    }
)

;; tier -> current supply for that tier
(define-map tier-supplies
    { tier: uint }
    { supply: uint }
)

;; public functions
;; - Core NFT operations: mint, transfer, burn.

;; Mint a new Bitdap Pass NFT for the caller in the given tier.
;; - The recipient is always tx-sender for now; this keeps permissions simple:
;;   users can only mint passes for themselves.
;; - Enforces global and per-tier maximum supplies.
;; - Returns (ok token-id) on success, or an error constant on failure.
(define-read-only (get-max-supply)
    MAX-SUPPLY
)

(define-public (mint-pass
        (tier uint)
        (uri (optional (string-utf8 256)))
    )
    (begin
        ;; Validate tier first.
        (if (not (is-valid-tier tier))
            ERR-INVALID-TIER
            (let (
                    (current-total (var-get total-supply))
                    (new-total (+ current-total u1))
                )
                ;; Check global max supply.
                (if (> new-total MAX-SUPPLY)
                    ERR-MAX-SUPPLY
                    (let (
                            (tier-row (default-to { supply: u0 } (map-get? tier-supplies { tier: tier })))
                            (tier-supply (get supply tier-row))
                            (new-tier-supply (+ tier-supply u1))
                        )
                        ;; Check per-tier max supply.
                        (if (is-tier-over-max? tier new-tier-supply)
                            ERR-MAX-TIER-SUPPLY
                            (let (
                                    (token-id (var-get next-token-id))
                                    (recipient tx-sender)
                                )
                                (begin
                                    ;; Write ownership and metadata.
                                    (map-set token-owners { token-id: token-id } { owner: recipient })
                                    (map-set token-metadata { token-id: token-id } {
                                        tier: tier,
                                        uri: uri,
                                    })
                                    ;; Update counters.
                                    (map-set tier-supplies { tier: tier } { supply: new-tier-supply })
                                    (var-set total-supply new-total)
                                    (var-set next-token-id (+ token-id u1))
                                    ;; Emit mint event.
                                    (print (tuple
                                        (event "mint-event")
                                        (token-id token-id)
                                        (owner recipient)
                                        (tier tier)
                                    ))
                                    (ok token-id)
                                )
                            )
                        )
                    )
                )
            )
        )
    )
)

;; Transfer a Bitdap Pass NFT from the caller to a recipient.
;; - Only the current owner may transfer.
;; - Self-transfers (owner == recipient) are rejected as no-ops.
(define-public (transfer
        (token-id uint)
        (recipient principal)
    )
    (let ((owner-row (map-get? token-owners { token-id: token-id })))
        (match owner-row
            owner-data (let ((owner (get owner owner-data)))
                (if (not (is-eq owner tx-sender))
                    ERR-NOT-OWNER
                    (if (is-eq owner recipient)
                        ERR-SELF-TRANSFER
                        (begin
                            (map-set token-owners { token-id: token-id } { owner: recipient })
                            ;; Emit transfer event.
                            (print (tuple
                                (event "transfer-event")
                                (token-id token-id)
                                (from owner)
                                (to recipient)
                            ))
                            (ok true)
                        )
                    )
                )
            )
            ERR-NOT-FOUND
        )
    )
)

;; Burn (destroy) a Bitdap Pass NFT owned by the caller.
;; - Only the current owner may burn.
;; - Decrements total supply and the tier supply.
(define-public (burn (token-id uint))
    (let ((owner-row (map-get? token-owners { token-id: token-id })))
        (match owner-row
            owner-data (let ((owner (get owner owner-data)))
                (if (not (is-eq owner tx-sender))
                    ERR-NOT-OWNER
                    (let ((meta-row (map-get? token-metadata { token-id: token-id })))
                        (match meta-row
                            meta (let (
                                    (tier (get tier meta))
                                    (tier-row (default-to { supply: u0 } (map-get? tier-supplies { tier: tier })))
                                    (current-tier-supply (get supply tier-row))
                                )
                                (begin
                                    ;; Delete ownership and metadata.
                                    (map-delete token-owners { token-id: token-id })
                                    (map-delete token-metadata { token-id: token-id })
                                    ;; Decrement counters (clamped to zero by design choices).
                                    (map-set tier-supplies { tier: tier } { supply: (if (> current-tier-supply u0)
                                        (- current-tier-supply u1)
                                        u0
                                    ) }
                                    )
                                    (let ((current-total (var-get total-supply)))
                                        (var-set total-supply
                                            (if (> current-total u0)
                                                (- current-total u1)
                                                u0
                                            ))
                                    )
                                    ;; Emit burn event.
                                    (print (tuple
                                        (event "burn-event")
                                        (token-id token-id)
                                        (owner owner)
                                        (tier tier)
                                    ))
                                    (ok true)
                                )
                            )
                            ERR-NOT-FOUND
                        )
                    )
                )
            )
            ERR-NOT-FOUND
        )
    )
)

;; read only functions
;; - Views into ownership, metadata, and supply statistics (SIP-009 style).

;; SIP-009: returns the last minted token-id (or u0 if none exist).
(define-read-only (get-last-token-id)
    (let ((next-id (var-get next-token-id)))
        (if (is-eq next-id u1)
            (ok u0)
            (ok (- next-id u1))
        )
    )
)

;; SIP-009: returns the owner of a given token-id, if any.
(define-read-only (get-owner (token-id uint))
    (match (map-get? token-owners { token-id: token-id })
        owner-row (ok (get owner owner-row))
        ERR-NOT-FOUND
    )
)

;; SIP-009: returns the token URI for a given token-id, if present.
(define-read-only (get-token-uri (token-id uint))
    (match (map-get? token-metadata { token-id: token-id })
        meta (ok (get uri meta))
        ERR-NOT-FOUND
    )
)

;; Returns the full metadata record for a given token-id.
(define-read-only (get-token-metadata (token-id uint))
    (match (map-get? token-metadata { token-id: token-id })
        meta (ok meta)
        ERR-NOT-FOUND
    )
)

;; Returns the tier (Basic/Pro/VIP) for a given token-id.
(define-read-only (get-tier (token-id uint))
    (match (map-get? token-metadata { token-id: token-id })
        meta (ok (get tier meta))
        ERR-NOT-FOUND
    )
)

;; Returns the total supply of Bitdap Pass NFTs in circulation.
(define-read-only (get-total-supply)
    (ok (var-get total-supply))
)

;; Returns the supply for a specific tier.
(define-read-only (get-tier-supply (tier uint))
    (let (
            (row (default-to { supply: u0 } (map-get? tier-supplies { tier: tier })))
        )
        (ok (get supply row))
    )
)

;; private functions
;; - Internal helpers for validating tiers and managing counters/maps.

;; Returns true if the given tier is one of the known tiers.
(define-private (is-valid-tier (tier uint))
    (or
        (is-eq tier TIER-BASIC)
        (or
            (is-eq tier TIER-PRO)
            (is-eq tier TIER-VIP)
        )
    )
)

;; Returns true if the given (tier, new-supply) would exceed that tier's max.
(define-private (is-tier-over-max?
        (tier uint)
        (new-supply uint)
    )
    (if (is-eq tier TIER-BASIC)
        (> new-supply MAX-BASIC-SUPPLY)
        (if (is-eq tier TIER-PRO)
            (> new-supply MAX-PRO-SUPPLY)
            (if (is-eq tier TIER-VIP)
                (> new-supply MAX-VIP-SUPPLY)
                ;; Unknown tiers are treated as invalid via is-valid-tier, but
                ;; this path is left as not over max for safety.
                false
            )
        )
    )
)
