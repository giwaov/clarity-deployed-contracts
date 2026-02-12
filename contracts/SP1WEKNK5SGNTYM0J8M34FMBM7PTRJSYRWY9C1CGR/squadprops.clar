;; squadprops.clar
;;
;; ============================================
;; title: Squad Props
;; version: 1.0
;; summary: A social recognition smart contract for Stacks blockchain.
;; description: Give props to your squad, track contributions, build reputation, and celebrate achievements on-chain.
;; ============================================

;; traits
;;
;; ============================================
;; token definitions
;;
;; ============================================
;; constants
;;
;; Error Codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_SELF_PROPS (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_MESSAGE_TOO_LONG (err u103))
(define-constant ERR_NO_HISTORY (err u104))
(define-constant ERR_INVALID_INDEX (err u105))

;; Maximum message length
(define-constant MAX_MESSAGE_LENGTH u500)

;; Maximum history items to store per user
(define-constant MAX_HISTORY_ITEMS u100)

;; ============================================
;; data vars
;;
;; Counter for total props given across the entire system
(define-data-var total-props-count uint u0)

;; Counter for unique props transactions (used as ID)
(define-data-var props-id-counter uint u0)

;; ============================================
;; data maps
;;
;; Map to track total props received by each user
(define-map props-received principal uint)

;; Map to track total props given by each user
(define-map props-given principal uint)

;; Map to track when user first received props (block height)
(define-map first-props-block principal uint)

;; Map to track individual props transactions
;; Key: props-id, Value: props details
(define-map props-record
  uint
  {
    giver: principal,
    receiver: principal,
    message: (string-utf8 500),
    timestamp: uint,
    amount: uint
  }
)

;; Map to track user's received props history (list of props IDs)
(define-map user-props-history
  principal
  (list 100 uint)
)

;; Map to track if giver has given props to receiver
(define-map has-given-to
  {giver: principal, receiver: principal}
  bool
)

;; ============================================
;; public functions
;;

;; Give a single prop to someone with a message
(define-public (give-props (recipient principal) (message (string-utf8 500)))
  (begin
    ;; Validate inputs
    (asserts! (not (is-eq tx-sender recipient)) ERR_SELF_PROPS)
    (asserts! (<= (len message) MAX_MESSAGE_LENGTH) ERR_MESSAGE_TOO_LONG)
    
    ;; Call internal function to give props and return the props-id
    (give-props-internal recipient u1 message)
  )
)

;; Give multiple props to someone at once
(define-public (give-multiple-props (recipient principal) (amount uint) (message (string-utf8 500)))
  (begin
    ;; Validate inputs
    (asserts! (not (is-eq tx-sender recipient)) ERR_SELF_PROPS)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= (len message) MAX_MESSAGE_LENGTH) ERR_MESSAGE_TOO_LONG)
    
    ;; Call internal function to give props and return the props-id
    (give-props-internal recipient amount message)
  )
)

;; ============================================
;; read only functions
;;

;; Get total props received by a user
(define-read-only (get-props-received (user principal))
  (ok (default-to u0 (map-get? props-received user)))
)

;; Get total props given by a user
(define-read-only (get-props-given (user principal))
  (ok (default-to u0 (map-get? props-given user)))
)

;; Get total props given across entire system
(define-read-only (get-total-props)
  (ok (var-get total-props-count))
)

;; Get user's props history (list of props IDs)
(define-read-only (get-user-history (user principal))
  (ok (default-to (list) (map-get? user-props-history user)))
)

;; Get specific props record by ID
(define-read-only (get-props-by-id (props-id uint))
  (ok (map-get? props-record props-id))
)

;; Check if giver has given props to receiver
(define-read-only (has-given-props-to (giver principal) (receiver principal))
  (ok (default-to false (map-get? has-given-to {giver: giver, receiver: receiver})))
)

;; Get user's rank (simplified - returns props received, actual rank would need sorting)
(define-read-only (get-user-rank (user principal))
  (ok (default-to u0 (map-get? props-received user)))
)

;; Get block height when user first received props
(define-read-only (get-first-props-block (user principal))
  (ok (map-get? first-props-block user))
)

;; Get current props ID counter
(define-read-only (get-current-props-id)
  (ok (var-get props-id-counter))
)

;; Get user stats
(define-read-only (get-user-stats (user principal))
  (ok {
    props-received: (default-to u0 (map-get? props-received user)),
    props-given: (default-to u0 (map-get? props-given user)),
    first-props-block: (map-get? first-props-block user)
  })
)

;; ============================================
;; private functions
;;

;; Internal function to handle props giving logic
(define-private (give-props-internal (recipient principal) (amount uint) (message (string-utf8 500)))
  (let
    (
      (props-id (var-get props-id-counter))
      (giver-current-given (default-to u0 (map-get? props-given tx-sender)))
      (receiver-current-received (default-to u0 (map-get? props-received recipient)))
      (receiver-history (default-to (list) (map-get? user-props-history recipient)))
    )
    (begin
      ;; Update props-id counter
      (var-set props-id-counter (+ props-id u1))
      
      ;; Update total props count
      (var-set total-props-count (+ (var-get total-props-count) amount))
      
      ;; Update giver's props-given count
      (map-set props-given tx-sender (+ giver-current-given amount))
      
      ;; Update receiver's props-received count
      (map-set props-received recipient (+ receiver-current-received amount))
      
      ;; Set first props block if this is receiver's first props
      (if (is-eq receiver-current-received u0)
        (begin
          (map-set first-props-block recipient burn-block-height)
          true
        )
        true
      )
      
      ;; Mark that giver has given props to receiver
      (map-set has-given-to {giver: tx-sender, receiver: recipient} true)
      
      ;; Store props record
      (begin
        (map-set props-record props-id
          {
            giver: tx-sender,
            receiver: recipient,
            message: message,
            timestamp: burn-block-height,
            amount: amount
          }
        )
        
        ;; Update receiver's history (add new props-id to list if not at max)
        (if (< (len receiver-history) MAX_HISTORY_ITEMS)
          (map-set user-props-history recipient (unwrap-panic (as-max-len? (append receiver-history props-id) u100)))
          true
        )
        
        ;; Emit event
        (print {
          event: "props-given",
          props-id: props-id,
          giver: tx-sender,
          receiver: recipient,
          amount: amount,
          message: message,
          block-height: burn-block-height,
          receiver-total: (+ receiver-current-received amount)
        })
        
        (ok props-id)
      )
    )
  )
)
