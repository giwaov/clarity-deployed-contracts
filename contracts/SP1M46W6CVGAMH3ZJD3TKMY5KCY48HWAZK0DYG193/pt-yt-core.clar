;; Stakied PT/YT Core - Principal & Yield Token Minting/Redemption

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-authorized (err u201))
(define-constant err-invalid-amount (err u202))
(define-constant err-insufficient-balance (err u203))
(define-constant err-maturity-not-reached (err u204))
(define-constant err-already-matured (err u205))
(define-constant err-invalid-maturity (err u206))

;; Data variables
(define-data-var sy-contract principal contract-owner)

;; PT (Principal Token) data
(define-map pt-balances {user: principal, maturity: uint} uint)
(define-map pt-total-supply uint uint)

;; YT (Yield Token) data
(define-map yt-balances {user: principal, maturity: uint} uint)
(define-map yt-total-supply uint uint)
(define-map yt-claimed-yield {user: principal, maturity: uint} uint)

;; Read-only functions
(define-read-only (get-pt-balance (user principal) (maturity uint))
  (ok (default-to u0 (map-get? pt-balances {user: user, maturity: maturity}))))

(define-read-only (get-yt-balance (user principal) (maturity uint))
  (ok (default-to u0 (map-get? yt-balances {user: user, maturity: maturity}))))

(define-read-only (get-pt-total-supply (maturity uint))
  (ok (default-to u0 (map-get? pt-total-supply maturity))))

(define-read-only (get-yt-total-supply (maturity uint))
  (ok (default-to u0 (map-get? yt-total-supply maturity))))

(define-public (mint-pt-yt (sy-amount uint) (maturity uint))
  (begin
    (asserts! (> sy-amount u0) err-invalid-amount)
    (asserts! (> maturity stacks-block-height) err-invalid-maturity)
    
    ;; TODO Phase 2: Transfer SY from user to this contract
    ;; This will require implementing a custodial pattern or using contract-call with proper authorization
    
    ;; Mint PT tokens
    (let ((current-pt-balance (default-to u0 (map-get? pt-balances {user: tx-sender, maturity: maturity}))))
      (map-set pt-balances {user: tx-sender, maturity: maturity} (+ current-pt-balance sy-amount))
      (map-set pt-total-supply maturity (+ (default-to u0 (map-get? pt-total-supply maturity)) sy-amount))
    )
    
    ;; Mint YT tokens (same amount as PT)
    (let ((current-yt-balance (default-to u0 (map-get? yt-balances {user: tx-sender, maturity: maturity}))))
      (map-set yt-balances {user: tx-sender, maturity: maturity} (+ current-yt-balance sy-amount))
      (map-set yt-total-supply maturity (+ (default-to u0 (map-get? yt-total-supply maturity)) sy-amount))
    )
    
    (print {action: "mint-pt-yt", user: tx-sender, amount: sy-amount, maturity: maturity})
    (ok {pt: sy-amount, yt: sy-amount})
  )
)

(define-public (redeem-matured-pt (pt-amount uint) (maturity uint))
  (begin
    (asserts! (> pt-amount u0) err-invalid-amount)
    (asserts! (>= stacks-block-height maturity) err-maturity-not-reached)
    
    (let ((user-pt-balance (default-to u0 (map-get? pt-balances {user: tx-sender, maturity: maturity}))))
      (asserts! (>= user-pt-balance pt-amount) err-insufficient-balance)
      
      ;; Burn PT tokens
      (map-set pt-balances {user: tx-sender, maturity: maturity} (- user-pt-balance pt-amount))
      (map-set pt-total-supply maturity (- (default-to u0 (map-get? pt-total-supply maturity)) pt-amount))
      
      ;; TODO Phase 2: Transfer SY back to user (1:1 redemption)
      
      (print {action: "redeem-pt", user: tx-sender, amount: pt-amount, maturity: maturity})
      (ok pt-amount)
    )
  )
)

(define-public (redeem-pt-yt (amount uint) (maturity uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    
    (let (
      (user-pt-balance (default-to u0 (map-get? pt-balances {user: tx-sender, maturity: maturity})))
      (user-yt-balance (default-to u0 (map-get? yt-balances {user: tx-sender, maturity: maturity})))
    )
      (asserts! (>= user-pt-balance amount) err-insufficient-balance)
      (asserts! (>= user-yt-balance amount) err-insufficient-balance)
      
      ;; Burn PT tokens
      (map-set pt-balances {user: tx-sender, maturity: maturity} (- user-pt-balance amount))
      (map-set pt-total-supply maturity (- (default-to u0 (map-get? pt-total-supply maturity)) amount))
      
      ;; Burn YT tokens
      (map-set yt-balances {user: tx-sender, maturity: maturity} (- user-yt-balance amount))
      (map-set yt-total-supply maturity (- (default-to u0 (map-get? yt-total-supply maturity)) amount))
      
      ;; TODO Phase 2: Return SY to user
      
      (print {action: "redeem-pt-yt", user: tx-sender, amount: amount, maturity: maturity})
      (ok amount)
    )
  )
)

(define-read-only (calculate-claimable-yield (user principal) (maturity uint))
  (let (
    (user-yt-balance (default-to u0 (map-get? yt-balances {user: user, maturity: maturity})))
    (total-yt-supply (default-to u1 (map-get? yt-total-supply maturity)))
    (already-claimed (default-to u0 (map-get? yt-claimed-yield {user: user, maturity: maturity})))
  )
    ;; Simplified: assume 8% APY prorata distribution
    ;; Real implementation would query SY contract for actual yield
    (let ((total-yield (* user-yt-balance u8)))
      (ok (if (> total-yield already-claimed)
            (- total-yield already-claimed)
            u0))
    )
  )
)

(define-public (claim-yield (maturity uint))
  (let (
    (claimable (unwrap! (calculate-claimable-yield tx-sender maturity) err-invalid-amount))
  )
    (asserts! (> claimable u0) err-invalid-amount)
    
    ;; Update claimed amount
    (let ((already-claimed (default-to u0 (map-get? yt-claimed-yield {user: tx-sender, maturity: maturity}))))
      (map-set yt-claimed-yield {user: tx-sender, maturity: maturity} (+ already-claimed claimable))
    )
    
    ;; TODO: Transfer yield (STX or SY) to user
    
    (print {action: "claim-yield", user: tx-sender, amount: claimable, maturity: maturity})
    (ok claimable)
  )
)
