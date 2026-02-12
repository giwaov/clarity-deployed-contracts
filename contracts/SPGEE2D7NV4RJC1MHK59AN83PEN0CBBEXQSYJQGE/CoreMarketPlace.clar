;; CoreMarketPlace Contract
;; This contract manages the creation, updating, and purchasing of listings in the Strade decentralized marketplace.
;; It handles the core logic for marketplace interactions, including listing management and purchase fulfillment.

;; --- Constants ---
;; Defines immutable values used throughout the contract for error handling and configuration.

(define-constant CONTRACT_OWNER tx-sender) ;; Sets the contract deployer as the owner.
(define-constant ERR_NOT_AUTHORIZED (err u100)) ;; Error for unauthorized actions.
(define-constant ERR_LISTING_NOT_FOUND (err u101)) ;; Error when a listing cannot be found.
(define-constant ERR_INVALID_PRICE (err u102)) ;; Error for invalid listing prices (e.g., zero or negative).
(define-constant ERR_INVALID_SELLER (err u103)) ;; Error for invalid seller principals.
(define-constant ERR_INSUFFICIENT_BALANCE (err u104)) ;; Error when a buyer has insufficient funds.
(define-constant ERR_LISTING_EXPIRED (err u105)) ;; Error for expired listings.
(define-constant ERR_INVALID_STATUS (err u106)) ;; Error for invalid listing statuses.
(define-constant ERR_NOT_SELLER (err u107)) ;; Error when a user is not the seller of a listing.
(define-constant ERR_ALREADY_PURCHASED (err u108)) ;; Error for listings that have already been sold.
(define-constant ERR_INVALID_INPUT (err u109)) ;; Error for invalid input parameters.
(define-constant ERR_INVALID_DURATION (err u110)) ;; Error for invalid listing durations.
(define-constant ERR_INVALID_LISTING_ID (err u111)) ;; Error for invalid listing IDs.
(define-constant MAX_LISTING_DURATION u52560) ;; Maximum duration of a listing (approximately 1 year).

;; --- Data Maps ---
;; Defines the data structures used to store marketplace information.

(define-map Listings
  { listing-id: uint }
  {
    seller: principal, ;; The principal of the seller.
    name: (string-utf8 64), ;; The name of the listing.
    description: (string-utf8 256), ;; A description of the item.
    price: uint, ;; The price of the listing in micro-STX.
    status: (string-ascii 20), ;; The current status of the listing (e.g., "active", "sold", "cancelled").
    created-at: uint, ;; The block height at which the listing was created.
    expires-at: uint ;; The block height at which the listing expires.
  }
)

;; --- Variables ---
;; Defines mutable variables for tracking the contract's state.

(define-data-var last-listing-id uint u0) ;; Tracks the ID of the last created listing.

;; --- Private Functions ---
;; Helper functions intended for internal use by the contract.

;; Checks if a given price is valid (greater than zero).
(define-private (is-valid-price (price uint))
  (> price u0)
)

;; Checks if a seller principal is valid (not the sender or the contract itself).
(define-private (is-valid-seller (seller principal))
  (and 
    (not (is-eq seller tx-sender))
    (not (is-eq seller (as-contract tx-sender)))
  )
)

;; Checks if a string is within the specified length constraints.
(define-private (is-valid-string (str (string-utf8 256)) (max-len uint))
  (and (>= (len str) u1) (<= (len str) max-len))
)

;; Checks if a listing duration is valid.
(define-private (is-valid-duration (duration uint))
  (and (> duration u0) (<= duration MAX_LISTING_DURATION))
)

;; Checks if a listing ID is valid.
(define-private (is-valid-listing-id (id uint))
  (<= id (var-get last-listing-id))
)

;; Increments and returns the next listing ID.
(define-private (increment-listing-id)
  (let 
    (
      (current-id (var-get last-listing-id))
    )
    (var-set last-listing-id (+ current-id u1))
    (var-get last-listing-id)
  )
)

;; --- Public Functions ---
;; Functions that can be called by any user.

;; Creates a new listing in the marketplace.
;; @param name: The name of the listing.
;; @param description: A description of the item.
;; @param price: The price of the listing in micro-STX.
;; @param duration: The duration of the listing in blocks.
;; @returns (ok uint): The ID of the newly created listing.
(define-public (create-listing (name (string-utf8 64)) (description (string-utf8 256)) (price uint) (duration uint))
  (let
    (
      (listing-id (increment-listing-id))
      (expires-at (+ stacks-block-height duration))
    )
    (asserts! (is-valid-price price) (err ERR_INVALID_PRICE))
    (asserts! (is-valid-string name u64) (err ERR_INVALID_INPUT))
    (asserts! (is-valid-string description u256) (err ERR_INVALID_INPUT))
    (asserts! (is-valid-duration duration) (err ERR_INVALID_DURATION))
    (map-set Listings
      { listing-id: listing-id }
      {
        seller: tx-sender,
        name: name,
        description: description,
        price: price,
        status: "active",
        created-at: stacks-block-height,
        expires-at: expires-at
      }
    )
    (print { event: "listing_created", listing-id: listing-id, seller: tx-sender })
    (ok listing-id)
  )
)

;; Updates an existing listing.
;; @param listing-id: The ID of the listing to update.
;; @param new-price: The new price for the listing.
;; @param new-description: The new description for the listing.
;; @returns (ok bool): True if the update is successful.
(define-public (update-listing (listing-id uint) (new-price uint) (new-description (string-utf8 256)))
  (begin
    (asserts! (is-valid-listing-id listing-id) (err ERR_INVALID_LISTING_ID))
    (let
      (
        (listing (unwrap! (map-get? Listings { listing-id: listing-id }) (err ERR_LISTING_NOT_FOUND)))
      )
      (asserts! (is-eq (get seller listing) tx-sender) (err ERR_NOT_SELLER))
      (asserts! (is-eq (get status listing) "active") (err ERR_INVALID_STATUS))
      (asserts! (is-valid-price new-price) (err ERR_INVALID_PRICE))
      (asserts! (is-valid-string new-description u256) (err ERR_INVALID_INPUT))
      (map-set Listings
        { listing-id: listing-id }
        (merge listing 
          {
            price: new-price,
            description: new-description
          }
        )
      )
      (print { event: "listing_updated", listing-id: listing-id, seller: tx-sender })
      (ok true)
    )
  )
)

;; Cancels a listing.
;; @param listing-id: The ID of the listing to cancel.
;; @returns (ok bool): True if the cancellation is successful.
(define-public (cancel-listing (listing-id uint))
  (begin
    (asserts! (is-valid-listing-id listing-id) (err ERR_INVALID_LISTING_ID))
    (let
      (
        (listing (unwrap! (map-get? Listings { listing-id: listing-id }) (err ERR_LISTING_NOT_FOUND)))
      )
      (asserts! (is-eq (get seller listing) tx-sender) (err ERR_NOT_SELLER))
      (asserts! (is-eq (get status listing) "active") (err ERR_INVALID_STATUS))
      (map-set Listings
        { listing-id: listing-id }
        (merge listing { status: "cancelled" })
      )
      (print { event: "listing_cancelled", listing-id: listing-id, seller: tx-sender })
      (ok true)
    )
  )
)

;; Purchases a listing.
;; @param listing-id: The ID of the listing to purchase.
;; @returns (ok bool): True if the purchase is successful.
(define-public (purchase-listing (listing-id uint))
  (begin
    (asserts! (is-valid-listing-id listing-id) (err ERR_INVALID_LISTING_ID))
    (let
      (
        (listing (unwrap! (map-get? Listings { listing-id: listing-id }) (err ERR_LISTING_NOT_FOUND)))
        (price (get price listing))
        (seller (get seller listing))
      )
      (asserts! (is-eq (get status listing) "active") (err ERR_INVALID_STATUS))
      (asserts! (<= stacks-block-height (get expires-at listing)) (err ERR_LISTING_EXPIRED))
      (asserts! (is-valid-seller seller) (err ERR_INVALID_SELLER))
      (match (stx-transfer? price tx-sender seller)
        success (begin
          (map-set Listings
            { listing-id: listing-id }
            (merge listing { status: "sold" })
          )
          (print { event: "listing_purchased", listing-id: listing-id, buyer: tx-sender, seller: seller, price: price })
          (ok true))
        error (err ERR_INSUFFICIENT_BALANCE))
    )
  )
)

;; --- Read-Only Functions ---
;; Functions for retrieving data from the contract without making state changes.

;; Retrieves a listing by its ID.
;; @param listing-id: The ID of the listing to retrieve.
;; @returns (optional {<listing-data>}): The listing data or none if not found.
(define-read-only (get-listing (listing-id uint))
  (if (is-valid-listing-id listing-id)
    (map-get? Listings { listing-id: listing-id })
    none
  )
)

;; Retrieves the ID of the last created listing.
;; @returns (ok uint): The last listing ID.
(define-read-only (get-last-listing-id)
  (ok (var-get last-listing-id))
)

;; --- Contract Initialization ---
;; Initializes the contract upon deployment.
(begin
  (print "CoreMarketPlace contract initialized")
  (ok true)
)
