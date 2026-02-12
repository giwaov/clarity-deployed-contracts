;; Gaga Finance Escrow Contract
;; Securely holds STX and NFTs during marketplace transactions
;; Only authorized contracts can interact with escrowed assets

;; ============================================
;; CONSTANTS - Error Codes
;; ============================================
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INSUFFICIENT-BALANCE (err u201))
(define-constant ERR-TRANSFER-FAILED (err u202))
(define-constant ERR-NOT-FOUND (err u203))
(define-constant ERR-ALREADY-EXISTS (err u204))
(define-constant ERR-CONTRACT-PAUSED (err u205))
(define-constant ERR-INVALID-AMOUNT (err u206))
(define-constant ERR-INVALID-CALLER (err u207))
(define-constant ERR-EMERGENCY-ONLY (err u208))
(define-constant ERR-NFT-NOT-ESCROWED (err u209))

;; ============================================
;; CONFIGURATION
;; ============================================
(define-constant CONTRACT-OWNER tx-sender)

;; ============================================
;; DATA VARIABLES
;; ============================================
(define-data-var is-paused bool false)
(define-data-var emergency-mode bool false)
(define-data-var marketplace-contract principal CONTRACT-OWNER)
(define-data-var auction-contract principal CONTRACT-OWNER)

;; ============================================
;; DATA MAPS
;; ============================================

;; STX balances held in escrow per user
(define-map stx-balances principal uint)

;; NFT escrow tracking: { nft-contract, token-id } -> { owner, listing-id }
(define-map escrowed-nfts 
  { nft-contract: principal, token-id: uint } 
  { owner: principal, listing-id: uint }
)

;; Total STX held in escrow
(define-data-var total-escrowed-stx uint u0)

;; ============================================
;; AUTHORIZATION CHECKS
;; ============================================

(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-authorized-caller)
  (or 
    (is-eq contract-caller (var-get marketplace-contract))
    (is-eq contract-caller (var-get auction-contract))
    (is-contract-owner)
  )
)

(define-private (assert-not-paused)
  (ok (asserts! (not (var-get is-paused)) ERR-CONTRACT-PAUSED))
)

(define-private (assert-authorized)
  (ok (asserts! (is-authorized-caller) ERR-NOT-AUTHORIZED))
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

;; Get STX balance held in escrow for a user
(define-read-only (get-stx-balance (user principal))
  (ok (default-to u0 (map-get? stx-balances user)))
)

;; Check if NFT is in escrow
(define-read-only (is-nft-escrowed (nft-contract principal) (token-id uint))
  (is-some (map-get? escrowed-nfts { nft-contract: nft-contract, token-id: token-id }))
)

;; Get NFT escrow details
(define-read-only (get-nft-escrow-info (nft-contract principal) (token-id uint))
  (ok (map-get? escrowed-nfts { nft-contract: nft-contract, token-id: token-id }))
)

;; Get total STX held in escrow
(define-read-only (get-total-escrowed-stx)
  (ok (var-get total-escrowed-stx))
)

;; Check pause status
(define-read-only (is-contract-paused)
  (ok (var-get is-paused))
)

;; Check emergency mode
(define-read-only (is-emergency-mode)
  (ok (var-get emergency-mode))
)

;; Get marketplace contract
(define-read-only (get-marketplace-contract)
  (ok (var-get marketplace-contract))
)

;; Get auction contract
(define-read-only (get-auction-contract)
  (ok (var-get auction-contract))
)

;; ============================================
;; STX ESCROW FUNCTIONS
;; ============================================

;; Deposit STX into escrow (called by marketplace/auction)
(define-public (deposit-stx (user principal) (amount uint))
  (begin
    (try! (assert-not-paused))
    (try! (assert-authorized))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Transfer STX from user to this contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update user's escrow balance
    (let (
      (current-balance (default-to u0 (map-get? stx-balances user)))
      (new-balance (+ current-balance amount))
    )
      (map-set stx-balances user new-balance)
      (var-set total-escrowed-stx (+ (var-get total-escrowed-stx) amount))
      
      (print { 
        event: "stx-deposited",
        user: user,
        amount: amount,
        new-balance: new-balance
      })
      
      (ok true)
    )
  )
)

;; Release STX from escrow to recipient
(define-public (release-stx (from-user principal) (to-recipient principal) (amount uint))
  (begin
    (try! (assert-not-paused))
    (try! (assert-authorized))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    (let (
      (current-balance (default-to u0 (map-get? stx-balances from-user)))
    )
      ;; Check sufficient balance
      (asserts! (>= current-balance amount) ERR-INSUFFICIENT-BALANCE)
      
      ;; Update balance
      (map-set stx-balances from-user (- current-balance amount))
      (var-set total-escrowed-stx (- (var-get total-escrowed-stx) amount))
      
      ;; Transfer STX to recipient
      (try! (as-contract (stx-transfer? amount tx-sender to-recipient)))
      
      (print { 
        event: "stx-released",
        from: from-user,
        to: to-recipient,
        amount: amount
      })
      
      (ok true)
    )
  )
)

;; Refund STX back to original depositor
(define-public (refund-stx (user principal) (amount uint))
  (begin
    (try! (assert-not-paused))
    (try! (assert-authorized))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    (let (
      (current-balance (default-to u0 (map-get? stx-balances user)))
    )
      (asserts! (>= current-balance amount) ERR-INSUFFICIENT-BALANCE)
      
      (map-set stx-balances user (- current-balance amount))
      (var-set total-escrowed-stx (- (var-get total-escrowed-stx) amount))
      
      (try! (as-contract (stx-transfer? amount tx-sender user)))
      
      (print { 
        event: "stx-refunded",
        user: user,
        amount: amount
      })
      
      (ok true)
    )
  )
)

;; ============================================
;; NFT ESCROW FUNCTIONS
;; ============================================

;; Escrow an NFT (for listings)
(define-public (escrow-nft (nft-contract principal) (token-id uint) (owner principal) (listing-id uint))
  (begin
    (try! (assert-not-paused))
    (try! (assert-authorized))
    
    ;; Check NFT is not already escrowed
    (asserts! (not (is-nft-escrowed nft-contract token-id)) ERR-ALREADY-EXISTS)
    
    ;; Record escrow
    (map-set escrowed-nfts 
      { nft-contract: nft-contract, token-id: token-id }
      { owner: owner, listing-id: listing-id }
    )
    
    (print { 
      event: "nft-escrowed",
      nft-contract: nft-contract,
      token-id: token-id,
      owner: owner,
      listing-id: listing-id
    })
    
    (ok true)
  )
)

;; Release NFT from escrow
(define-public (release-nft (nft-contract principal) (token-id uint))
  (begin
    (try! (assert-not-paused))
    (try! (assert-authorized))
    
    ;; Check NFT is escrowed
    (asserts! (is-nft-escrowed nft-contract token-id) ERR-NFT-NOT-ESCROWED)
    
    ;; Remove from escrow tracking
    (map-delete escrowed-nfts { nft-contract: nft-contract, token-id: token-id })
    
    (print { 
      event: "nft-released",
      nft-contract: nft-contract,
      token-id: token-id
    })
    
    (ok true)
  )
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

;; Set marketplace contract address
(define-public (set-marketplace-contract (new-marketplace principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set marketplace-contract new-marketplace)
    (print { event: "marketplace-contract-updated", contract: new-marketplace })
    (ok true)
  )
)

;; Set auction contract address
(define-public (set-auction-contract (new-auction principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set auction-contract new-auction)
    (print { event: "auction-contract-updated", contract: new-auction })
    (ok true)
  )
)

;; Pause contract
(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set is-paused paused)
    (print { event: "pause-status-changed", paused: paused })
    (ok true)
  )
)

;; Enable emergency mode
(define-public (set-emergency-mode (enabled bool))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set emergency-mode enabled)
    (var-set is-paused enabled) ;; Also pause when emergency
    (print { event: "emergency-mode-changed", enabled: enabled })
    (ok true)
  )
)

;; ============================================
;; EMERGENCY RECOVERY (OWNER ONLY)
;; ============================================

;; Emergency withdraw STX (only in emergency mode, owner only)
(define-public (emergency-withdraw-stx (recipient principal) (amount uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (var-get emergency-mode) ERR-EMERGENCY-ONLY)
    
    (try! (as-contract (stx-transfer? amount tx-sender recipient)))
    
    (print { 
      event: "emergency-stx-withdrawal",
      recipient: recipient,
      amount: amount
    })
    
    (ok true)
  )
)

;; Clear stuck NFT escrow record (emergency only)
(define-public (emergency-clear-nft-escrow (nft-contract principal) (token-id uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (var-get emergency-mode) ERR-EMERGENCY-ONLY)
    
    (map-delete escrowed-nfts { nft-contract: nft-contract, token-id: token-id })
    
    (print { 
      event: "emergency-nft-escrow-cleared",
      nft-contract: nft-contract,
      token-id: token-id
    })
    
    (ok true)
  )
)