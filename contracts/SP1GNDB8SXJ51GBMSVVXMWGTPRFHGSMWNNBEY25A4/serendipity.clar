;; serendipity.clar
;;
;; ============================================
;; title: serendipity
;; version: 1.0
;; summary: A simple on-chain raffle smart contract for Stacks blockchain.
;; description: Create raffles, buy tickets, draw random winners, and claim prizes - all on-chain.
;; ============================================

;; traits
;;
;; ============================================
;; token definitions
;;
;; ============================================
;; constants
;;

;; Counter Error Codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_UNDERFLOW (err u101))

;; Raffle Error Codes
(define-constant ERR_INVALID_BLOCK (err u102))
(define-constant ERR_RAFFLE_NOT_FOUND (err u103))
(define-constant ERR_RAFFLE_ENDED (err u104))
(define-constant ERR_ALREADY_DRAWN (err u105))
(define-constant ERR_NOT_ENDED (err u106))
(define-constant ERR_NO_TICKETS (err u107))
(define-constant ERR_TRANSFER_FAILED (err u108))
(define-constant ERR_INVALID_AMOUNT (err u109))

;; Status constants
(define-constant STATUS_ACTIVE "active")
(define-constant STATUS_DRAWN "drawn")
(define-constant STATUS_COMPLETED "completed")

;; ============================================
;; data vars
;;

;; Counter for general testing (as requested)
(define-data-var counter uint u0)

;; Counter for raffle IDs
(define-data-var raffle-counter uint u0)

;; ============================================
;; data maps
;;

;; Map to store raffle details: key=raffle-id, value=raffle-data
(define-map raffles
  uint
  {
    title: (string-ascii 100),
    creator: principal,
    ticket-price: uint,
    prize-pool: uint,
    total-tickets: uint,
    end-block: uint,
    winner: (optional principal),
    status: (string-ascii 20),
    created-at: uint
  }
)

;; Map to track user tickets: key={raffle-id, user}, value=ticket-count
(define-map user-tickets
  {raffle-id: uint, user: principal}
  uint
)

;; Map to store list of participants for each raffle
(define-map raffle-participants
  uint
  (list 1000 principal)
)

;; ============================================
;; public functions
;;

;; --- Counter Functions (for initial testing) ---

;; Public function to increment the counter
(define-public (increment)
  (let
    ((new-value (+ (var-get counter) u1)))
    (begin
      (var-set counter new-value)
      (print {
        event: "counter-incremented",
        caller: tx-sender,
        new-value: new-value,
        block-height: block-height
      })
      (ok new-value)
    )
  )
)

;; Public function to decrement the counter
(define-public (decrement)
  (let 
    ((current-value (var-get counter)))
    (begin
      ;; Prevent underflow
      (asserts! (> current-value u0) ERR_UNDERFLOW)
      (let
        ((new-value (- current-value u1)))
        (begin
          (var-set counter new-value)
          (print {
            event: "counter-decremented",
            caller: tx-sender,
            new-value: new-value,
            block-height: block-height
          })
          (ok new-value)
        )
      )
    )
  )
)

;; --- Raffle Core Functions ---

;; Create a new raffle
(define-public (create-raffle (title (string-ascii 100)) (ticket-price uint) (end-block uint))
  (let
    (
      (raffle-id (var-get raffle-counter))
      (current-block block-height)
    )
    (begin
      ;; Validate end block is in the future
      (asserts! (> end-block current-block) ERR_INVALID_BLOCK)
      
      ;; Validate ticket price is greater than 0
      (asserts! (> ticket-price u0) ERR_INVALID_AMOUNT)

      ;; Create the raffle
      (map-set raffles raffle-id
        {
          title: title,
          creator: tx-sender,
          ticket-price: ticket-price,
          prize-pool: u0,
          total-tickets: u0,
          end-block: end-block,
          winner: none,
          status: STATUS_ACTIVE,
          created-at: current-block
        }
      )

      ;; Initialize empty participants list
      (map-set raffle-participants raffle-id (list))

      ;; Increment raffle counter
      (var-set raffle-counter (+ raffle-id u1))

      ;; Emit event
      (print {
        event: "raffle-created",
        raffle-id: raffle-id,
        title: title,
        creator: tx-sender,
        ticket-price: ticket-price,
        end-block: end-block,
        current-block: current-block
      })

      (ok raffle-id)
    )
  )
)

;; Buy a single ticket for a raffle
(define-public (buy-ticket (raffle-id uint))
  (buy-multiple-tickets raffle-id u1)
)

;; Buy multiple tickets for a raffle
(define-public (buy-multiple-tickets (raffle-id uint) (count uint))
  (let
    (
      (raffle-data (unwrap! (map-get? raffles raffle-id) ERR_RAFFLE_NOT_FOUND))
      (current-block block-height)
      (ticket-price (get ticket-price raffle-data))
      (total-cost (* ticket-price count))
      (current-tickets (default-to u0 (map-get? user-tickets {raffle-id: raffle-id, user: tx-sender})))
      (new-ticket-count (+ current-tickets count))
      (new-total-tickets (+ (get total-tickets raffle-data) count))
      (new-prize-pool (+ (get prize-pool raffle-data) total-cost))
      (participants (default-to (list) (map-get? raffle-participants raffle-id)))
    )
    (begin
      ;; Validate raffle is active
      (asserts! (is-eq (get status raffle-data) STATUS_ACTIVE) ERR_ALREADY_DRAWN)
      
      ;; Validate raffle hasn't ended
      (asserts! (< current-block (get end-block raffle-data)) ERR_RAFFLE_ENDED)
      
      ;; Validate count is greater than 0
      (asserts! (> count u0) ERR_INVALID_AMOUNT)

      ;; Transfer STX from user to contract (contract receives the funds)
      (unwrap! (stx-transfer? total-cost tx-sender (as-contract tx-sender)) ERR_TRANSFER_FAILED)

      ;; Update user tickets
      (map-set user-tickets 
        {raffle-id: raffle-id, user: tx-sender}
        new-ticket-count
      )

      ;; Add user to participants if first ticket
      (if (is-eq current-tickets u0)
        (map-set raffle-participants raffle-id 
          (unwrap! (as-max-len? (append participants tx-sender) u1000) ERR_NO_TICKETS)
        )
        true
      )

      ;; Update raffle data
      (map-set raffles raffle-id
        (merge raffle-data {
          prize-pool: new-prize-pool,
          total-tickets: new-total-tickets
        })
      )

      ;; Emit event
      (print {
        event: "tickets-purchased",
        raffle-id: raffle-id,
        user: tx-sender,
        count: count,
        total-cost: total-cost,
        user-total-tickets: new-ticket-count,
        raffle-total-tickets: new-total-tickets,
        prize-pool: new-prize-pool,
        current-block: current-block
      })

      (ok new-ticket-count)
    )
  )
)

;; Draw winner for a raffle
(define-public (draw-winner (raffle-id uint))
  (let
    (
      (raffle-data (unwrap! (map-get? raffles raffle-id) ERR_RAFFLE_NOT_FOUND))
      (current-block block-height)
      (total-tickets (get total-tickets raffle-data))
      (prize-pool (get prize-pool raffle-data))
      (participants (unwrap! (map-get? raffle-participants raffle-id) ERR_NO_TICKETS))
      (participants-count (len participants))
    )
    (begin
      ;; Validate raffle has ended
      (asserts! (>= current-block (get end-block raffle-data)) ERR_NOT_ENDED)
      
      ;; Validate raffle is still active (not already drawn)
      (asserts! (is-eq (get status raffle-data) STATUS_ACTIVE) ERR_ALREADY_DRAWN)
      
      ;; Validate at least one ticket was sold
      (asserts! (> total-tickets u0) ERR_NO_TICKETS)
      (asserts! (> participants-count u0) ERR_NO_TICKETS)

      ;; Generate random winner index using block hash
      (let
        (
          (random-seed-full (unwrap-panic (get-block-info? id-header-hash (- current-block u1))))
          (random-seed (unwrap-panic (as-max-len? (unwrap-panic (slice? random-seed-full u0 u16)) u16)))
          (random-number (mod (hash-to-uint random-seed) participants-count))
          (winner (unwrap! (element-at participants random-number) ERR_NO_TICKETS))
        )
        (begin
          ;; Update raffle with winner
          (map-set raffles raffle-id
            (merge raffle-data {
              winner: (some winner),
              status: STATUS_DRAWN
            })
          )

          ;; Transfer prize pool to winner
          (unwrap! (as-contract (stx-transfer? prize-pool tx-sender winner)) ERR_TRANSFER_FAILED)

          ;; Mark as completed
          (map-set raffles raffle-id
            (merge raffle-data {
              winner: (some winner),
              status: STATUS_COMPLETED
            })
          )

          ;; Emit event
          (print {
            event: "winner-drawn",
            raffle-id: raffle-id,
            winner: winner,
            prize-pool: prize-pool,
            total-tickets: total-tickets,
            participants-count: participants-count,
            winner-index: random-number,
            current-block: current-block
          })

          (ok winner)
        )
      )
    )
  )
)

;; ============================================
;; read only functions
;;

;; Read-only function to get the current counter value (for initial testing)
(define-read-only (get-counter)
  (ok (var-get counter))
)

;; Read-only function to get the current block height
(define-read-only (get-current-block)
  (ok block-height)
)

;; Get complete raffle information
(define-read-only (get-raffle-info (raffle-id uint))
  (match (map-get? raffles raffle-id)
    raffle-data (ok raffle-data)
    ERR_RAFFLE_NOT_FOUND
  )
)

;; Get raffle winner
(define-read-only (get-raffle-winner (raffle-id uint))
  (match (map-get? raffles raffle-id)
    raffle-data (ok (get winner raffle-data))
    ERR_RAFFLE_NOT_FOUND
  )
)

;; Get user's ticket count for a raffle
(define-read-only (get-user-tickets (raffle-id uint) (user principal))
  (ok (default-to u0 (map-get? user-tickets {raffle-id: raffle-id, user: user})))
)

;; Get total number of raffles created
(define-read-only (get-total-raffles)
  (ok (var-get raffle-counter))
)

;; Check if raffle is active (accepting tickets)
(define-read-only (is-raffle-active (raffle-id uint))
  (match (map-get? raffles raffle-id)
    raffle-data 
      (ok (and 
        (is-eq (get status raffle-data) STATUS_ACTIVE)
        (< block-height (get end-block raffle-data))
      ))
    ERR_RAFFLE_NOT_FOUND
  )
)

;; ============================================
;; private functions
;;

;; Helper function to convert block hash to uint (uses first 8 bytes)
(define-private (hash-to-uint (input (buff 16)))
  (let
    (
      ;; Extract first 8 bytes and convert to uint
      (byte0 (byte-to-uint (unwrap-panic (as-max-len? (unwrap-panic (slice? input u0 u1)) u1))))
      (byte1 (byte-to-uint (unwrap-panic (as-max-len? (unwrap-panic (slice? input u1 u2)) u1))))
      (byte2 (byte-to-uint (unwrap-panic (as-max-len? (unwrap-panic (slice? input u2 u3)) u1))))
      (byte3 (byte-to-uint (unwrap-panic (as-max-len? (unwrap-panic (slice? input u3 u4)) u1))))
      (byte4 (byte-to-uint (unwrap-panic (as-max-len? (unwrap-panic (slice? input u4 u5)) u1))))
      (byte5 (byte-to-uint (unwrap-panic (as-max-len? (unwrap-panic (slice? input u5 u6)) u1))))
      (byte6 (byte-to-uint (unwrap-panic (as-max-len? (unwrap-panic (slice? input u6 u7)) u1))))
      (byte7 (byte-to-uint (unwrap-panic (as-max-len? (unwrap-panic (slice? input u7 u8)) u1))))
    )
    (+ 
      (* byte0 u72057594037927936)  ;; 256^7
      (* byte1 u281474976710656)     ;; 256^6
      (* byte2 u1099511627776)       ;; 256^5
      (* byte3 u4294967296)          ;; 256^4
      (* byte4 u16777216)            ;; 256^3
      (* byte5 u65536)               ;; 256^2
      (* byte6 u256)                 ;; 256^1
      byte7                          ;; 256^0
    )
  )
)

;; Helper function to convert single byte buffer to uint
(define-private (byte-to-uint (byte (buff 1)))
  (unwrap-panic (index-of 0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6e7e8e9eaebecedeeeff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff byte))
)
