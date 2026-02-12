;; VDEX Governance Token
;; Verified DEX governance and reward token implementing SIP-010

;; ============================================
;; TRAITS
;; ============================================

(impl-trait .sip-010-trait.sip-010-trait)

;; ============================================
;; TOKEN DEFINITION
;; ============================================

(define-fungible-token VDEX u1000000000000000) ;; 1 billion max supply (6 decimals)

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant CONTRACT_OWNER tx-sender)

;; Errors
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_INSUFFICIENT_BALANCE (err u402))
(define-constant ERR_FARMING_CAP_EXCEEDED (err u403))
(define-constant ERR_ALREADY_INITIALIZED (err u404))
(define-constant ERR_NOT_INITIALIZED (err u405))

;; Token Distribution (in micro units - 6 decimals)
;; Total: 1,000,000,000 VDEX (1 billion)
(define-constant FARMING_ALLOCATION u400000000000000)    ;; 40% - 400M for farming rewards
(define-constant TREASURY_ALLOCATION u300000000000000)   ;; 30% - 300M treasury
(define-constant TEAM_ALLOCATION u150000000000000)       ;; 15% - 150M team (vested)
(define-constant AIRDROP_ALLOCATION u100000000000000)    ;; 10% - 100M airdrops/incentives
(define-constant LIQUIDITY_ALLOCATION u50000000000000)   ;; 5%  - 50M initial liquidity

;; ============================================
;; DATA VARIABLES
;; ============================================

(define-data-var token-uri (optional (string-utf8 256)) (some u"https://verified-dex.io/token/vdex.json"))
(define-data-var minter principal CONTRACT_OWNER)
(define-data-var is-initialized bool false)
(define-data-var farming-minted uint u0) ;; Track farming tokens minted

;; ============================================
;; DATA MAPS
;; ============================================

;; Authorization map for multiple minters
(define-map authorized-minters principal bool)

;; ============================================
;; INITIALIZATION
;; ============================================

(define-public (initialize (treasury-address principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (not (var-get is-initialized)) ERR_ALREADY_INITIALIZED)

    ;; Mint treasury allocation to treasury address
    (try! (ft-mint? VDEX TREASURY_ALLOCATION treasury-address))

    ;; Mint initial liquidity allocation to deployer
    (try! (ft-mint? VDEX LIQUIDITY_ALLOCATION CONTRACT_OWNER))

    ;; Mark as initialized
    (var-set is-initialized true)

    (print {
      event: "token-initialized",
      treasury: treasury-address,
      treasury-amount: TREASURY_ALLOCATION,
      liquidity-amount: LIQUIDITY_ALLOCATION
    })

    (ok true)
  )
)

;; ============================================
;; SIP-010 IMPLEMENTATION
;; ============================================

(define-read-only (get-name)
  (ok "Verified DEX Token")
)

(define-read-only (get-symbol)
  (ok "VDEX")
)

(define-read-only (get-decimals)
  (ok u6)
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance VDEX account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply VDEX))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

(define-public (transfer
  (amount uint)
  (sender principal)
  (recipient principal)
  (memo (optional (buff 34)))
)
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    (try! (ft-transfer? VDEX amount sender recipient))
    (match memo
      to-print (print to-print)
      0x
    )
    (print {
      event: "transfer",
      sender: sender,
      recipient: recipient,
      amount: amount
    })
    (ok true)
  )
)

;; ============================================
;; MINTING (For Farming Rewards)
;; ============================================

(define-public (mint (amount uint) (recipient principal))
  (let (
    (current-farming-minted (var-get farming-minted))
    (new-farming-minted (+ current-farming-minted amount))
  )
    ;; Check authorization
    (asserts!
      (or
        (is-eq tx-sender (var-get minter))
        (default-to false (map-get? authorized-minters tx-sender))
      )
      ERR_NOT_AUTHORIZED
    )

    ;; Check farming allocation cap
    (asserts!
      (<= new-farming-minted FARMING_ALLOCATION)
      ERR_FARMING_CAP_EXCEEDED
    )

    ;; Mint tokens
    (try! (ft-mint? VDEX amount recipient))

    ;; Update farming minted counter
    (var-set farming-minted new-farming-minted)

    (print {
      event: "tokens-minted",
      recipient: recipient,
      amount: amount,
      total-farming-minted: new-farming-minted,
      remaining-farming: (- FARMING_ALLOCATION new-farming-minted)
    })

    (ok true)
  )
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

(define-public (set-minter (new-minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set minter new-minter)
    (print {
      event: "minter-updated",
      old-minter: (var-get minter),
      new-minter: new-minter
    })
    (ok true)
  )
)

(define-public (authorize-minter (minter-address principal) (authorized bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set authorized-minters minter-address authorized)
    (print {
      event: "minter-authorization",
      minter: minter-address,
      authorized: authorized
    })
    (ok true)
  )
)

(define-public (set-token-uri (new-uri (string-utf8 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set token-uri (some new-uri))
    (print { event: "token-uri-updated", uri: new-uri })
    (ok true)
  )
)

;; ============================================
;; BURN FUNCTION
;; ============================================

(define-public (burn (amount uint))
  (begin
    (try! (ft-burn? VDEX amount tx-sender))
    (print {
      event: "tokens-burned",
      burner: tx-sender,
      amount: amount,
      remaining-balance: (ft-get-balance VDEX tx-sender)
    })
    (ok true)
  )
)

;; ============================================
;; READ-ONLY HELPERS
;; ============================================

(define-read-only (is-authorized-minter (account principal))
  (or
    (is-eq account (var-get minter))
    (default-to false (map-get? authorized-minters account))
  )
)

(define-read-only (get-remaining-farm-supply)
  (- FARMING_ALLOCATION (var-get farming-minted))
)

(define-read-only (get-farming-minted)
  (var-get farming-minted)
)

(define-read-only (get-allocation-info)
  {
    farming: FARMING_ALLOCATION,
    treasury: TREASURY_ALLOCATION,
    team: TEAM_ALLOCATION,
    airdrop: AIRDROP_ALLOCATION,
    liquidity: LIQUIDITY_ALLOCATION,
    total-max: (+ FARMING_ALLOCATION
                 (+ TREASURY_ALLOCATION
                   (+ TEAM_ALLOCATION
                     (+ AIRDROP_ALLOCATION LIQUIDITY_ALLOCATION))))
  }
)

(define-read-only (is-initialized-check)
  (var-get is-initialized)
)

(define-read-only (get-minter)
  (var-get minter)
)

;; ============================================
;; EMERGENCY FUNCTIONS
;; ============================================

;; Emergency pause (if needed in future)
;; Can be added here for additional security
