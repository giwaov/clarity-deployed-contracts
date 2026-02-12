;; GM ON STACKS v2 - MAINNET
;; =========================================================================
;; Features:
;; - GM Streak: Track daily GMs and reward consistent users
;; - Tiered NFT Pricing: 1 STX for 21+ day streak, 33 STX otherwise
;; =========================================================================
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; =========================================================================
;; CONSTANTS
;; =========================================================================
(define-constant CONTRACT_OWNER tx-sender)
(define-constant GM_FEE u100000)              ;; 0.1 STX
(define-constant NFT_FEE_STREAK u1000000)     ;; 1 STX (21+ day streak)
(define-constant NFT_FEE_NORMAL u33000000)    ;; 33 STX (no streak / <21 days)
(define-constant STREAK_THRESHOLD u21)        ;; Days required for discount
(define-constant BLOCKS_PER_DAY u144)         ;; ~10 min blocks = 144/day
(define-constant STREAK_WINDOW u288)          ;; 2 days grace period in blocks

(define-constant ERR_NOT_TOKEN_OWNER (err u100))
(define-constant ERR_NOT_AUTHORIZED (err u101))
(define-constant ERR_INSUFFICIENT_FUNDS (err u102))

;; =========================================================================
;; DATA VARS & MAPS
;; =========================================================================
(define-non-fungible-token gm-nft uint)
(define-data-var last-token-id uint u0)
(define-data-var total-gms uint u0)
(define-data-var base-uri (string-ascii 256) "ipfs://bafybeid7zjg55ukcb3qvi2dd4psbs7fz4ivds7xgrmsp55nzuwslftxnp4")

;; User streak data
(define-map UserStreak principal {
    current-streak: uint,
    last-gm-block: uint,
    total-gms: uint,
    longest-streak: uint
})

;; Legacy user GM map (for backwards compatibility)
(define-map UserGM principal (string-ascii 64))

;; =========================================================================
;; SIP-009 NFT TRAIT FUNCTIONS
;; =========================================================================
(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
    (ok (some (var-get base-uri)))
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? gm-nft token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR_NOT_TOKEN_OWNER)
        (nft-transfer? gm-nft token-id sender recipient)
    )
)

;; =========================================================================
;; READ-ONLY FUNCTIONS
;; =========================================================================
(define-read-only (get-total-gms)
    (ok (var-get total-gms))
)

(define-read-only (get-user-gm (user principal))
    (ok (map-get? UserGM user))
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

;; Calculate the current effective streak (accounting for missed days)
(define-read-only (get-effective-streak (user principal))
    (match (map-get? UserStreak user)
        streak-data 
        (let (
            (blocks-since-last (- stacks-block-height (get last-gm-block streak-data)))
        )
            ;; If more than STREAK_WINDOW blocks have passed, streak is broken
            (if (> blocks-since-last STREAK_WINDOW)
                (ok u0)
                (ok (get current-streak streak-data))
            )
        )
        (ok u0)
    )
)

;; Get the NFT price for a user based on their streak
(define-read-only (get-nft-price (user principal))
    (let (
        (effective-streak (unwrap-panic (get-effective-streak user)))
    )
        (if (>= effective-streak STREAK_THRESHOLD)
            (ok NFT_FEE_STREAK)
            (ok NFT_FEE_NORMAL)
        )
    )
)

;; Check if user qualifies for streak discount
(define-read-only (has-streak-discount (user principal))
    (let (
        (effective-streak (unwrap-panic (get-effective-streak user)))
    )
        (ok (>= effective-streak STREAK_THRESHOLD))
    )
)

;; =========================================================================
;; PRIVATE FUNCTIONS
;; =========================================================================

;; Calculate new streak based on time since last GM
(define-private (calculate-new-streak (last-block uint) (current-streak uint))
    (let (
        (blocks-since-last (- stacks-block-height last-block))
    )
        ;; First time (last-block is 0)
        (if (is-eq last-block u0)
            u1
            ;; Within streak window: increment
            (if (<= blocks-since-last STREAK_WINDOW)
                (+ current-streak u1)
                ;; Streak broken: reset to 1
                u1
            )
        )
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
        (new-streak (calculate-new-streak 
            (get last-gm-block user-data) 
            (get current-streak user-data)
        ))
        (new-longest (if (> new-streak (get longest-streak user-data))
            new-streak
            (get longest-streak user-data)
        ))
    )
        ;; Charge GM fee
        (try! (stx-transfer? GM_FEE sender CONTRACT_OWNER))
        
        ;; Update user streak data
        (map-set UserStreak sender {
            current-streak: new-streak,
            last-gm-block: stacks-block-height,
            total-gms: (+ (get total-gms user-data) u1),
            longest-streak: new-longest
        })
        
        ;; Update legacy map
        (map-set UserGM sender "gm")
        
        ;; Increment global counter
        (var-set total-gms (+ current-count u1))
        
        (ok {
            gm-count: (+ current-count u1),
            streak: new-streak,
            longest-streak: new-longest
        })
    )
)

(define-public (say-gm-message (message (string-ascii 64)))
    (let (
        (sender tx-sender)
        (current-count (var-get total-gms))
        (user-data (default-to 
            { current-streak: u0, last-gm-block: u0, total-gms: u0, longest-streak: u0 }
            (map-get? UserStreak sender)
        ))
        (new-streak (calculate-new-streak 
            (get last-gm-block user-data) 
            (get current-streak user-data)
        ))
        (new-longest (if (> new-streak (get longest-streak user-data))
            new-streak
            (get longest-streak user-data)
        ))
    )
        ;; Charge GM fee
        (try! (stx-transfer? GM_FEE sender CONTRACT_OWNER))
        
        ;; Update user streak data
        (map-set UserStreak sender {
            current-streak: new-streak,
            last-gm-block: stacks-block-height,
            total-gms: (+ (get total-gms user-data) u1),
            longest-streak: new-longest
        })
        
        ;; Update legacy map with custom message
        (map-set UserGM sender message)
        
        ;; Increment global counter
        (var-set total-gms (+ current-count u1))
        
        (ok {
            gm-count: (+ current-count u1),
            streak: new-streak,
            message: message
        })
    )
)

(define-public (mint-gm-nft)
    (let (
        (next-id (+ (var-get last-token-id) u1))
        (buyer tx-sender)
        (effective-streak (unwrap-panic (get-effective-streak buyer)))
        (nft-fee (if (>= effective-streak STREAK_THRESHOLD)
            NFT_FEE_STREAK
            NFT_FEE_NORMAL
        ))
    )
        ;; Charge appropriate fee based on streak
        (try! (stx-transfer? nft-fee buyer CONTRACT_OWNER))
        
        ;; Mint NFT
        (try! (nft-mint? gm-nft next-id buyer))
        
        ;; Update counters
        (var-set last-token-id next-id)
        (var-set total-gms (+ (var-get total-gms) u1))
        
        (ok {
            token-id: next-id,
            fee-paid: nft-fee,
            had-discount: (>= effective-streak STREAK_THRESHOLD)
        })
    )
)

;; =========================================================================
;; ADMIN FUNCTIONS
;; =========================================================================
(define-public (set-base-uri (new-uri (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set base-uri new-uri)
        (ok true)
    )
)
