;; Title: BitFlow - Smart Bitcoin Payment Request Protocol
;;
;; Summary: A revolutionary trustless payment infrastructure that transforms
;; Bitcoin commerce through intelligent payment tags and automated
;; settlement on Stacks Layer 2, enabling seamless peer-to-peer
;; transactions with time-bound smart contracts.
;;
;; Description: BitFlow redefines the future of Bitcoin commerce by creating
;; an advanced decentralized payment request ecosystem. The protocol
;; empowers merchants, freelancers, service providers, and individuals
;; to generate sophisticated time-bound payment tags with customizable
;; parameters including recipient designation, precise amounts, and
;; contextual memos. By harnessing the power of sBTC for instantaneous
;; settlement while preserving Bitcoin's uncompromising security model
;; through Stacks Layer 2 architecture, BitFlow eliminates traditional
;; payment intermediaries and creates a truly sovereign financial
;; experience. The protocol features intelligent expiration management,
;; comprehensive indexing systems, and robust state tracking to ensure
;; reliable and efficient payment processing at scale.

;; ERROR CODES & SYSTEM CONSTANTS

;; Core System Error Definitions
(define-constant ERR-TAG-EXISTS u100)
(define-constant ERR-NOT-PENDING u101)
(define-constant ERR-INSUFFICIENT-FUNDS u102)
(define-constant ERR-NOT-FOUND u103)
(define-constant ERR-UNAUTHORIZED u104)
(define-constant ERR-EXPIRED u105)
(define-constant ERR-INVALID-AMOUNT u106)
(define-constant ERR-EMPTY-MEMO u107)
(define-constant ERR-MAX-EXPIRATION-EXCEEDED u108)
(define-constant ERR-INVALID-RECIPIENT u109)
(define-constant ERR-SELF-PAYMENT u110)

;; Payment Tag Lifecycle State Constants
(define-constant STATE-PENDING "pending")
(define-constant STATE-PAID "paid")
(define-constant STATE-EXPIRED "expired")
(define-constant STATE-CANCELED "canceled")

;; PROTOCOL CONFIGURATION & INTEGRATION

;; sBTC Token Contract Integration
;; Production mainnet address - update during deployment
(define-constant SBTC-CONTRACT 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)

;; Protocol Administrator
(define-constant CONTRACT-DEPLOYER tx-sender)

;; Protocol Operational Limits & Security Constraints
(define-constant MAX-EXPIRATION-BLOCKS u4320) ;; 30 days (~10 min/block)
(define-constant MAX-TAGS-PER-USER u100) ;; Efficient indexing limit
(define-constant MIN-PAYMENT-AMOUNT u1000) ;; 0.00001 sBTC spam prevention

;; DATA STRUCTURES & PERSISTENT STORAGE

;; Core Payment Tag Registry
(define-map payment-tags
  { id: uint }
  {
    creator: principal,
    recipient: principal,
    amount: uint,
    created-at: uint,
    expires-at: uint,
    memo: (optional (string-ascii 256)),
    state: (string-ascii 16),
    payment-tx: (optional (buff 32)),
    payment-block: (optional uint),
  }
)

;; Creator Indexing for Efficient Query Operations
(define-map creator-index
  { creator: principal }
  {
    tag-ids: (list 100 uint),
    count: uint,
  }
)

;; Recipient Indexing for Payment Tracking & Analytics
(define-map recipient-index
  { recipient: principal }
  {
    tag-ids: (list 100 uint),
    count: uint,
  }
)

;; Protocol Analytics & Performance Metrics
(define-map contract-stats
  { key: (string-ascii 32) }
  { value: uint }
)

;; STATE VARIABLES

(define-data-var tag-counter uint u0)
(define-data-var contract-paused bool false)

;; INTERNAL HELPER FUNCTIONS

;; Add Payment Tag to Creator's Index
(define-private (add-to-creator-index
    (creator principal)
    (tag-id uint)
  )
  (let (
      (current-data (default-to {
        tag-ids: (list),
        count: u0,
      }
        (map-get? creator-index { creator: creator })
      ))
      (current-list (get tag-ids current-data))
      (current-count (get count current-data))
    )
    (match (as-max-len? (append current-list tag-id) u100)
      new-list (begin
        (map-set creator-index { creator: creator } {
          tag-ids: new-list,
          count: (+ current-count u1),
        })
        true
      )
      false
    )
  )
)

;; Add Payment Tag to Recipient's Index
(define-private (add-to-recipient-index
    (recipient principal)
    (tag-id uint)
  )
  (let (
      (current-data (default-to {
        tag-ids: (list),
        count: u0,
      }
        (map-get? recipient-index { recipient: recipient })
      ))
      (current-list (get tag-ids current-data))
      (current-count (get count current-data))
    )
    (match (as-max-len? (append current-list tag-id) u100)
      new-list (begin
        (map-set recipient-index { recipient: recipient } {
          tag-ids: new-list,
          count: (+ current-count u1),
        })
        true
      )
      false
    )
  )
)

;; Expiration Validation Logic
(define-private (is-tag-expired (expires-at uint))
  (>= stacks-block-height expires-at)
)

;; Protocol Metrics Tracking
(define-private (increment-stat (stat-key (string-ascii 32)))
  (let ((current-value (default-to u0 (get value (map-get? contract-stats { key: stat-key })))))
    (map-set contract-stats { key: stat-key } { value: (+ current-value u1) })
  )
)

;; READ-ONLY FUNCTIONS - QUERY INTERFACE

;; Get Current Payment Tag Counter
(define-read-only (get-tag-counter)
  (var-get tag-counter)
)

;; Retrieve Specific Payment Tag Details
(define-read-only (get-payment-tag (tag-id uint))
  (match (map-get? payment-tags { id: tag-id })
    tag-data (ok tag-data)
    (err ERR-NOT-FOUND)
  )
)

;; Get All Payment Tags Created by User
(define-read-only (get-creator-tags (creator principal))
  (match (map-get? creator-index { creator: creator })
    index-data (ok (get tag-ids index-data))
    (ok (list))
  )
)

;; Get All Payment Tags Where User is Recipient
(define-read-only (get-recipient-tags (recipient principal))
  (match (map-get? recipient-index { recipient: recipient })
    index-data (ok (get tag-ids index-data))
    (ok (list))
  )
)

;; Check if Payment Tag is Eligible for Expiration
(define-read-only (can-expire-tag (tag-id uint))
  (match (map-get? payment-tags { id: tag-id })
    tag-data (if (and
        (is-eq (get state tag-data) STATE-PENDING)
        (is-tag-expired (get expires-at tag-data))
      )
      (ok true)
      (ok false)
    )
    (err ERR-NOT-FOUND)
  )
)

;; Retrieve Protocol Statistics
(define-read-only (get-contract-stats (stat-key (string-ascii 32)))
  (match (map-get? contract-stats { key: stat-key })
    stat-data (ok (get value stat-data))
    (ok u0)
  )
)

;; Check Protocol Operational Status
(define-read-only (is-contract-paused)
  (var-get contract-paused)
)

;; Batch Retrieve Multiple Payment Tags
(define-read-only (get-multiple-tags (tag-ids (list 20 uint)))
  (ok (map get-tag-safe tag-ids))
)

;; Safe Tag Retrieval Helper
(define-private (get-tag-safe (tag-id uint))
  (map-get? payment-tags { id: tag-id })
)

;; PUBLIC FUNCTIONS - CORE PROTOCOL OPERATIONS

;; Create New Payment Request Tag
(define-public (create-payment-tag
    (recipient principal)
    (amount uint)
    (expires-in-blocks uint)
    (memo (optional (string-ascii 256)))
  )
  (let (
      (new-tag-id (+ (var-get tag-counter) u1))
      (expiration-block (+ stacks-block-height expires-in-blocks))
    )
    (begin
      ;; Protocol Status Validation
      (asserts! (not (var-get contract-paused)) (err ERR-UNAUTHORIZED))
      
      ;; Input Parameter Validation
      (asserts! (>= amount MIN-PAYMENT-AMOUNT) (err ERR-INVALID-AMOUNT))
      (asserts! (<= expires-in-blocks MAX-EXPIRATION-BLOCKS)
        (err ERR-MAX-EXPIRATION-EXCEEDED)
      )
      (asserts! (> expires-in-blocks u0) (err ERR-INVALID-AMOUNT))
      (asserts! (not (is-eq tx-sender recipient)) (err ERR-SELF-PAYMENT))
      
      ;; Optional Memo Validation
      (match memo
        some-memo (asserts! (> (len some-memo) u0) (err ERR-EMPTY-MEMO))
        true
      )
      
      ;; Create Payment Tag Record
      (map-set payment-tags { id: new-tag-id } {
        creator: tx-sender,
        recipient: recipient,
        amount: amount,
        created-at: stacks-block-height,
        expires-at: expiration-block,
        memo: memo,
        state: STATE-PENDING,
        payment-tx: none,
        payment-block: none,
      })
      
      ;; Update Protocol State
      (var-set tag-counter new-tag-id)
      (add-to-creator-index tx-sender new-tag-id)
      (add-to-recipient-index recipient new-tag-id)
      (increment-stat "tags-created")
      
      ;; Emit Creation Event
      (print {
        event: "payment-tag-created",
        tag-id: new-tag-id,
        creator: tx-sender,
        recipient: recipient,
        amount: amount,
        expires-at: expiration-block,
        memo: memo,
      })
      
      (ok new-tag-id)
    )
  )
)

;; Execute Payment Tag Settlement
(define-public (fulfill-payment-tag (tag-id uint))
  (let ((tag-data (unwrap! (map-get? payment-tags { id: tag-id }) (err ERR-NOT-FOUND))))
    (begin
      ;; Protocol Status Validation
      (asserts! (not (var-get contract-paused)) (err ERR-UNAUTHORIZED))
      
      ;; Input Parameter Validation
      (asserts! (> tag-id u0) (err ERR-INVALID-AMOUNT))
      (asserts! (<= tag-id (var-get tag-counter)) (err ERR-NOT-FOUND))
      
      ;; Payment Tag State Validation
      (asserts! (is-eq (get state tag-data) STATE-PENDING) (err ERR-NOT-PENDING))
      (asserts! (< stacks-block-height (get expires-at tag-data))
        (err ERR-EXPIRED)
      )
      
      ;; Execute sBTC Transfer
      (try! (contract-call? SBTC-CONTRACT transfer (get amount tag-data) tx-sender
        (get recipient tag-data) none
      ))
      
      ;; Update Payment Tag State
      (map-set payment-tags { id: tag-id }
        (merge tag-data {
          state: STATE-PAID,
          payment-block: (some stacks-block-height),
        })
      )
      
      ;; Update Protocol Metrics
      (increment-stat "tags-fulfilled")
      
      ;; Emit Fulfillment Event
      (print {
        event: "payment-tag-fulfilled",
        tag-id: tag-id,
        payer: tx-sender,
        recipient: (get recipient tag-data),
        amount: (get amount tag-data),
        payment-block: stacks-block-height,
      })
      
      (ok tag-id)
    )
  )
)

;; Cancel Payment Request (Creator Only)
(define-public (cancel-payment-tag (tag-id uint))
  (let ((tag-data (unwrap! (map-get? payment-tags { id: tag-id }) (err ERR-NOT-FOUND))))
    (begin
      ;; Input Parameter Validation
      (asserts! (> tag-id u0) (err ERR-INVALID-AMOUNT))
      (asserts! (<= tag-id (var-get tag-counter)) (err ERR-NOT-FOUND))
      
      ;; Authorization Validation
      (asserts! (is-eq tx-sender (get creator tag-data)) (err ERR-UNAUTHORIZED))
      
      ;; State Validation
      (asserts! (is-eq (get state tag-data) STATE-PENDING) (err ERR-NOT-PENDING))
      
      ;; Update Payment Tag State
      (map-set payment-tags { id: tag-id }
        (merge tag-data { state: STATE-CANCELED })
      )
      
      ;; Update Protocol Metrics
      (increment-stat "tags-canceled")
      
      ;; Emit Cancellation Event
      (print {
        event: "payment-tag-canceled",
        tag-id: tag-id,
        creator: tx-sender,
      })
      
      (ok tag-id)
    )
  )
)

;; Mark Expired Payment Tag (Public Function)
(define-public (expire-payment-tag (tag-id uint))
  (let ((tag-data (unwrap! (map-get? payment-tags { id: tag-id }) (err ERR-NOT-FOUND))))
    (begin
      ;; Input Parameter Validation
      (asserts! (> tag-id u0) (err ERR-INVALID-AMOUNT))
      (asserts! (<= tag-id (var-get tag-counter)) (err ERR-NOT-FOUND))
      
      ;; Expiration State Validation
      (asserts! (is-eq (get state tag-data) STATE-PENDING) (err ERR-NOT-PENDING))
      (asserts! (is-tag-expired (get expires-at tag-data)) (err ERR-EXPIRED))
      
      ;; Update Payment Tag State
      (map-set payment-tags { id: tag-id }
        (merge tag-data { state: STATE-EXPIRED })
      )
      
      ;; Update Protocol Metrics
      (increment-stat "tags-expired")
      
      ;; Emit Expiration Event
      (print {
        event: "payment-tag-expired",
        tag-id: tag-id,
        expired-by: tx-sender,
      })
      
      (ok tag-id)
    )
  )
)

;; ADMINISTRATIVE FUNCTIONS - PROTOCOL GOVERNANCE

;; Emergency Protocol Pause Toggle (Deployer Only)
(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-DEPLOYER) (err ERR-UNAUTHORIZED))
    (var-set contract-paused (not (var-get contract-paused)))
    
    (print {
      event: "contract-pause-toggled",
      paused: (var-get contract-paused),
    })
    
    (ok (var-get contract-paused))
  )
)

;; Protocol Information & Metadata
(define-read-only (get-contract-info)
  (ok {
    name: "BitFlow - Smart Bitcoin Payment Request Protocol",
    version: "1.0.0",
    deployer: CONTRACT-DEPLOYER,
    total-tags: (var-get tag-counter),
    paused: (var-get contract-paused),
    description: "Revolutionary trustless Bitcoin payment infrastructure on Stacks Layer 2",
  })
)