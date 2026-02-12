;; NFT Marketplace Contract
;; Integrates with non-fungible-token.clar and uses Clarity v4 functions
;; Supports listing, buying, selling, bidding, and auction functionality

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u4001))
(define-constant ERR_NOT_FOUND (err u4002))
(define-constant ERR_ALREADY_EXISTS (err u4003))
(define-constant ERR_INVALID_PRICE (err u4004))
(define-constant ERR_INSUFFICIENT_FUNDS (err u4005))
(define-constant ERR_LISTING_EXPIRED (err u4006))
(define-constant ERR_AUCTION_ACTIVE (err u4007))
(define-constant ERR_AUCTION_ENDED (err u4008))
(define-constant ERR_BID_TOO_LOW (err u4009))
(define-constant ERR_ASSETS_RESTRICTED (err u4010))
(define-constant ERR_INVALID_SIGNATURE (err u4011))
(define-constant ERR_CONTRACT_MISMATCH (err u4012))

;; Data variables
(define-data-var marketplace-fee-rate uint u250) ;; 2.5% fee (250 basis points)
(define-data-var platform-wallet principal tx-sender)
(define-data-var contract-owner principal tx-sender)
(define-data-var marketplace-paused bool false)
(define-data-var listing-nonce uint u0)
(define-data-var auction-nonce uint u0)
(define-data-var bid-nonce uint u0)

;; Data maps
(define-map listings
  { contract: principal, token-id: uint }
  {
    seller: principal,
    price: uint,
    created-at: uint,
    expires-at: uint,
    active: bool,
    listing-id: uint,
    signature-hash: (optional (buff 32)),
    verified: bool
  }
)

(define-map auctions
  { auction-id: uint }
  {
    nft-contract: principal,
    token-id: uint,
    seller: principal,
    starting-price: uint,
    current-bid: uint,
    highest-bidder: (optional principal),
    created-at: uint,
    ends-at: uint,
    active: bool,
    signature-hash: (optional (buff 32)),
    verified: bool
  }
)

(define-map bids
  { auction-id: uint, bidder: principal }
  {
    amount: uint,
    timestamp: uint,
    bid-id: uint,
    signature-hash: (optional (buff 32)),
    verified: bool
  }
)

(define-map sales-history
  { contract: principal, token-id: uint, sale-id: uint }
  {
    seller: principal,
    buyer: principal,
    price: uint,
    timestamp: uint,
    transaction-type: (string-ascii 16), ;; "listing", "auction", "direct"
    signature-verified: bool
  }
)

(define-map purchase-intents
  { nft-contract: principal, token-id: uint }
  {
    buyer: principal,
    price: uint,
    created-at: uint,
    active: bool
  }
)

(define-map user-stats
  { user: principal }
  {
    total-sold: uint,
    total-bought: uint,
    total-volume: uint,
    reputation-score: uint
  }
)

;; Clarity v4 functions integration

;; Get marketplace contract hash using contract-hash?
(define-read-only (get-marketplace-hash)
  (contract-hash? .nft-marketplace)
)

;; Check if marketplace assets are restricted (simplified)
(define-read-only (are-marketplace-assets-restricted)
  (var-get marketplace-paused)
)

;; Get current Stacks block time
(define-read-only (get-current-time)
  stacks-block-time
)

;; Convert string to ASCII using to-ascii?
(define-read-only (convert-to-ascii (input (string-utf8 256)))
  (to-ascii? input)
)

;; Signature verification helper using secp256r1-verify
(define-private (verify-signature 
  (message-hash (buff 32))
  (signature (buff 64))
  (public-key (buff 33))
)
  (secp256r1-verify message-hash signature public-key)
)

;; Read-only functions

(define-read-only (get-marketplace-fee-rate)
  (var-get marketplace-fee-rate)
)

(define-read-only (get-platform-wallet)
  (var-get platform-wallet)
)

(define-read-only (is-marketplace-paused)
  (var-get marketplace-paused)
)

(define-read-only (get-listing (nft-contract principal) (token-id uint))
  (map-get? listings { contract: nft-contract, token-id: token-id })
)

(define-read-only (get-auction (auction-id uint))
  (map-get? auctions { auction-id: auction-id })
)

(define-read-only (get-bid (auction-id uint) (bidder principal))
  (map-get? bids { auction-id: auction-id, bidder: bidder })
)

(define-read-only (get-user-stats (user principal))
  (default-to 
    { total-sold: u0, total-bought: u0, total-volume: u0, reputation-score: u0 }
    (map-get? user-stats { user: user })
  )
)

(define-read-only (get-listing-nonce)
  (var-get listing-nonce)
)

(define-read-only (get-auction-nonce)
  (var-get auction-nonce)
)

(define-read-only (calculate-marketplace-fee (price uint))
  (/ (* price (var-get marketplace-fee-rate)) u10000)
)

;; Admin functions

(define-public (set-marketplace-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (<= new-rate u1000) ERR_INVALID_PRICE) ;; Max 10% fee
    (ok (var-set marketplace-fee-rate new-rate))
  )
)

(define-public (set-platform-wallet (new-wallet principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set platform-wallet new-wallet))
  )
)

(define-public (toggle-marketplace-pause)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set marketplace-paused (not (var-get marketplace-paused))))
  )
)

;; Core marketplace functions

(define-public (list-nft 
  (nft-contract principal)
  (token-id uint)
  (price uint)
  (duration-blocks uint)
  (signature (optional (buff 64)))
  (public-key (optional (buff 33)))
  (message-hash (optional (buff 32)))
)
  (let (
    (current-time stacks-block-time)
    (expires-at (+ current-time duration-blocks))
    (listing-id (+ (var-get listing-nonce) u1))
    (signature-verified 
      (match signature sig
        (match public-key pub-key
          (match message-hash msg-hash
            (verify-signature msg-hash sig pub-key)
            false
          )
          false
        )
        false
      )
    )
  )
    (asserts! (not (var-get marketplace-paused)) ERR_UNAUTHORIZED)
    (asserts! (> price u0) ERR_INVALID_PRICE)
    (asserts! (> duration-blocks u0) ERR_INVALID_PRICE)
    (asserts! (is-none (get-listing nft-contract token-id)) ERR_ALREADY_EXISTS)
    
    ;; Verify NFT ownership through contract call
    (asserts! (is-ok (contract-call? .non-fungible-token owner-of token-id)) ERR_NOT_FOUND)
    
    ;; Store listing
    (map-set listings
      { contract: nft-contract, token-id: token-id }
      {
        seller: tx-sender,
        price: price,
        created-at: current-time,
        expires-at: expires-at,
        active: true,
        listing-id: listing-id,
        signature-hash: message-hash,
        verified: signature-verified
      }
    )
    
    ;; Update listing nonce
    (var-set listing-nonce listing-id)
    
    ;; Log event
    (print {
      event: "nft-listed",
      contract: nft-contract,
      token-id: token-id,
      seller: tx-sender,
      price: price,
      listing-id: listing-id,
      expires-at: expires-at,
      signature-verified: signature-verified,
      stacks-block-time: current-time
    })
    
    (ok listing-id)
  )
)

(define-public (delist-nft (nft-contract principal) (token-id uint))
  (let (
    (listing (unwrap! (get-listing nft-contract token-id) ERR_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get seller listing)) ERR_UNAUTHORIZED)
    (asserts! (get active listing) ERR_NOT_FOUND)
    
    ;; Deactivate listing
    (map-set listings
      { contract: nft-contract, token-id: token-id }
      (merge listing { active: false })
    )
    
    ;; Log event
    (print {
      event: "nft-delisted",
      contract: nft-contract,
      token-id: token-id,
      seller: tx-sender,
      listing-id: (get listing-id listing),
      stacks-block-time: stacks-block-time
    })
    
    (ok true)
  )
)

(define-public (buy-nft 
  (nft-contract principal)
  (token-id uint)
  (max-price uint)
  (signature (optional (buff 64)))
  (public-key (optional (buff 33)))
  (message-hash (optional (buff 32)))
)
  (let (
    (listing (unwrap! (get-listing nft-contract token-id) ERR_NOT_FOUND))
    (seller (get seller listing))
    (price (get price listing))
    (current-time stacks-block-time)
    (marketplace-fee (calculate-marketplace-fee price))
    (seller-amount (- price marketplace-fee))
    (signature-verified 
      (match signature sig
        (match public-key pub-key
          (match message-hash msg-hash
            (verify-signature msg-hash sig pub-key)
            false
          )
          false
        )
        false
      )
    )
  )
    (asserts! (not (var-get marketplace-paused)) ERR_UNAUTHORIZED)
    (asserts! (get active listing) ERR_NOT_FOUND)
    (asserts! (<= current-time (get expires-at listing)) ERR_LISTING_EXPIRED)
    (asserts! (<= price max-price) ERR_INVALID_PRICE)
    (asserts! (not (is-eq tx-sender seller)) ERR_UNAUTHORIZED)
    
    ;; Transfer NFT from seller to buyer 
    (try! (contract-call? .non-fungible-token transfer-from 
      seller tx-sender token-id 
      signature public-key message-hash
    ))
    
    ;; Transfer payment to seller
    (try! (stx-transfer? seller-amount tx-sender seller))
    
    ;; Transfer marketplace fee to platform
    (try! (stx-transfer? marketplace-fee tx-sender (var-get platform-wallet)))
    
    ;; Transfer payment to seller
    (try! (stx-transfer? seller-amount tx-sender seller))
    
    ;; Transfer marketplace fee to platform
    (try! (stx-transfer? marketplace-fee tx-sender (var-get platform-wallet)))
    
    ;; Deactivate listing
    (map-set listings
      { contract: nft-contract, token-id: token-id }
      (merge listing { active: false })
    )
    
    ;; Record sale
    (let ((sale-id (+ current-time token-id))) ;; Simple sale ID generation
      (map-set sales-history
        { contract: nft-contract, token-id: token-id, sale-id: sale-id }
        {
          seller: seller,
          buyer: tx-sender,
          price: price,
          timestamp: current-time,
          transaction-type: "listing",
          signature-verified: signature-verified
        }
      )
    )
    
    ;; Update user stats
    (update-user-stats seller true price)
    (update-user-stats tx-sender false price)
    
    ;; Log event
    (print {
      event: "nft-sold",
      contract: nft-contract,
      token-id: token-id,
      seller: seller,
      buyer: tx-sender,
      price: price,
      marketplace-fee: marketplace-fee,
      signature-verified: signature-verified,
      stacks-block-time: current-time
    })
    
    (ok true)
  )
)

;; Create purchase order - buyer signals intent to purchase
(define-public (create-purchase-order
  (nft-contract principal)
  (token-id uint)
  (max-price uint)
)
  (let (
    (listing (unwrap! (get-listing nft-contract token-id) ERR_NOT_FOUND))
    (price (get price listing))
    (current-time stacks-block-time)
  )
    (asserts! (not (var-get marketplace-paused)) ERR_UNAUTHORIZED)
    (asserts! (get active listing) ERR_NOT_FOUND)
    (asserts! (<= current-time (get expires-at listing)) ERR_LISTING_EXPIRED)
    (asserts! (<= price max-price) ERR_INVALID_PRICE)
    (asserts! (not (is-eq tx-sender (get seller listing))) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? purchase-intents { nft-contract: nft-contract, token-id: token-id })) ERR_ALREADY_EXISTS)
    
    ;; Store purchase intent (no payment yet - will happen during completion)
    (map-set purchase-intents
      { nft-contract: nft-contract, token-id: token-id }
      {
        buyer: tx-sender,
        price: price,
        created-at: current-time,
        active: true
      }
    )
    
    (print {
      event: "purchase-order-created",
      nft-contract: nft-contract,
      token-id: token-id,
      buyer: tx-sender,
      price: price,
      timestamp: current-time
    })
    
    (ok true)
  )
)

;; Auction functions

(define-public (create-auction 
  (nft-contract principal)
  (token-id uint)
  (starting-price uint)
  (duration-blocks uint)
  (signature (optional (buff 64)))
  (public-key (optional (buff 33)))
  (message-hash (optional (buff 32)))
)
  (let (
    (current-time stacks-block-time)
    (ends-at (+ current-time duration-blocks))
    (auction-id (+ (var-get auction-nonce) u1))
    (signature-verified 
      (match signature sig
        (match public-key pub-key
          (match message-hash msg-hash
            (verify-signature msg-hash sig pub-key)
            false
          )
          false
        )
        false
      )
    )
  )
    (asserts! (not (var-get marketplace-paused)) ERR_UNAUTHORIZED)
    (asserts! (> starting-price u0) ERR_INVALID_PRICE)
    (asserts! (> duration-blocks u0) ERR_INVALID_PRICE)
    
    ;; Verify NFT ownership
    (asserts! (is-ok (contract-call? .non-fungible-token owner-of token-id)) ERR_NOT_FOUND)
    
    ;; Store auction
    (map-set auctions
      { auction-id: auction-id }
      {
        nft-contract: nft-contract,
        token-id: token-id,
        seller: tx-sender,
        starting-price: starting-price,
        current-bid: u0,
        highest-bidder: none,
        created-at: current-time,
        ends-at: ends-at,
        active: true,
        signature-hash: message-hash,
        verified: signature-verified
      }
    )
    
    ;; Update auction nonce
    (var-set auction-nonce auction-id)
    
    ;; Log event
    (print {
      event: "auction-created",
      auction-id: auction-id,
      nft-contract: nft-contract,
      token-id: token-id,
      seller: tx-sender,
      starting-price: starting-price,
      ends-at: ends-at,
      signature-verified: signature-verified,
      stacks-block-time: current-time
    })
    
    (ok auction-id)
  )
)

(define-public (place-bid 
  (auction-id uint)
  (bid-amount uint)
  (signature (optional (buff 64)))
  (public-key (optional (buff 33)))
  (message-hash (optional (buff 32)))
)
  (let (
    (auction (unwrap! (get-auction auction-id) ERR_NOT_FOUND))
    (current-time stacks-block-time)
    (current-bid (get current-bid auction))
    (min-bid (if (is-eq current-bid u0) 
               (get starting-price auction)
               (+ current-bid u1))) ;; Minimum increment of 1 STX
    (bid-id (+ (var-get bid-nonce) u1))
    (signature-verified 
      (match signature sig
        (match public-key pub-key
          (match message-hash msg-hash
            (verify-signature msg-hash sig pub-key)
            false
          )
          false
        )
        false
      )
    )
  )
    (asserts! (not (var-get marketplace-paused)) ERR_UNAUTHORIZED)
    (asserts! (get active auction) ERR_NOT_FOUND)
    (asserts! (< current-time (get ends-at auction)) ERR_AUCTION_ENDED)
    (asserts! (>= bid-amount min-bid) ERR_BID_TOO_LOW)
    (asserts! (not (is-eq tx-sender (get seller auction))) ERR_UNAUTHORIZED)
    
    ;; Refund previous highest bidder if exists
    (match (get highest-bidder auction) prev-bidder
      (try! (stx-transfer? current-bid (var-get platform-wallet) prev-bidder))
      true
    )
    
    ;; Transfer bid amount to platform (escrowed)
    (try! (stx-transfer? bid-amount tx-sender (var-get platform-wallet)))
    
    ;; Update auction
    (map-set auctions
      { auction-id: auction-id }
      (merge auction {
        current-bid: bid-amount,
        highest-bidder: (some tx-sender)
      })
    )
    
    ;; Store bid
    (map-set bids
      { auction-id: auction-id, bidder: tx-sender }
      {
        amount: bid-amount,
        timestamp: current-time,
        bid-id: bid-id,
        signature-hash: message-hash,
        verified: signature-verified
      }
    )
    
    ;; Update bid nonce
    (var-set bid-nonce bid-id)
    
    ;; Log event
    (print {
      event: "bid-placed",
      auction-id: auction-id,
      bidder: tx-sender,
      amount: bid-amount,
      bid-id: bid-id,
      signature-verified: signature-verified,
      stacks-block-time: current-time
    })
    
    (ok bid-id)
  )
)

(define-public (finalize-auction (auction-id uint))
  (let (
    (auction (unwrap! (get-auction auction-id) ERR_NOT_FOUND))
    (current-time stacks-block-time)
    (seller (get seller auction))
    (current-bid (get current-bid auction))
    (marketplace-fee (calculate-marketplace-fee current-bid))
    (seller-amount (- current-bid marketplace-fee))
  )
    (asserts! (get active auction) ERR_NOT_FOUND)
    (asserts! (>= current-time (get ends-at auction)) ERR_AUCTION_ACTIVE)
    (asserts! (> current-bid u0) ERR_NOT_FOUND) ;; Must have at least one bid
    
    (match (get highest-bidder auction) winner
      (begin
        ;; Transfer NFT to winner
        (try! (contract-call? .non-fungible-token transfer-from 
          seller winner (get token-id auction)
          none none none ;; No signature required for auction finalization
        ))
        
        ;; Transfer payment to seller (minus fee)
        (try! (stx-transfer? seller-amount (var-get platform-wallet) seller))
        
        ;; Keep marketplace fee in platform wallet (already there from escrow)
        
        ;; Deactivate auction
        (map-set auctions
          { auction-id: auction-id }
          (merge auction { active: false })
        )
        
        ;; Record sale
        (let ((sale-id (+ current-time auction-id)))
          (map-set sales-history
            { contract: (get nft-contract auction), token-id: (get token-id auction), sale-id: sale-id }
            {
              seller: seller,
              buyer: winner,
              price: current-bid,
              timestamp: current-time,
              transaction-type: "auction",
              signature-verified: (get verified auction)
            }
          )
        )
        
        ;; Update user stats
        (update-user-stats seller true current-bid)
        (update-user-stats winner false current-bid)
        
        ;; Log event
        (print {
          event: "auction-finalized",
          auction-id: auction-id,
          winner: winner,
          final-price: current-bid,
          seller: seller,
          marketplace-fee: marketplace-fee,
          stacks-block-time: current-time
        })
        
        (ok true)
      )
      ERR_NOT_FOUND ;; No winner
    )
  )
)

;; Helper functions

(define-private (update-user-stats (user principal) (is-seller bool) (amount uint))
  (let (
    (current-stats (get-user-stats user))
    (new-stats 
      (if is-seller
        (merge current-stats {
          total-sold: (+ (get total-sold current-stats) u1),
          total-volume: (+ (get total-volume current-stats) amount),
          reputation-score: (+ (get reputation-score current-stats) u1)
        })
        (merge current-stats {
          total-bought: (+ (get total-bought current-stats) u1),
          total-volume: (+ (get total-volume current-stats) amount),
          reputation-score: (+ (get reputation-score current-stats) u1)
        })
      )
    )
  )
    (map-set user-stats { user: user } new-stats)
  )
)

;; Emergency functions

(define-public (emergency-cancel-listing (nft-contract principal) (token-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-delete listings { contract: nft-contract, token-id: token-id })
    (ok true)
  )
)

(define-public (emergency-cancel-auction (auction-id uint))
  (let (
    (auction (unwrap! (get-auction auction-id) ERR_NOT_FOUND))
    (current-bid (get current-bid auction))
  )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    
    ;; Refund highest bidder if exists
    (match (get highest-bidder auction) bidder
      (try! (stx-transfer? current-bid (var-get platform-wallet) bidder))
      true
    )
    
    ;; Deactivate auction
    (map-set auctions
      { auction-id: auction-id }
      (merge auction { active: false })
    )
    
    (ok true)
  )
)

;; Contract initialization
(begin
  (print {
    event: "marketplace-deployed",
    contract-hash: (get-marketplace-hash),
    assets-restricted: (are-marketplace-assets-restricted),
    deployed-at: (get-current-time)
  })
)
