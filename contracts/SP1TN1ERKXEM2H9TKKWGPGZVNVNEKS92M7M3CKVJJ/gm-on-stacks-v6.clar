;; GM ON STACKS - MAINNET (FIXED - NO TRAIT ISSUES)

;; =========================================================================
;; CONSTANTS
;; =========================================================================
(define-constant CONTRACT_OWNER tx-sender)
(define-constant GM_FEE u100000)
(define-constant NFT_FEE_STREAK u1000000)
(define-constant NFT_FEE_NORMAL u33000000)
(define-constant STREAK_THRESHOLD u21)
(define-constant BLOCKS_PER_DAY u144)
(define-constant STREAK_WINDOW u288)

(define-constant ERR_NOT_TOKEN_OWNER (err u100))
(define-constant ERR_NOT_AUTHORIZED (err u101))

;; =========================================================================
;; DATA VARS & MAPS
;; =========================================================================
(define-non-fungible-token gm-nft uint)
(define-data-var last-token-id uint u0)
(define-data-var total-gms uint u0)
(define-data-var base-uri (string-ascii 256) 
    "ipfs://bafkreig36opxlfdedhbgaiwyedlqmpwvdeonbgxnv5v6fv2avurffvc2gq")

(define-map UserStreak principal {
    current-streak: uint,
    last-gm-block: uint,
    total-gms: uint,
    longest-streak: uint
})

(define-map UserGM principal (string-ascii 64))

;; =========================================================================
;; READ-ONLY FUNCTIONS
;; =========================================================================
(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
    (ok (some (var-get base-uri)))
)

(define-public (set-base-uri (new-base-uri (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set base-uri new-base-uri)
        (ok true)
    )
)



(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? gm-nft token-id))
)

(define-read-only (get-total-gms)
    (ok (var-get total-gms))
)

(define-read-only (get-user-streak (user principal))
    (match (map-get? UserStreak user)
        streak-data (ok streak-data)
        (ok {
            current-streak: u0,
            last-gm-block: u0,
            total-gms: u0,
            longest-streak: u0
        })
    )
)

(define-read-only (get-effective-streak (user principal))
    (match (map-get? UserStreak user)
        streak-data 
        (let ((blocks-since-last (- stacks-block-height (get last-gm-block streak-data))))
            (if (> blocks-since-last STREAK_WINDOW)
                (ok u0)
                (ok (get current-streak streak-data))
            )
        )
        (ok u0)
    )
)

;; =========================================================================
;; PRIVATE FUNCTIONS
;; =========================================================================
(define-private (calculate-new-streak (last-block uint) (current-streak uint))
    (let ((blocks-since-last (- stacks-block-height last-block)))
        (if (is-eq last-block u0)
            u1
            (if (<= blocks-since-last STREAK_WINDOW)
                (+ current-streak u1)
                u1
            )
        )
    )
)

(define-private (pay-fee (amount uint) (payer principal))
    (if (is-eq payer CONTRACT_OWNER)
        (ok true)
        (stx-transfer? amount payer CONTRACT_OWNER)
    )
)

;; =========================================================================
;; PUBLIC FUNCTIONS
;; =========================================================================
(define-public (say-gm)
    (let (
        (sender tx-sender)
        (current-count (var-get total-gms))
        (user-data (default-to 
            { current-streak: u0, last-gm-block: u0, total-gms: u0, longest-streak: u0 }
            (map-get? UserStreak sender)
        ))
        (new-streak (calculate-new-streak (get last-gm-block user-data) (get current-streak user-data)))
        (new-longest (if (> new-streak (get longest-streak user-data)) new-streak (get longest-streak user-data)))
    )
        (try! (pay-fee GM_FEE sender))
        (map-set UserStreak sender {
            current-streak: new-streak,
            last-gm-block: stacks-block-height,
            total-gms: (+ (get total-gms user-data) u1),
            longest-streak: new-longest
        })
        (map-set UserGM sender "gm")
        (var-set total-gms (+ current-count u1))
        (ok { gm-count: (+ current-count u1), streak: new-streak, longest-streak: new-longest })
    )
)

(define-public (mint-gm-nft)
    (let (
        (next-id (+ (var-get last-token-id) u1))
        (buyer tx-sender)
        (effective-streak (unwrap-panic (get-effective-streak buyer)))
        (nft-fee (if (>= effective-streak STREAK_THRESHOLD) NFT_FEE_STREAK NFT_FEE_NORMAL))
    )
        (try! (pay-fee nft-fee buyer))
        (try! (nft-mint? gm-nft next-id buyer))
        (var-set last-token-id next-id)
        (var-set total-gms (+ (var-get total-gms) u1))
        (ok { token-id: next-id, fee-paid: nft-fee, had-discount: (>= effective-streak STREAK_THRESHOLD) })
    )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR_NOT_TOKEN_OWNER)
        (nft-transfer? gm-nft token-id sender recipient)
    )
)
