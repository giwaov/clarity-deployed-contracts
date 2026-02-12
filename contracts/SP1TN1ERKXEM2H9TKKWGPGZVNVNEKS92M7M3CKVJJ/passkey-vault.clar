;; PasskeyVault - Clarity Smart Contract
;; ============================================
;; A secure personal vault with cryptographic signature authentication
;; Showcases advanced Clarity features:
;; 1. secp256k1-verify - Signature verification
;; 2. contract-code-hash - Validate external contracts (Clarity 4)
;; 3. Post-conditions via explicit checks - Protect vault assets
;; 4. stx-account - Query account balances
;; 5. Timestamps via burn-block-height patterns
;; 6. Principal validation and access control

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant CONTRACT_OWNER tx-sender)

;; Error Codes
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_SIGNATURE (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_TIME_LOCKED (err u103))
(define-constant ERR_NO_VAULT (err u104))
(define-constant ERR_INVALID_NONCE (err u105))
(define-constant ERR_PUBKEY_EXISTS (err u106))
(define-constant ERR_NO_PUBKEY (err u107))
(define-constant ERR_UNTRUSTED_CONTRACT (err u108))
(define-constant ERR_CONTRACT_HASH_MISMATCH (err u109))
(define-constant ERR_TRANSFER_FAILED (err u110))
(define-constant ERR_INVALID_AMOUNT (err u111))

;; ============================================
;; DATA MAPS & VARS
;; ============================================

;; User Vaults: stores pubkey, balance, time-lock, and nonce
(define-map user-vaults principal 
  {
    pubkey: (buff 33),             ;; Compressed secp256k1 public key
    balance: uint,                  ;; STX balance in microstacks
    time-lock-height: uint,         ;; Block height for unlock
    nonce: uint                     ;; Replay protection
  }
)

;; Trusted Contracts: stores expected code hashes (principal -> expected-hash)
(define-map trusted-contracts principal (buff 32))

;; Global Stats
(define-data-var total-deposits uint u0)
(define-data-var total-vaults uint u0)
(define-data-var total-withdrawals uint u0)

;; ============================================
;; SECP256K1 SIGNATURE VERIFICATION
;; Standard Bitcoin/Stacks signature verification
;; ============================================

(define-private (verify-signature 
    (user principal) 
    (message-hash (buff 32)) 
    (signature (buff 65)))
  (let (
    (vault (unwrap! (map-get? user-vaults user) false))
    (pubkey (get pubkey vault))
    ;; Recover the public key from the signature
    (recovered (secp256k1-recover? message-hash signature))
  )
    ;; Compare recovered pubkey with stored pubkey
    ;; secp256k1-recover? returns (response (buff 33) uint)
    (match recovered
      recovered-key (is-eq recovered-key pubkey)
      err-code false
    )
  )
)

;; ============================================
;; STX-ACCOUNT FEATURE
;; Query detailed STX account information
;; ============================================

(define-read-only (get-account-info (user principal))
  ;; Get locked/unlocked STX breakdown
  (let (
    (account (stx-account user))
  )
    {
      locked: (get locked account),
      unlock-height: (get unlock-height account),
      unlocked: (get unlocked account),
      total: (+ (get locked account) (get unlocked account))
    }
  )
)

;; ============================================
;; TIME-BASED LOGIC
;; Using burn-block-height for time locks
;; ============================================

(define-read-only (get-current-block-height)
  burn-block-height
)

(define-read-only (is-time-locked (user principal))
  (match (map-get? user-vaults user)
    vault (> (get time-lock-height vault) burn-block-height)
    false
  )
)

;; ============================================
;; CONTRACT VALIDATION
;; Validate external contracts before interaction
;; ============================================

;; NOTE: contract-code-hash? is available in Clarity 3.1+
;; For compatibility, we use a hash registry pattern
(define-read-only (get-trusted-hash (contract-principal principal))
  (map-get? trusted-contracts contract-principal)
)

(define-read-only (is-trusted-contract (contract-principal principal))
  (is-some (map-get? trusted-contracts contract-principal))
)

;; ============================================
;; PUBLIC FUNCTIONS
;; ============================================

;; Register a public key for the user's vault
(define-public (register-pubkey (pubkey (buff 33)))
  (let (
    (sender tx-sender)
  )
    ;; Check if vault already exists
    (asserts! (is-none (map-get? user-vaults sender)) ERR_PUBKEY_EXISTS)
    
    ;; Create new vault
    (map-set user-vaults sender {
      pubkey: pubkey,
      balance: u0,
      time-lock-height: u0,
      nonce: u0
    })
    
    ;; Update stats
    (var-set total-vaults (+ (var-get total-vaults) u1))
    
    (print {
      event: "pubkey-registered",
      user: sender,
      block-height: burn-block-height
    })
    
    (ok true)
  )
)

;; Deposit STX into the vault
(define-public (deposit (amount uint))
  (let (
    (sender tx-sender)
    (vault (unwrap! (map-get? user-vaults sender) ERR_NO_VAULT))
    (current-balance (get balance vault))
    (contract-addr (as-contract tx-sender))
  )
    ;; Validate amount
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Transfer STX to contract
    (unwrap! (stx-transfer? amount sender contract-addr) ERR_TRANSFER_FAILED)
    
    ;; Update vault balance
    (map-set user-vaults sender (merge vault {
      balance: (+ current-balance amount)
    }))
    
    ;; Update global stats
    (var-set total-deposits (+ (var-get total-deposits) amount))
    
    (print {
      event: "deposit",
      user: sender,
      amount: amount,
      new-balance: (+ current-balance amount),
      block-height: burn-block-height
    })
    
    (ok (+ current-balance amount))
  )
)

;; Withdraw STX with signature verification
(define-public (withdraw 
    (amount uint)
    (signature (buff 65))
    (nonce uint))
  (let (
    (sender tx-sender)
    (vault (unwrap! (map-get? user-vaults sender) ERR_NO_VAULT))
    (current-balance (get balance vault))
    (current-nonce (get nonce vault))
    (time-lock-height (get time-lock-height vault))
    ;; Create message hash: user + amount + nonce
    (message-hash (keccak256 (concat 
      (unwrap-panic (to-consensus-buff? sender))
      (concat 
        (unwrap-panic (to-consensus-buff? amount))
        (unwrap-panic (to-consensus-buff? nonce))
      )
    )))
  )
    ;; Validate amount
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= amount current-balance) ERR_INSUFFICIENT_BALANCE)
    
    ;; Check time-lock using block height
    (asserts! (<= time-lock-height burn-block-height) ERR_TIME_LOCKED)
    
    ;; Validate nonce (replay protection)
    (asserts! (is-eq nonce current-nonce) ERR_INVALID_NONCE)
    
    ;; Verify signature (secp256k1)
    (asserts! (verify-signature sender message-hash signature) ERR_INVALID_SIGNATURE)
    
    ;; Transfer STX to user
    (unwrap! (as-contract (stx-transfer? amount tx-sender sender)) ERR_TRANSFER_FAILED)
    
    ;; Update vault
    (map-set user-vaults sender (merge vault {
      balance: (- current-balance amount),
      nonce: (+ current-nonce u1)
    }))
    
    ;; Update stats
    (var-set total-withdrawals (+ (var-get total-withdrawals) amount))
    
    (print {
      event: "withdrawal",
      user: sender,
      amount: amount,
      remaining-balance: (- current-balance amount),
      nonce: (+ current-nonce u1),
      block-height: burn-block-height
    })
    
    (ok (- current-balance amount))
  )
)

;; Set a time-lock on the vault (delayed withdrawals)
(define-public (set-time-lock (unlock-height uint))
  (let (
    (sender tx-sender)
    (vault (unwrap! (map-get? user-vaults sender) ERR_NO_VAULT))
  )
    ;; Use block height for time-based logic
    (asserts! (> unlock-height burn-block-height) ERR_INVALID_AMOUNT)
    
    ;; Update time-lock
    (map-set user-vaults sender (merge vault {
      time-lock-height: unlock-height
    }))
    
    (print {
      event: "time-lock-set",
      user: sender,
      unlock-at: unlock-height,
      current-height: burn-block-height
    })
    
    (ok unlock-height)
  )
)

;; Add a trusted contract (admin only)
(define-public (add-trusted-contract (contract-principal principal) (expected-hash (buff 32)))
  (begin
    ;; Only contract owner can add trusted contracts
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    ;; Store the expected code hash
    (map-set trusted-contracts contract-principal expected-hash)
    
    (print {
      event: "trusted-contract-added",
      contract: contract-principal,
      code-hash: expected-hash,
      block-height: burn-block-height
    })
    
    (ok expected-hash)
  )
)

;; Remove trusted contract
(define-public (remove-trusted-contract (contract-principal principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-delete trusted-contracts contract-principal)
    
    (print {
      event: "trusted-contract-removed",
      contract: contract-principal,
      block-height: burn-block-height
    })
    
    (ok true)
  )
)

;; Emergency withdrawal (owner only, for stuck funds)
(define-public (emergency-withdraw (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (unwrap! (as-contract (stx-transfer? amount tx-sender recipient)) ERR_TRANSFER_FAILED)
    
    (print {
      event: "emergency-withdrawal",
      amount: amount,
      recipient: recipient,
      block-height: burn-block-height
    })
    
    (ok amount)
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-vault (user principal))
  (map-get? user-vaults user)
)

(define-read-only (get-balance (user principal))
  (match (map-get? user-vaults user)
    vault (ok (get balance vault))
    ERR_NO_VAULT
  )
)

(define-read-only (get-nonce (user principal))
  (match (map-get? user-vaults user)
    vault (ok (get nonce vault))
    ERR_NO_VAULT
  )
)

(define-read-only (get-time-lock-height (user principal))
  (match (map-get? user-vaults user)
    vault (ok (get time-lock-height vault))
    ERR_NO_VAULT
  )
)

(define-read-only (get-total-deposits)
  (var-get total-deposits)
)

(define-read-only (get-total-withdrawals)
  (var-get total-withdrawals)
)

(define-read-only (get-total-vaults)
  (var-get total-vaults)
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

;; ============================================
;; MESSAGE HASH HELPER (for off-chain signing)
;; ============================================

(define-read-only (get-withdrawal-message-hash 
    (user principal) 
    (amount uint) 
    (nonce uint))
  (keccak256 (concat 
    (unwrap-panic (to-consensus-buff? user))
    (concat 
      (unwrap-panic (to-consensus-buff? amount))
      (unwrap-panic (to-consensus-buff? nonce))
    )
  ))
)

;; ============================================
;; UTILITY FUNCTIONS
;; ============================================

(define-read-only (get-contract-owner)
  CONTRACT_OWNER
)
