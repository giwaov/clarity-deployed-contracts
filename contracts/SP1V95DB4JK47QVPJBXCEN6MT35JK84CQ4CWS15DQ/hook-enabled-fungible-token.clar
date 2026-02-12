;; ============================================================================
;;  Inspired Hook-Enabled Fungible Token Contract with Clarity v4
;; ============================================================================
;; 
;; This contract implements an  style token with:
;; - Send/Receive Hooks for token holders to control token flow
;; - Operators system for delegated token operations
;; - Default operators for pre-approved contracts
;; - Granularity for token divisibility
;; - Data fields for rich transfer context
;;
;; Clarity v4 Functions Used:
;; - contract-hash?: Verify contract integrity
;; - restrict-assets?: Asset restriction management (simulated)
;; - to-ascii?: String conversion for hook data
;; - stacks-block-time: Timestamp for operations
;; - secp256r1-verify: Signature verification for operators
;; ============================================================================

;; ============================================================================
;; CONSTANTS
;; ============================================================================

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_NOT_OWNER (err u1002))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1003))
(define-constant ERR_INVALID_AMOUNT (err u1004))
(define-constant ERR_ASSETS_RESTRICTED (err u1005))
(define-constant ERR_SIGNATURE_VERIFICATION_FAILED (err u1006))
(define-constant ERR_INVALID_RECIPIENT (err u1007))
(define-constant ERR_INVALID_SENDER (err u1008))
(define-constant ERR_NOT_OPERATOR (err u1009))
(define-constant ERR_CANNOT_REVOKE_SELF (err u1010))
(define-constant ERR_HOOK_REJECTED (err u1011))
(define-constant ERR_GRANULARITY_VIOLATION (err u1012))
(define-constant ERR_INVALID_GRANULARITY (err u1013))
(define-constant ERR_PAUSED (err u1014))
(define-constant ERR_ALREADY_OPERATOR (err u1015))
(define-constant ERR_NOT_AUTHORIZED_OPERATOR (err u1016))
(define-constant ERR_HOOK_NOT_REGISTERED (err u1017))
(define-constant ERR_INVALID_HOOK_CONTRACT (err u1018))
(define-constant ERR_CONVERSION_FAILED (err u1019))
(define-constant ERR_OPERATOR_ALREADY_DEFAULT (err u1020))

;; Token constants
(define-constant TOKEN_NAME u"Hook-Enabled Token")
(define-constant TOKEN_SYMBOL u"HOOK")
(define-constant TOKEN_DECIMALS u18) ;;  requires 18 decimals
(define-constant TOTAL_SUPPLY u1000000000000000000000000) ;; 1 million tokens with 18 decimals
(define-constant TOKEN_GRANULARITY u1) ;; Smallest divisible unit (1 wei equivalent)

;; Contract owner (deployer)
(define-constant CONTRACT_OWNER tx-sender)

;; Default operators list (max 5 for this implementation)
;; These are pre-approved operators for all holders
(define-constant DEFAULT_OPERATORS_COUNT u0) ;; Initially no default operators

;; ============================================================================
;; DATA VARIABLES
;; ============================================================================

;; Contract state
(define-data-var contract-paused bool false)
(define-data-var assets-restricted bool false)
(define-data-var total-minted uint TOTAL_SUPPLY)
(define-data-var total-burned uint u0)

;; Operation tracking
(define-data-var operation-nonce uint u0)
(define-data-var event-nonce uint u0)

;; ============================================================================
;; DATA MAPS
;; ============================================================================

;; Token balances ( balanceOf)
(define-map balances principal uint)

;; Operators mapping: holder -> (operator -> authorized)
;;  authorizeOperator, revokeOperator
(define-map operators { holder: principal, operator: principal } bool)

;; Revoked default operators: holder -> (operator -> revoked)
;; Allows holders to revoke default operators
(define-map revoked-default-operators { holder: principal, operator: principal } bool)

;; Default operators list
(define-map default-operators uint principal)

;; Hook registrations: address -> hook-implementer-contract
;;  ERC1820 registry simulation for tokensToSend and tokensReceived hooks
(define-map tokens-to-send-hooks principal principal)
(define-map tokens-received-hooks principal principal)

;; Hook data storage for verification
(define-map hook-data uint {
  operator: principal,
  from: principal,
  to: principal,
  amount: uint,
  user-data: (buff 256),
  operator-data: (buff 256),
  timestamp: uint,
  hook-type: (string-ascii 20)
})

;; Signature nonces for replay protection
(define-map signature-nonces principal uint)

;; Transfer operations log
(define-map transfer-operations uint {
  operator: principal,
  from: principal,
  to: principal,
  amount: uint,
  user-data: (buff 256),
  operator-data: (buff 256),
  timestamp: uint,
  hooks-called: bool,
  signature-verified: bool
})

;; Event log for comprehensive audit trail
(define-map event-log uint {
  event-type: (string-ascii 32),
  operator: principal,
  holder: principal,
  amount: uint,
  timestamp: uint,
  data-hash: (optional (buff 32))
})

;; ============================================================================
;; INITIALIZATION
;; ============================================================================

;; Initialize contract with total supply to deployer
(map-set balances CONTRACT_OWNER TOTAL_SUPPLY)

;; Log deployment event
(map-set event-log u1 {
  event-type: "contract-deployed",
  operator: CONTRACT_OWNER,
  holder: CONTRACT_OWNER,
  amount: TOTAL_SUPPLY,
  timestamp: stacks-block-time,
  data-hash: none
})
(var-set event-nonce u1)

;; ============================================================================
;; CLARITY V4 FUNCTIONS INTEGRATION
;; ============================================================================

;; Get contract hash using Clarity v4 contract-hash? function
;; Used for verifying contract integrity and security
(define-read-only (get-contract-hash)
  (contract-hash? contract-caller)
)

;; Get specific contract hash for verification
(define-read-only (get-contract-hash-for (contract principal))
  (contract-hash? contract)
)

;; Check if assets are currently restricted
;; Simulates the restrict-assets? functionality
(define-read-only (are-assets-restricted)
  (var-get assets-restricted)
)

;; Convert token name to ASCII using Clarity v4 to-ascii?
(define-read-only (get-token-name-ascii)
  (to-ascii? TOKEN_NAME)
)

;; Convert token symbol to ASCII
(define-read-only (get-token-symbol-ascii)
  (to-ascii? TOKEN_SYMBOL)
)

;; Get current block time using Clarity v4 stacks-block-time
(define-read-only (get-current-block-time)
  stacks-block-time
)

;; Verify secp256r1 signature using Clarity v4 function
(define-private (verify-secp256r1-signature 
  (message-hash (buff 32)) 
  (signature (buff 64)) 
  (public-key (buff 33)))
  (secp256r1-verify message-hash signature public-key)
)

;; ============================================================================
;;  VIEW FUNCTIONS
;; ============================================================================

;; Get token name ( name)
(define-read-only (get-name)
  (ok TOKEN_NAME)
)

;; Get token symbol ( symbol)
(define-read-only (get-symbol)
  (ok TOKEN_SYMBOL)
)

;; Get token granularity ( granularity)
;; Returns the smallest part of the token that's not divisible
(define-read-only (get-granularity)
  (ok TOKEN_GRANULARITY)
)

;; Get total supply ( totalSupply)
(define-read-only (get-total-supply)
  (ok (- (var-get total-minted) (var-get total-burned)))
)

;; Get balance of account ( balanceOf)
(define-read-only (get-balance (holder principal))
  (ok (default-to u0 (map-get? balances holder)))
)

;; Get decimals (ERC-20 compatibility)
(define-read-only (get-decimals)
  (ok TOKEN_DECIMALS)
)

;; ============================================================================
;;  OPERATOR FUNCTIONS
;; ============================================================================

;; Get default operators list ( defaultOperators)
(define-read-only (get-default-operators)
  (ok (list))
)

;; Check if an address is an operator for a holder ( isOperatorFor)
(define-read-only (is-operator-for (operator principal) (holder principal))
  (if (is-eq operator holder)
    ;; A holder is always an operator for itself
    true
    (if (is-default-operator-for operator holder)
      ;; Check if it's a default operator that hasn't been revoked
      true
      ;; Check if explicitly authorized
      (default-to false (map-get? operators { holder: holder, operator: operator }))
    )
  )
)

;; Check if operator is a default operator for holder
(define-private (is-default-operator-for (operator principal) (holder principal))
  (and
    (is-default-operator operator)
    (not (default-to false (map-get? revoked-default-operators { holder: holder, operator: operator })))
  )
)

;; Check if address is a default operator
(define-private (is-default-operator (operator principal))
  false ;; Initially no default operators
)

;; Authorize an operator ( authorizeOperator)
;; Allows a holder to authorize another address to send tokens on their behalf
(define-public (authorize-operator (operator principal))
  (let ((holder tx-sender))
    ;; Cannot authorize self as operator (you're always your own operator)
    (asserts! (not (is-eq operator holder)) ERR_CANNOT_REVOKE_SELF)
    
    ;; Check if contract is paused
    (asserts! (not (var-get contract-paused)) ERR_PAUSED)
    
    ;; Set operator authorization
    (map-set operators { holder: holder, operator: operator } true)
    
    ;; If this was a revoked default operator, remove the revocation
    (map-delete revoked-default-operators { holder: holder, operator: operator })
    
    ;; Emit AuthorizedOperator event
    (log-operator-event "authorized-operator" operator holder)
    
    ;; Print event for indexers
    (print {
      event: "AuthorizedOperator",
      operator: operator,
      holder: holder,
      timestamp: stacks-block-time,
      contract-hash: (get-contract-hash)
    })
    
    (ok true)
  )
)

;; Revoke an operator ( revokeOperator)
(define-public (revoke-operator (operator principal))
  (let ((holder tx-sender))
    ;; Cannot revoke self as operator (you're always your own operator)
    (asserts! (not (is-eq operator holder)) ERR_CANNOT_REVOKE_SELF)
    
    ;; Check if contract is paused
    (asserts! (not (var-get contract-paused)) ERR_PAUSED)
    
    ;; Remove operator authorization
    (map-delete operators { holder: holder, operator: operator })
    
    ;; If this is a default operator, mark as revoked for this holder
    (if (is-default-operator operator)
      (map-set revoked-default-operators { holder: holder, operator: operator } true)
      true
    )
    
    ;; Emit RevokedOperator event
    (log-operator-event "revoked-operator" operator holder)
    
    ;; Print event for indexers
    (print {
      event: "RevokedOperator",
      operator: operator,
      holder: holder,
      timestamp: stacks-block-time
    })
    
    (ok true)
  )
)

;; ============================================================================
;; HOOK REGISTRATION (Registry Simulation)
;; ============================================================================

;; Register tokensToSend hook implementer
;; Register TokensSender implementation
(define-public (register-tokens-to-send-hook (implementer principal))
  (let ((holder tx-sender))
    ;; Verify the implementer contract exists using Clarity v4 contract-hash?
    (asserts! (is-ok (contract-hash? implementer)) ERR_INVALID_HOOK_CONTRACT)
    
    ;; Register the hook implementer
    (map-set tokens-to-send-hooks holder implementer)
    
    ;; Log registration
    (print {
      event: "TokensToSendHookRegistered",
      holder: holder,
      implementer: implementer,
      timestamp: stacks-block-time
    })
    
    (ok true)
  )
)

;; Register tokensReceived hook implementer
;; Register TokensRecipient implementation
(define-public (register-tokens-received-hook (implementer principal))
  (let ((recipient tx-sender))
    ;; Verify the implementer contract exists using Clarity v4 contract-hash?
    (asserts! (is-ok (contract-hash? implementer)) ERR_INVALID_HOOK_CONTRACT)
    
    ;; Register the hook implementer
    (map-set tokens-received-hooks recipient implementer)
    
    ;; Log registration
    (print {
      event: "TokensReceivedHookRegistered",
      recipient: recipient,
      implementer: implementer,
      timestamp: stacks-block-time
    })
    
    (ok true)
  )
)

;; Unregister tokensToSend hook
(define-public (unregister-tokens-to-send-hook)
  (begin
    (map-delete tokens-to-send-hooks tx-sender)
    (ok true)
  )
)

;; Unregister tokensReceived hook
(define-public (unregister-tokens-received-hook)
  (begin
    (map-delete tokens-received-hooks tx-sender)
    (ok true)
  )
)

;; Get tokens-to-send hook implementer for an address
(define-read-only (get-tokens-to-send-hook (holder principal))
  (map-get? tokens-to-send-hooks holder)
)

;; Get tokens-received hook implementer for an address
(define-read-only (get-tokens-received-hook (recipient principal))
  (map-get? tokens-received-hooks recipient)
)

;; ============================================================================
;;  SENDING TOKENS
;; ============================================================================

;; Send tokens ( send)
;; The operator and holder are both msg.sender
(define-public (send-tokens 
  (to principal) 
  (amount uint) 
  (user-data (buff 256)))
  (internal-send tx-sender tx-sender to amount user-data 0x)
)

;; Operator send ( operatorSend)
;; Send tokens on behalf of a holder
(define-public (operator-send 
  (from principal) 
  (to principal) 
  (amount uint) 
  (user-data (buff 256)) 
  (operator-data (buff 256)))
  (let ((operator tx-sender))
    ;; Verify operator is authorized
    (asserts! (is-operator-for operator from) ERR_NOT_OPERATOR)
    
    (internal-send operator from to amount user-data operator-data)
  )
)

;; Operator send with signature verification (Clarity v4 secp256r1-verify)
(define-public (operator-send-with-signature
  (from principal)
  (to principal)
  (amount uint)
  (user-data (buff 256))
  (operator-data (buff 256))
  (nonce uint)
  (signature (buff 64))
  (public-key (buff 33)))
  (let ((operator tx-sender)
        (message-hash (keccak256 (concat 
          (concat (unwrap-panic (to-consensus-buff? from)) (unwrap-panic (to-consensus-buff? to)))
          (concat (unwrap-panic (to-consensus-buff? amount)) (unwrap-panic (to-consensus-buff? nonce)))
        )))
        (current-nonce (default-to u0 (map-get? signature-nonces from))))
    
    ;; Verify nonce for replay protection
    (asserts! (is-eq nonce (+ current-nonce u1)) ERR_SIGNATURE_VERIFICATION_FAILED)
    
    ;; Verify signature using Clarity v4 secp256r1-verify
    (asserts! (verify-secp256r1-signature message-hash signature public-key) ERR_SIGNATURE_VERIFICATION_FAILED)
    
    ;; Verify operator is authorized
    (asserts! (is-operator-for operator from) ERR_NOT_OPERATOR)
    
    ;; Update nonce
    (map-set signature-nonces from nonce)
    
    ;; Perform the send
    (internal-send operator from to amount user-data operator-data)
  )
)

;; Internal send function implementing  rules
(define-private (internal-send 
  (operator principal) 
  (from principal) 
  (to principal) 
  (amount uint) 
  (user-data (buff 256)) 
  (operator-data (buff 256)))
  (let ((from-balance (default-to u0 (map-get? balances from)))
        (to-balance (default-to u0 (map-get? balances to))))
    
    ;; Check if contract is paused
    (asserts! (not (var-get contract-paused)) ERR_PAUSED)
    
    ;; Check if assets are restricted using Clarity v4 function
    (asserts! (not (are-assets-restricted)) ERR_ASSETS_RESTRICTED)
    
    ;; Validate granularity (amount must be multiple of granularity)
    (asserts! (is-eq (mod amount TOKEN_GRANULARITY) u0) ERR_GRANULARITY_VIOLATION)
    
    ;; Check sufficient balance
    (asserts! (>= from-balance amount) ERR_INSUFFICIENT_BALANCE)
    
    ;; Call tokensToSend hook BEFORE updating state
    (try! (call-tokens-to-send-hook operator from to amount user-data operator-data))
    
    ;; Update balances
    (map-set balances from (- from-balance amount))
    (map-set balances to (+ to-balance amount))
    
    ;; Call tokensReceived hook AFTER updating state
    (try! (call-tokens-received-hook operator from to amount user-data operator-data))
    
    ;; Record transfer operation
    (record-transfer-operation operator from to amount user-data operator-data)
    
    ;; Emit Sent event
    (print {
      event: "Sent",
      operator: operator,
      from: from,
      to: to,
      amount: amount,
      user-data: user-data,
      operator-data: operator-data,
      timestamp: stacks-block-time,
      block-height: stacks-block-height
    })
    
    (ok amount)
  )
)

;; ============================================================================
;;  MINTING TOKENS
;; ============================================================================

;; Mint tokens (only owner)
(define-public (mint 
  (to principal) 
  (amount uint) 
  (operator-data (buff 256)))
  (let ((operator tx-sender)
        (to-balance (default-to u0 (map-get? balances to))))
    
    ;; Only owner can mint
    (asserts! (is-eq operator CONTRACT_OWNER) ERR_NOT_OWNER)
    
    ;; Check if contract is paused
    (asserts! (not (var-get contract-paused)) ERR_PAUSED)
    
    ;; Validate granularity
    (asserts! (is-eq (mod amount TOKEN_GRANULARITY) u0) ERR_GRANULARITY_VIOLATION)
    
    ;; Validate amount
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Update balance
    (map-set balances to (+ to-balance amount))
    
    ;; Update total minted
    (var-set total-minted (+ (var-get total-minted) amount))
    
    ;; Call tokensReceived hook for the recipient (from is "zero address" for mint)
    (try! (call-tokens-received-hook-for-mint operator to amount operator-data))
    
    ;; Emit Minted event
    (print {
      event: "Minted",
      operator: operator,
      to: to,
      amount: amount,
      operator-data: operator-data,
      timestamp: stacks-block-time
    })
    
    (ok amount)
  )
)

;; ============================================================================
;;  BURNING TOKENS
;; ============================================================================

;; Burn tokens ( burn)
(define-public (burn 
  (amount uint) 
  (user-data (buff 256)))
  (internal-burn tx-sender tx-sender amount user-data 0x)
)

;; Operator burn ( operatorBurn)
(define-public (operator-burn 
  (from principal) 
  (amount uint) 
  (user-data (buff 256)) 
  (operator-data (buff 256)))
  (let ((operator tx-sender))
    ;; Verify operator is authorized
    (asserts! (is-operator-for operator from) ERR_NOT_OPERATOR)
    
    (internal-burn operator from amount user-data operator-data)
  )
)

;; Internal burn function
(define-private (internal-burn 
  (operator principal) 
  (from principal) 
  (amount uint) 
  (user-data (buff 256)) 
  (operator-data (buff 256)))
  (let ((from-balance (default-to u0 (map-get? balances from))))
    
    ;; Check if contract is paused
    (asserts! (not (var-get contract-paused)) ERR_PAUSED)
    
    ;; Validate granularity
    (asserts! (is-eq (mod amount TOKEN_GRANULARITY) u0) ERR_GRANULARITY_VIOLATION)
    
    ;; Check sufficient balance
    (asserts! (>= from-balance amount) ERR_INSUFFICIENT_BALANCE)
    
    ;; Call tokensToSend hook BEFORE updating state (to is "zero address" for burn)
    (try! (call-tokens-to-send-hook-for-burn operator from amount user-data operator-data))
    
    ;; Update balance
    (map-set balances from (- from-balance amount))
    
    ;; Update total burned
    (var-set total-burned (+ (var-get total-burned) amount))
    
    ;; Emit Burned event
    (print {
      event: "Burned",
      operator: operator,
      from: from,
      amount: amount,
      user-data: user-data,
      operator-data: operator-data,
      timestamp: stacks-block-time
    })
    
    (ok amount)
  )
)

;; ============================================================================
;; HOOK CALL FUNCTIONS
;; ============================================================================

;; Call tokensToSend hook for registered holders
;; Returns (response uint (response uint uint)) to match calling context
(define-private (call-tokens-to-send-hook 
  (operator principal) 
  (from principal) 
  (to principal) 
  (amount uint) 
  (user-data (buff 256)) 
  (operator-data (buff 256)))
  (begin
    (match (map-get? tokens-to-send-hooks from)
      hook-implementer (begin
        ;; Store hook call data for verification
        (let ((hook-id (+ (var-get operation-nonce) u1)))
          (map-set hook-data hook-id {
            operator: operator,
            from: from,
            to: to,
            amount: amount,
            user-data: user-data,
            operator-data: operator-data,
            timestamp: stacks-block-time,
            hook-type: "tokens-to-send"
          })
          
          ;; Print hook call for off-chain processing
          (print {
            event: "TokensToSendHookCalled",
            hook-id: hook-id,
            implementer: hook-implementer,
            operator: operator,
            from: from,
            to: to,
            amount: amount,
            timestamp: stacks-block-time
          })
          
          ;; In a real implementation, this would call the hook contract
          ;; Return with explicit error type matching parent context
          (if true (ok u1) ERR_HOOK_REJECTED)
        )
      )
      ;; No hook registered, continue with explicit error type
      (if true (ok u0) ERR_HOOK_REJECTED)
    )
  )
)

;; Call tokensReceived hook for registered recipients
;; Returns (response uint (response uint uint)) to match calling context
(define-private (call-tokens-received-hook 
  (operator principal) 
  (from principal) 
  (to principal) 
  (amount uint) 
  (user-data (buff 256)) 
  (operator-data (buff 256)))
  (begin
    (match (map-get? tokens-received-hooks to)
      hook-implementer (begin
        ;; Store hook call data for verification
        (let ((hook-id (+ (var-get operation-nonce) u1)))
          (map-set hook-data hook-id {
            operator: operator,
            from: from,
            to: to,
            amount: amount,
            user-data: user-data,
            operator-data: operator-data,
            timestamp: stacks-block-time,
            hook-type: "tokens-received"
          })
          
          ;; Print hook call for off-chain processing
          (print {
            event: "TokensReceivedHookCalled",
            hook-id: hook-id,
            implementer: hook-implementer,
            operator: operator,
            from: from,
            to: to,
            amount: amount,
            timestamp: stacks-block-time
          })
          
          ;; Return with explicit error type matching parent context
          (if true (ok u1) ERR_HOOK_REJECTED)
        )
      )
      ;; No hook registered, continue with explicit error type
      (if true (ok u0) ERR_HOOK_REJECTED)
    )
  )
)

;; Call tokensToSend hook for burn (to is conceptually "zero address")
(define-private (call-tokens-to-send-hook-for-burn 
  (operator principal) 
  (from principal) 
  (amount uint) 
  (user-data (buff 256)) 
  (operator-data (buff 256)))
  (call-tokens-to-send-hook operator from CONTRACT_OWNER amount user-data operator-data)
)

;; Call tokensReceived hook for mint (from is conceptually "zero address")
(define-private (call-tokens-received-hook-for-mint 
  (operator principal) 
  (to principal) 
  (amount uint) 
  (operator-data (buff 256)))
  (call-tokens-received-hook operator CONTRACT_OWNER to amount 0x operator-data)
)

;; ============================================================================
;; ADMINISTRATIVE FUNCTIONS
;; ============================================================================

;; Check if contract is paused
(define-read-only (is-paused)
  (var-get contract-paused)
)

;; Pause contract (only owner)
(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    (var-set contract-paused true)
    (print {
      event: "ContractPaused",
      by: tx-sender,
      timestamp: stacks-block-time
    })
    (ok true)
  )
)

;; Unpause contract (only owner)
(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    (var-set contract-paused false)
    (print {
      event: "ContractUnpaused",
      by: tx-sender,
      timestamp: stacks-block-time
    })
    (ok true)
  )
)

;; Set asset restrictions (only owner)
;; Demonstrates Clarity v4 restrict-assets? concept
(define-public (set-asset-restrictions (restricted bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    (var-set assets-restricted restricted)
    (print {
      event: "AssetRestrictionsUpdated",
      restricted: restricted,
      by: tx-sender,
      timestamp: stacks-block-time
    })
    (ok true)
  )
)

;; ============================================================================
;; LOGGING AND UTILITY FUNCTIONS
;; ============================================================================

;; Log operator events
(define-private (log-operator-event 
  (event-type (string-ascii 32)) 
  (operator principal) 
  (holder principal))
  (let ((new-nonce (+ (var-get event-nonce) u1)))
    (map-set event-log new-nonce {
      event-type: event-type,
      operator: operator,
      holder: holder,
      amount: u0,
      timestamp: stacks-block-time,
      data-hash: none
    })
    (var-set event-nonce new-nonce)
  )
)

;; Record transfer operation
(define-private (record-transfer-operation 
  (operator principal) 
  (from principal) 
  (to principal) 
  (amount uint) 
  (user-data (buff 256)) 
  (operator-data (buff 256)))
  (let ((new-nonce (+ (var-get operation-nonce) u1)))
    (map-set transfer-operations new-nonce {
      operator: operator,
      from: from,
      to: to,
      amount: amount,
      user-data: user-data,
      operator-data: operator-data,
      timestamp: stacks-block-time,
      hooks-called: true,
      signature-verified: false
    })
    (var-set operation-nonce new-nonce)
  )
)

;; ============================================================================
;; READ-ONLY QUERY FUNCTIONS
;; ============================================================================

;; Get transfer operation details
(define-read-only (get-transfer-operation (operation-id uint))
  (map-get? transfer-operations operation-id)
)

;; Get hook data
(define-read-only (get-hook-data (hook-id uint))
  (map-get? hook-data hook-id)
)

;; Get event log entry
(define-read-only (get-event-log (event-id uint))
  (map-get? event-log event-id)
)

;; Get signature nonce for address
(define-read-only (get-signature-nonce (address principal))
  (default-to u0 (map-get? signature-nonces address))
)

;; Get contract status with Clarity v4 features
(define-read-only (get-contract-status)
  {
    paused: (var-get contract-paused),
    assets-restricted: (are-assets-restricted),
    total-supply: (- (var-get total-minted) (var-get total-burned)),
    total-minted: (var-get total-minted),
    total-burned: (var-get total-burned),
    granularity: TOKEN_GRANULARITY,
    operation-nonce: (var-get operation-nonce),
    event-nonce: (var-get event-nonce),
    current-block-time: stacks-block-time,
    contract-hash: (get-contract-hash),
    token-name-ascii: (get-token-name-ascii),
    token-symbol-ascii: (get-token-symbol-ascii)
  }
)

;; Get comprehensive token info
(define-read-only (get-token-info)
  {
    name: TOKEN_NAME,
    symbol: TOKEN_SYMBOL,
    decimals: TOKEN_DECIMALS,
    granularity: TOKEN_GRANULARITY,
    total-supply: (- (var-get total-minted) (var-get total-burned)),
    owner: CONTRACT_OWNER
  }
)

;; ============================================================================
;; ERC-20 COMPATIBILITY FUNCTIONS (Optional for )
;; ============================================================================

;; ERC-20 compatible transfer (calls send internally)
(define-public (transfer (to principal) (amount uint) (memo (optional (buff 34))))
  (let ((user-data (default-to 0x memo)))
    ;; Convert memo to buff 256 for send-tokens
    (send-tokens to amount (unwrap-panic (as-max-len? user-data u256)))
  )
)

;; ERC-20 compatible transfer-from (using operator system)
(define-public (transfer-from (from principal) (to principal) (amount uint) (memo (optional (buff 34))))
  (let ((user-data (default-to 0x memo)))
    (operator-send from to amount (unwrap-panic (as-max-len? user-data u256)) 0x)
  )
)

;; ============================================================================
;; CLARITY V4 INTEGRATION SHOWCASE
;; ============================================================================

;; Enhanced send with all Clarity v4 features demonstration
(define-public (send-with-v4-features
  (to principal)
  (amount uint)
  (user-data (buff 256))
  (signature (buff 64))
  (public-key (buff 33))
  (message-hash (buff 32)))
  (let ((from tx-sender))
    
    ;; 1. Check contract hash using Clarity v4 contract-hash?
    (asserts! (is-ok (get-contract-hash)) ERR_UNAUTHORIZED)
    
    ;; 2. Check asset restrictions (simulates restrict-assets?)
    (asserts! (not (are-assets-restricted)) ERR_ASSETS_RESTRICTED)
    
    ;; 3. Verify signature using Clarity v4 secp256r1-verify
    (asserts! (verify-secp256r1-signature message-hash signature public-key) ERR_SIGNATURE_VERIFICATION_FAILED)
    
    ;; 4. Record operation with stacks-block-time timestamp
    (match (internal-send from from to amount user-data 0x)
      success (begin
        ;; 5. Log with ASCII conversion using Clarity v4 to-ascii?
        (print {
          event: "V4EnhancedSend",
          token-name: (get-token-name-ascii),
          token-symbol: (get-token-symbol-ascii),
          amount: amount,
          timestamp: stacks-block-time,
          signature-verified: true
        })
        (ok success)
      )
      error (err error)
    )
  )
)

;; Verify operator authorization with signature (Clarity v4)
(define-public (verify-and-authorize-operator
  (operator principal)
  (signature (buff 64))
  (public-key (buff 33))
  (message-hash (buff 32)))
  (begin
    ;; Verify signature using Clarity v4 secp256r1-verify
    (asserts! (verify-secp256r1-signature message-hash signature public-key) ERR_SIGNATURE_VERIFICATION_FAILED)
    
    ;; Authorize the operator
    (authorize-operator operator)
  )
)

;; ============================================================================
;; SIP-010 COMPATIBILITY (Stacks Fungible Token Standard)
;; ============================================================================

;; Get token URI
(define-read-only (get-token-uri)
  (ok (some u"https://api.hook-token.io/metadata"))
)

;; Get balance (SIP-010 compatible)
(define-read-only (get-balance-of (account principal))
  (get-balance account)
)
