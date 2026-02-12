;; Stacks-to-Megapot Bridge Contract
;; Bridges sBTC from Stacks to Base for Megapot lottery participation
;; Handles ticket purchases and winnings claims without Base wallet requirement

;; Contract owner
(define-constant CONTRACT_OWNER tx-sender)

;; Bridge operator (can be different from owner, handles off-chain operations)
(define-constant BRIDGE_OPERATOR tx-sender)

;; Bridge Address for cross-chain to Base - now configurable
(define-data-var bridge-address principal tx-sender)

;; Error codes
(define-constant ERR_NOT_ENOUGH_SBTC (err u1001))
(define-constant ERR_NOT_AUTHORIZED (err u1002))
(define-constant ERR_INVALID_TICKET_COUNT (err u1003))
(define-constant ERR_INVALID_BASE_ADDRESS (err u1005))
(define-constant ERR_PURCHASE_NOT_FOUND (err u1006))
(define-constant ERR_ALREADY_CLAIMED (err u1007))
(define-constant ERR_INVALID_AMOUNT (err u1008))
(define-constant ERR_PURCHASE_ALREADY_PROCESSED (err u1009))

;; Configuration
(define-data-var ticket-price uint u1000000) ;; 1 sBTC per ticket (in micro-units)
(define-data-var bridge-fee uint u10000) ;; 0.01 sBTC bridge fee
(define-data-var service-enabled bool true)

;; Counter for purchase IDs
(define-data-var next-purchase-id uint u1)

;; Purchase tracking - maps Stacks user to their ticket purchases
(define-map purchases
  { purchase-id: uint }
  {
    stacks-user: principal,
    base-address: (string-ascii 42),
    ticket-count: uint,
    sbtc-amount: uint,
    purchase-block: uint,
    processed: bool,
    base-tx-hash: (optional (string-ascii 66)),
  }
)

;; Winnings tracking - bridge operator updates when user wins
(define-map winnings
  { stacks-user: principal }
  {
    total-winnings: uint,
    claimed: bool,
    megapot-round: uint,
    base-tx-hash: (string-ascii 66),
  }
)

;; Statistics
(define-data-var total-bridged uint u0)
(define-data-var total-tickets-purchased uint u0)
(define-data-var total-winnings-claimed uint u0)

;; ============================================
;; CORE BRIDGE FUNCTIONS
;; ============================================

;; Bridge sBTC to Base and purchase Megapot tickets
;; This is the main entry point for users
(define-public (bridge-and-purchase (ticket-count uint) (base-address (string-ascii 42)))
  (let (
    (ticket-cost (* ticket-count (var-get ticket-price)))
    (fee (var-get bridge-fee))
    (total-cost (+ ticket-cost fee))
    (purchase-id (var-get next-purchase-id))
  )
    ;; Validations
    (asserts! (var-get service-enabled) (err u1010))
    (asserts! (> ticket-count u0) ERR_INVALID_TICKET_COUNT)
    (asserts! (is-eq (len base-address) u42) ERR_INVALID_BASE_ADDRESS)
    
    ;; Transfer sBTC from buyer to bridge address
    (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      transfer total-cost tx-sender (var-get bridge-address) none))
    
    ;; Record the purchase
    (map-set purchases 
      { purchase-id: purchase-id }
      {
        stacks-user: tx-sender,
        base-address: base-address,
        ticket-count: ticket-count,
        sbtc-amount: total-cost,
        purchase-block: stacks-block-height,
        processed: false,
        base-tx-hash: none,
      }
    )
    
    ;; Update statistics
    (var-set total-bridged (+ (var-get total-bridged) total-cost))
    (var-set total-tickets-purchased (+ (var-get total-tickets-purchased) ticket-count))
    (var-set next-purchase-id (+ purchase-id u1))
    
    ;; Emit event for off-chain relayer/bridge operator
    (print {
      event: "bridge-purchase-initiated",
      purchase-id: purchase-id,
      stacks-user: tx-sender,
      base-address: base-address,
      ticket-count: ticket-count,
      sbtc-amount: total-cost,
      ticket-price: (var-get ticket-price),
      bridge-fee: fee,
      block-height: stacks-block-height
    })
    
    (ok purchase-id)
  )
)

;; Bridge operator confirms purchase was processed on Base
(define-public (confirm-purchase-processed (purchase-id uint) (base-tx-hash (string-ascii 66)))
  (let (
    (purchase (unwrap! (map-get? purchases { purchase-id: purchase-id }) ERR_PURCHASE_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender BRIDGE_OPERATOR) ERR_NOT_AUTHORIZED)
    (asserts! (not (get processed purchase)) ERR_PURCHASE_ALREADY_PROCESSED)
    
    ;; Update purchase status
    (map-set purchases 
      { purchase-id: purchase-id }
      (merge purchase {
        processed: true,
        base-tx-hash: (some base-tx-hash)
      })
    )
    
    (print {
      event: "purchase-confirmed",
      purchase-id: purchase-id,
      base-tx-hash: base-tx-hash
    })
    
    (ok true)
  )
)

;; ============================================
;; WINNINGS MANAGEMENT
;; ============================================

;; Bridge operator records winnings for a user
(define-public (record-winnings 
  (winner principal) 
  (amount uint) 
  (round uint)
  (base-tx-hash (string-ascii 66))
)
  (begin
    (asserts! (is-eq tx-sender BRIDGE_OPERATOR) ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Check if winnings already exist, if so add to them
    (match (map-get? winnings { stacks-user: winner })
      existing-winnings
        (map-set winnings 
          { stacks-user: winner }
          {
            total-winnings: (+ (get total-winnings existing-winnings) amount),
            claimed: false,
            megapot-round: round,
            base-tx-hash: base-tx-hash
          }
        )
      ;; Create new winnings record
      (map-set winnings 
        { stacks-user: winner }
        {
          total-winnings: amount,
          claimed: false,
          megapot-round: round,
          base-tx-hash: base-tx-hash
        }
      )
    )
    
    (print {
      event: "winnings-recorded",
      winner: winner,
      amount: amount,
      round: round,
      base-tx-hash: base-tx-hash
    })
    
    (ok true)
  )
)

;; User claims their winnings (bridged back from Base to Stacks)
(define-public (claim-winnings)
  (let (
    (winnings-data (unwrap! (map-get? winnings { stacks-user: tx-sender }) ERR_PURCHASE_NOT_FOUND))
    (amount (get total-winnings winnings-data))
  )
    (asserts! (not (get claimed winnings-data)) ERR_ALREADY_CLAIMED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Transfer winnings from bridge to user
    ;; The user is tx-sender (the key in the map), not in the tuple
    (try! (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      transfer amount (as-contract tx-sender) tx-sender none)))
    
    ;; Mark as claimed
    (map-set winnings 
      { stacks-user: tx-sender }
      (merge winnings-data { claimed: true })
    )
    
    ;; Update statistics
    (var-set total-winnings-claimed (+ (var-get total-winnings-claimed) amount))
    
    (print {
      event: "winnings-claimed",
      user: tx-sender,
      amount: amount
    })
    
    (ok amount)
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-purchase (purchase-id uint))
  (map-get? purchases { purchase-id: purchase-id })
)

(define-read-only (get-winnings (user principal))
  (map-get? winnings { stacks-user: user })
)

(define-read-only (get-bridge-address)
  (var-get bridge-address)
)

(define-read-only (get-service-info)
  {
    ticket-price: (var-get ticket-price),
    bridge-fee: (var-get bridge-fee),
    service-enabled: (var-get service-enabled),
    bridge-address: (var-get bridge-address),
    total-bridged: (var-get total-bridged),
    total-tickets-purchased: (var-get total-tickets-purchased),
    total-winnings-claimed: (var-get total-winnings-claimed),
  }
)

(define-read-only (calculate-total-cost (ticket-count uint))
  (let (
    (ticket-cost (* ticket-count (var-get ticket-price)))
    (fee (var-get bridge-fee))
  )
    {
      ticket-cost: ticket-cost,
      bridge-fee: fee,
      total-cost: (+ ticket-cost fee)
    }
  )
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

;; NEW: Set the bridge address (can only be called by owner)
(define-public (set-bridge-address (new-address principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set bridge-address new-address)
    (print {
      event: "bridge-address-updated",
      old-address: (var-get bridge-address),
      new-address: new-address
    })
    (ok true)
  )
)

(define-public (set-ticket-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set ticket-price new-price)
    (ok true)
  )
)

(define-public (set-bridge-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set bridge-fee new-fee)
    (ok true)
  )
)

(define-public (toggle-service)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set service-enabled (not (var-get service-enabled)))
    (ok (var-get service-enabled))
  )
)

;; Emergency withdrawal (only owner)
(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      transfer amount tx-sender CONTRACT_OWNER none))
  )
)