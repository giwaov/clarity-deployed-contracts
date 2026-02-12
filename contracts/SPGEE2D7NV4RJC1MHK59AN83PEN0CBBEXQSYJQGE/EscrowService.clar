;; EscrowService Contract
;; This contract provides a secure escrow service for transactions between buyers and sellers.
;; It holds funds until the buyer releases them to the seller or a dispute is resolved.

;; --- Constants ---
;; Defines immutable values used throughout the contract for error handling and configuration.

(define-constant CONTRACT_OWNER tx-sender) ;; Sets the contract deployer as the owner.
(define-constant ERR_NOT_AUTHORIZED (err u100)) ;; Error for unauthorized actions.
(define-constant ERR_ESCROW_NOT_FOUND (err u101)) ;; Error when an escrow cannot be found.
(define-constant ERR_ALREADY_RELEASED (err u102)) ;; Error if funds have already been released.
(define-constant ERR_TRANSFER_FAILED (err u103)) ;; Error for failed STX transfers.
(define-constant ERR_INVALID_ESCROW_ID (err u104)) ;; Error for invalid escrow IDs.
(define-constant ERR_INVALID_AMOUNT (err u105)) ;; Error for invalid transaction amounts.
(define-constant ERR_INVALID_SELLER (err u106)) ;; Error for invalid seller principals.
(define-constant ERR_ESCROW_EXPIRED (err u107)) ;; Error for expired escrows.
(define-constant ESCROW_DURATION u1008) ;; The duration of the escrow in blocks (approximately 7 days).

;; --- Data Maps ---
;; Defines the data structures used to store escrow information.

(define-map Escrows
  { escrow-id: uint }
  {
    buyer: principal, ;; The principal of the buyer.
    seller: principal, ;; The principal of the seller.
    amount: uint, ;; The amount of STX held in escrow.
    state: (string-ascii 10), ;; The current state of the escrow (e.g., "locked", "released", "refunded").
    created-at: uint, ;; The block height at which the escrow was created.
    expires-at: uint ;; The block height at which the escrow expires.
  }
)

;; --- Variables ---
;; Defines mutable variables for tracking the contract's state.

(define-data-var last-escrow-id uint u0) ;; Tracks the ID of the last created escrow.

;; --- Helper functions ---

;; Checks if a seller principal is valid.
(define-private (is-valid-seller (seller principal))
  (and 
    (not (is-eq seller tx-sender))
    (not (is-eq seller (as-contract tx-sender)))
  )
)

;; Checks if an escrow ID is valid.
(define-private (is-valid-escrow-id (escrow-id uint))
  (<= escrow-id (var-get last-escrow-id))
)

;; --- Public Functions ---

;; Creates a new escrow.
;; @param seller: The principal of the seller.
;; @param amount: The amount of STX to hold in escrow.
;; @returns (ok uint): The ID of the newly created escrow.
(define-public (create-escrow (seller principal) (amount uint))
  (let
    (
      (escrow-id (+ (var-get last-escrow-id) u1))
      (expires-at (+ stacks-block-height ESCROW_DURATION))
    )
    (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
    (asserts! (is-valid-seller seller) (err ERR_INVALID_SELLER))
    (match (stx-transfer? amount tx-sender (as-contract tx-sender))
      success
        (begin
          (map-set Escrows
            { escrow-id: escrow-id }
            {
              buyer: tx-sender,
              seller: seller,
              amount: amount,
              state: "locked",
              created-at: stacks-block-height,
              expires-at: expires-at
            }
          )
          (var-set last-escrow-id escrow-id)
          (print {event: "escrow_created", escrow-id: escrow-id, buyer: tx-sender, seller: seller, amount: amount})
          (ok escrow-id)
        )
      error (err ERR_TRANSFER_FAILED)
    )
  )
)

;; Releases funds to the seller.
;; @param escrow-id: The ID of the escrow to release.
;; @returns (ok bool): True if the funds are released successfully.
(define-public (release-funds (escrow-id uint))
  (begin
    (asserts! (is-valid-escrow-id escrow-id) (err ERR_INVALID_ESCROW_ID))
    (let
      (
        (escrow (unwrap! (map-get? Escrows { escrow-id: escrow-id }) (err ERR_ESCROW_NOT_FOUND)))
        (seller (get seller escrow))
        (amount (get amount escrow))
      )
      (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-eq tx-sender (get buyer escrow))) (err ERR_NOT_AUTHORIZED))
      (asserts! (is-eq (get state escrow) "locked") (err ERR_ALREADY_RELEASED))
      (asserts! (<= stacks-block-height (get expires-at escrow)) (err ERR_ESCROW_EXPIRED))
      (match (as-contract (stx-transfer? amount tx-sender seller))
        success 
          (begin
            (map-set Escrows
              { escrow-id: escrow-id }
              (merge escrow { state: "released" })
            )
            (print {event: "funds_released", escrow-id: escrow-id, seller: seller, amount: amount})
            (ok true)
          )
        error (err ERR_TRANSFER_FAILED)
      )
    )
  )
)

;; Refunds the buyer.
;; @param escrow-id: The ID of the escrow to refund.
;; @returns (ok bool): True if the refund is successful.
(define-public (refund-buyer (escrow-id uint))
  (begin
    (asserts! (is-valid-escrow-id escrow-id) (err ERR_INVALID_ESCROW_ID))
    (let
      (
        (escrow (unwrap! (map-get? Escrows { escrow-id: escrow-id }) (err ERR_ESCROW_NOT_FOUND)))
        (buyer (get buyer escrow))
        (amount (get amount escrow))
      )
      (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_NOT_AUTHORIZED))
      (asserts! (is-eq (get state escrow) "locked") (err ERR_ALREADY_RELEASED))
      (match (as-contract (stx-transfer? amount tx-sender buyer))
        success 
          (begin
            (map-set Escrows
              { escrow-id: escrow-id }
              (merge escrow { state: "refunded" })
            )
            (print {event: "buyer_refunded", escrow-id: escrow-id, buyer: buyer, amount: amount})
            (ok true)
          )
        error (err ERR_TRANSFER_FAILED)
      )
    )
  )
)

;; --- Read-Only Functions ---

;; Retrieves escrow details by ID.
;; @param escrow-id: The ID of the escrow to retrieve.
;; @returns (ok {<escrow-data>}): The escrow data or an error if not found.
(define-read-only (get-escrow (escrow-id uint))
  (begin
    (asserts! (is-valid-escrow-id escrow-id) (err ERR_INVALID_ESCROW_ID))
    (match (map-get? Escrows { escrow-id: escrow-id })
      escrow (ok escrow)
      (err ERR_ESCROW_NOT_FOUND)
    )
  )
)

;; Retrieves the ID of the last created escrow.
;; @returns (ok uint): The last escrow ID.
(define-read-only (get-last-escrow-id)
  (ok (var-get last-escrow-id))
)
