;; quest-badge-nft
;; Quest Badge NFT - Minted upon quest completion following SIP-009 NFT standard
;; Each badge represents mastery of a specific DeFi protocol

;; Implement SIP-009 NFT trait
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Define the NFT
(define-non-fungible-token quest-badge uint)

;; Data vars
(define-data-var last-token-id uint u0)
(define-data-var base-token-uri (string-ascii 256) "https://stxfinance.xyz/api/metadata/")

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_NOT_TOKEN_OWNER (err u101))
(define-constant ERR_UNAUTHORIZED (err u103))
(define-constant ERR_ALREADY_CLAIMED (err u104))
(define-constant ERR_INVALID_QUEST (err u105))

;; Map token ID to quest info
(define-map token-info
    uint
    {
        protocol: (string-ascii 50),
        owner: principal,
        completion-date: uint,
        xp-earned: uint,
    }
)

;; Map user + protocol to token ID (prevent duplicate claims)
(define-map user-protocol-badge
    {
        user: principal,
        protocol: (string-ascii 50),
    }
    uint
)

;; Track total badges minted per protocol
(define-map protocol-badge-count
    (string-ascii 50)
    uint
)

;; Valid protocol names
(define-map valid-protocols
    (string-ascii 50)
    {
        active: bool,
        xp-reward: uint,
    }
)

;; SIP-009 required functions

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
    (if (> (len (var-get base-token-uri)) u0)
        (ok (some (var-get base-token-uri)))
        (ok none)
    )
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? quest-badge token-id))
)

;; Transfer function - Soul-bound badges cannot be transferred
;; They represent personal achievement and cannot be traded
(define-public (transfer
        (token-id uint)
        (sender principal)
        (recipient principal)
    )
    ERR_UNAUTHORIZED
)

;; Core minting function

;; Mint NFT badge for quest completion
;; Anyone can call this to mint their own badge after completing a quest
(define-public (mint-badge (protocol (string-ascii 50)))
    (let (
            (token-id (+ (var-get last-token-id) u1))
            (protocol-info (unwrap! (map-get? valid-protocols protocol) ERR_INVALID_QUEST))
            (current-count (default-to u0 (map-get? protocol-badge-count protocol)))
        )
        ;; Check if protocol is active
        (asserts! (get active protocol-info) ERR_INVALID_QUEST)

        ;; Check if user already has badge for this protocol
        (asserts!
            (is-none (map-get? user-protocol-badge {
                user: tx-sender,
                protocol: protocol,
            }))
            ERR_ALREADY_CLAIMED
        )

        ;; Mint the NFT to the caller
        (try! (nft-mint? quest-badge token-id tx-sender))

        ;; Update data
        (var-set last-token-id token-id)
        (map-set token-info token-id {
            protocol: protocol,
            owner: tx-sender,
            completion-date: stacks-block-height,
            xp-earned: (get xp-reward protocol-info),
        })
        (map-set user-protocol-badge {
            user: tx-sender,
            protocol: protocol,
        }
            token-id
        )
        (map-set protocol-badge-count protocol (+ current-count u1))

        (ok token-id)
    )
)

;; Read-only functions

;; Get badge information
(define-read-only (get-badge-info (token-id uint))
    (ok (map-get? token-info token-id))
)

;; Get user's badge for a specific protocol
(define-read-only (get-user-badge
        (user principal)
        (protocol (string-ascii 50))
    )
    (ok (map-get? user-protocol-badge {
        user: user,
        protocol: protocol,
    }))
)

;; Check if user has completed a protocol quest
(define-read-only (has-completed-protocol
        (user principal)
        (protocol (string-ascii 50))
    )
    (ok (is-some (map-get? user-protocol-badge {
        user: user,
        protocol: protocol,
    })))
)

;; Get total badges minted for a protocol
(define-read-only (get-protocol-badge-count (protocol (string-ascii 50)))
    (ok (default-to u0 (map-get? protocol-badge-count protocol)))
)

;; Get protocol info
(define-read-only (get-protocol-info (protocol (string-ascii 50)))
    (ok (map-get? valid-protocols protocol))
)

;; Admin functions

;; Initialize or update a protocol
;; #[allow(unchecked_data)]
(define-public (set-protocol
        (protocol (string-ascii 50))
        (active bool)
        (xp-reward uint)
    )
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
        (map-set valid-protocols protocol {
            active: active,
            xp-reward: xp-reward,
        })
        (ok true)
    )
)

;; Set base token URI
;; #[allow(unchecked_data)]
(define-public (set-base-token-uri (uri (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
        (var-set base-token-uri uri)
        (ok true)
    )
)

;; Initialize default protocols 
(map-set valid-protocols "zest" {
    active: true,
    xp-reward: u50,
})
(map-set valid-protocols "stackingdao" {
    active: true,
    xp-reward: u60,
})
(map-set valid-protocols "granite" {
    active: true,
    xp-reward: u70,
})
(map-set valid-protocols "hermetica" {
    active: true,
    xp-reward: u65,
})
(map-set valid-protocols "arkadiko" {
    active: true,
    xp-reward: u55,
})
