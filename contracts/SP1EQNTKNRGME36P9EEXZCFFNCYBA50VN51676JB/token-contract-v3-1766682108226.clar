;; This contract implements the SIP-010 community-standard Fungible Token trait.
;; Simplified version with minting pause control and max supply.

;; Define the FT, with a configurable maximum supply enforced in `mint`
(define-fungible-token clarity-coin)

;; ===== ERROR CODES =====

;; Authorization errors (100-109)
(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_NOT_TOKEN_OWNER (err u101))

;; Transfer errors (110-119)
(define-constant ERR_INSUFFICIENT_BALANCE (err u110))
(define-constant ERR_INSUFFICIENT_ALLOWANCE (err u111))
(define-constant ERR_INVALID_AMOUNT (err u112))
(define-constant ERR_INVALID_RECIPIENT (err u113))
(define-constant ERR_SELF_TRANSFER (err u114))

;; Allowance errors (120-129)
(define-constant ERR_ALLOWANCE_OVERFLOW (err u120))
(define-constant ERR_ALLOWANCE_UNDERFLOW (err u121))

;; General errors (130-139)
(define-constant ERR_INVALID_PARAMETER (err u130))
(define-constant ERR_MINTING_PAUSED (err u131))
(define-constant ERR_MAX_SUPPLY_EXCEEDED (err u132))

;; ===== CONSTANTS =====

(define-constant CONTRACT_OWNER tx-sender)
(define-constant TOKEN_NAME "Clarity Coin")
(define-constant TOKEN_SYMBOL "CC")
(define-constant TOKEN_DECIMALS u6)
(define-constant MAX_UINT u340282366920938463463374607431768211455)
(define-constant MAX_SUPPLY (* u1000000 u1000000))

;; ===== DATA VARIABLES =====

;; Minting guard: owner can pause further minting
(define-data-var minting-paused bool false)

;; ===== DATA MAPS =====

;; Allowances: owner -> spender -> amount
(define-map allowances {owner: principal, spender: principal} uint)

;; ===== HELPER FUNCTIONS =====

(define-private (is-valid-amount (amount uint))
  (> amount u0)
)

(define-private (is-contract-owner (caller principal))
  (is-eq caller CONTRACT_OWNER)
)

;; ===== READ-ONLY FUNCTIONS =====

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance clarity-coin who))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply clarity-coin))
)

(define-read-only (get-name)
  (ok TOKEN_NAME)
)

(define-read-only (get-symbol)
  (ok TOKEN_SYMBOL)
)

(define-read-only (get-decimals)
  (ok TOKEN_DECIMALS)
)

(define-read-only (get-allowance (owner principal) (spender principal))
  (ok (default-to u0 (map-get? allowances {owner: owner, spender: spender})))
)

;; ===== ALLOWANCE FUNCTIONS =====

(define-public (approve (spender principal) (amount uint))
  (begin
    (asserts! (not (is-eq tx-sender spender)) ERR_INVALID_RECIPIENT)
    (asserts! (<= amount MAX_UINT) ERR_ALLOWANCE_OVERFLOW)
    (map-set allowances {owner: tx-sender, spender: spender} amount)
    (ok true)
  )
)

;; ===== MINT FUNCTION =====

(define-public (mint (amount uint) (recipient principal))
  (let ((current-supply (ft-get-supply clarity-coin)))
    (begin
      (asserts! (not (var-get minting-paused)) ERR_MINTING_PAUSED)
      (asserts! (is-contract-owner tx-sender) ERR_OWNER_ONLY)
      (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
      (asserts! (not (is-eq recipient tx-sender)) ERR_INVALID_RECIPIENT)
      (asserts! (<= (+ current-supply amount) MAX_SUPPLY) ERR_MAX_SUPPLY_EXCEEDED)
      (try! (ft-mint? clarity-coin amount recipient))
      (ok true)
    )
  )
)

(define-public (set-minting-paused (value bool))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR_OWNER_ONLY)
    (var-set minting-paused value)
    (ok value)
  )
)

;; ===== TRANSFER FUNCTIONS =====

(define-public (transfer
  (amount uint)
  (sender principal)
  (recipient principal)
  (memo (optional (buff 34)))
)
  (begin
    (asserts! (or (is-eq tx-sender sender) (is-eq contract-caller sender)) ERR_NOT_TOKEN_OWNER)
    (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
    (asserts! (not (is-eq sender recipient)) ERR_SELF_TRANSFER)
    (asserts! (>= (ft-get-balance clarity-coin sender) amount) ERR_INSUFFICIENT_BALANCE)
    (try! (ft-transfer? clarity-coin amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

(define-public (transfer-from 
  (owner principal) 
  (recipient principal) 
  (amount uint) 
  (memo (optional (buff 34)))
)
  (let (
    (current-allowance (default-to u0 (map-get? allowances {owner: owner, spender: tx-sender})))
  )
    (begin
      (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
      (asserts! (not (is-eq owner recipient)) ERR_SELF_TRANSFER)
      (asserts! (>= (ft-get-balance clarity-coin owner) amount) ERR_INSUFFICIENT_BALANCE)
      (asserts! (>= current-allowance amount) ERR_INSUFFICIENT_ALLOWANCE)
      (try! (ft-transfer? clarity-coin amount owner recipient))
      (map-set allowances {owner: owner, spender: tx-sender} (- current-allowance amount))
      (match memo to-print (print to-print) 0x)
      (ok true)
    )
  )
)
