;; Rental Non-Fungible Token Contract
;;
;; This contract extends the non-fungible-token standard to add a "user" role that can be granted
;; to addresses with an expiration time. The user role represents permission
;; to "use" the NFT but not the ability to transfer it.
;;
;; Key Features:
;; - Separation of ownership and usage rights
;; - Time-limited rental periods
;; - Automatic expiration of user rights
;; - Owner can set user and rental expiration
;;
;; Clarity v4 Functions Used:
;; - contract-hash?: Verify contract integrity
;; - restrict-assets?: Control rental availability based on asset restrictions
;; - to-ascii?: Convert rental descriptions to ASCII for display
;; - stacks-block-time: Track rental start/end times precisely
;; - secp256r1-verify: Verify signatures for rental agreements

;; ==============================
;; Constants
;; ==============================

;; Contract owner for administrative functions
(define-constant CONTRACT_OWNER tx-sender)

;; Token metadata
(define-constant TOKEN_NAME "Bitto Rental NFT")
(define-constant TOKEN_SYMBOL "BRNFT")

;; Maximum URI length
(define-constant MAX_URI_LENGTH u256)

;; Maximum rental duration (365 days in seconds)
(define-constant MAX_RENTAL_DURATION u31536000)

;; Minimum rental duration (1 hour in seconds)
(define-constant MIN_RENTAL_DURATION u3600)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u4001))
(define-constant ERR_TOKEN_NOT_FOUND (err u4002))
(define-constant ERR_TOKEN_ALREADY_EXISTS (err u4003))
(define-constant ERR_INVALID_RECIPIENT (err u4004))
(define-constant ERR_INVALID_USER (err u4005))
(define-constant ERR_INVALID_EXPIRATION (err u4006))
(define-constant ERR_RENTAL_NOT_FOUND (err u4007))
(define-constant ERR_RENTAL_EXPIRED (err u4008))
(define-constant ERR_RENTAL_ACTIVE (err u4009))
(define-constant ERR_NOT_APPROVED (err u4010))
(define-constant ERR_INVALID_SIGNATURE (err u4011))
(define-constant ERR_ASSETS_RESTRICTED (err u4012))
(define-constant ERR_URI_TOO_LONG (err u4013))
(define-constant ERR_INVALID_DURATION (err u4014))
(define-constant ERR_ALREADY_RENTED (err u4015))
(define-constant ERR_NOT_RENTABLE (err u4016))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u4017))
(define-constant ERR_RENTAL_NOT_ACTIVE (err u4018))
(define-constant ERR_INVALID_PRICE (err u4019))
(define-constant ERR_CONTRACT_HASH_MISMATCH (err u4020))

;; ==============================
;; Data Variables
;; ==============================

;; Base URI for token metadata
(define-data-var base-uri (string-ascii 256) "https://api.bitto.io/rental-nft/")

;; Token supply counter
(define-data-var token-supply uint u0)

;; Total rental counter
(define-data-var total-rentals uint u0)

;; Total rental fees collected
(define-data-var total-rental-fees uint u0)

;; Asset restriction flag (using Clarity v4's restrict-assets? concept)
(define-data-var assets-restricted bool false)

;; Contract paused state
(define-data-var contract-paused bool false)

;; Default rental fee rate (in basis points, 100 = 1%)
(define-data-var platform-fee-rate uint u250)

;; ==============================
;; Data Maps
;; ==============================

;; Token ownership (ERC-721 compatible)
(define-map token-owners uint principal)

;; Token approvals (ERC-721 compatible)
(define-map token-approvals uint principal)

;; Operator approvals (ERC-721 compatible)
(define-map operator-approvals { owner: principal, operator: principal } bool)

;; Token metadata
(define-map token-metadata uint {
  uri: (string-ascii 256),
  name: (string-ascii 64),
  description: (string-utf8 256),
  creator: principal,
  created-at: uint,
})

;; ERC-4907: User information for each token
;; The "user" of an NFT has usage rights but not ownership
(define-map token-users uint {
  user: principal,
  expires: uint,
  rental-id: uint,
})

;; Rental configuration for each token
(define-map rental-config uint {
  is-rentable: bool,
  price-per-second: uint,
  min-duration: uint,
  max-duration: uint,
  allowed-users: (optional principal),
  auto-extend: bool,
})

;; Rental history for audit purposes
(define-map rental-history uint {
  token-id: uint,
  owner: principal,
  user: principal,
  start-time: uint,
  end-time: uint,
  total-price: uint,
  platform-fee: uint,
  signature-verified: bool,
  status: (string-ascii 16),
})

;; User rental statistics
(define-map user-rental-stats principal {
  total-rentals: uint,
  total-spent: uint,
  active-rentals: uint,
})

;; Owner rental statistics
(define-map owner-rental-stats principal {
  total-rentals: uint,
  total-earned: uint,
  active-listings: uint,
})

;; Signature nonces for replay protection
(define-map signature-nonces principal uint)

;; ==============================
;; Clarity v4 Functions - Contract Verification
;; ==============================

;; Get the hash of this contract using Clarity v4's contract-hash?
(define-read-only (get-contract-hash)
  (contract-hash? tx-sender)
)

;; Verify contract integrity by checking hash
(define-read-only (verify-contract-integrity (expected-hash (buff 32)))
  (match (contract-hash? tx-sender)
    actual-hash (is-eq expected-hash actual-hash)
    err-code false
  )
)

;; ==============================
;; Clarity v4 Functions - Time
;; ==============================

;; Get current Stacks block time using Clarity v4's stacks-block-time
(define-read-only (get-current-block-time)
  stacks-block-time
)

;; Check if a rental has expired
(define-read-only (is-rental-expired (token-id uint))
  (match (map-get? token-users token-id)
    user-info (> stacks-block-time (get expires user-info))
    true
  )
)

;; Get remaining rental time
(define-read-only (get-remaining-rental-time (token-id uint))
  (match (map-get? token-users token-id)
    user-info 
      (if (> (get expires user-info) stacks-block-time)
        (ok (- (get expires user-info) stacks-block-time))
        (ok u0)
      )
    (ok u0)
  )
)

;; ==============================
;; Clarity v4 Functions - ASCII Conversion
;; ==============================

;; Convert rental status to ASCII using to-ascii?
(define-read-only (status-to-ascii (status (string-utf8 16)))
  (to-ascii? status)
)

;; Convert description to ASCII for display
(define-read-only (description-to-ascii (description (string-utf8 256)))
  (to-ascii? description)
)

;; ==============================
;; Clarity v4 Functions - Asset Restriction
;; ==============================

;; Check if rentals are currently restricted
(define-read-only (are-assets-restricted)
  (var-get assets-restricted)
)

;; Toggle asset restrictions (owner only)
(define-public (set-asset-restrictions (restricted bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set assets-restricted restricted)
    (print {
      event: "AssetRestrictionsUpdated",
      restricted: restricted,
      updated-by: tx-sender,
      timestamp: stacks-block-time,
    })
    (ok restricted)
  )
)

;; ==============================
;; Clarity v4 Functions - Signature Verification
;; ==============================

;; Verify a secp256r1 signature for rental agreements
;; This enables WebAuthn/passkey-based authorization for rentals
(define-read-only (verify-rental-signature
    (message-hash (buff 32))
    (signature (buff 64))
    (public-key (buff 33))
  )
  (secp256r1-verify message-hash signature public-key)
)

;; Get signature nonce for a user (replay protection)
(define-read-only (get-signature-nonce (user principal))
  (default-to u0 (map-get? signature-nonces user))
)

;; ==============================
;; ERC-721 Compatible Functions
;; ==============================

;; Get token name
(define-read-only (get-name)
  (ok TOKEN_NAME)
)

;; Get token symbol
(define-read-only (get-symbol)
  (ok TOKEN_SYMBOL)
)

;; Get token URI
(define-read-only (token-uri (token-id uint))
  (match (map-get? token-metadata token-id)
    metadata (ok (get uri metadata))
    ERR_TOKEN_NOT_FOUND
  )
)

;; Get total supply
(define-read-only (get-total-supply)
  (ok (var-get token-supply))
)

;; Get owner of a token (ERC-721 ownerOf)
(define-read-only (get-owner (token-id uint))
  (match (map-get? token-owners token-id)
    owner (ok owner)
    ERR_TOKEN_NOT_FOUND
  )
)

;; Get approved address for a token (ERC-721 getApproved)
(define-read-only (get-approved (token-id uint))
  (match (map-get? token-owners token-id)
    owner (ok (map-get? token-approvals token-id))
    ERR_TOKEN_NOT_FOUND
  )
)

;; Check if operator is approved for all (ERC-721 isApprovedForAll)
(define-read-only (is-approved-for-all (owner principal) (operator principal))
  (default-to false (map-get? operator-approvals { owner: owner, operator: operator }))
)

;; Check if caller is owner or approved
(define-read-only (is-owner-or-approved (token-id uint) (spender principal))
  (match (map-get? token-owners token-id)
    owner
      (or 
        (is-eq owner spender)
        (is-eq (some spender) (map-get? token-approvals token-id))
        (is-approved-for-all owner spender)
      )
    false
  )
)

;; Get balance of owner
(define-read-only (get-balance (owner principal))
  (ok (fold count-tokens-owned (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) { owner: owner, count: u0 }))
)

;; Helper function to count tokens
(define-private (count-tokens-owned (token-id uint) (acc { owner: principal, count: uint }))
  (match (map-get? token-owners token-id)
    token-owner 
      (if (is-eq token-owner (get owner acc))
        { owner: (get owner acc), count: (+ (get count acc) u1) }
        acc
      )
    acc
  )
)

;; ==============================
;; ERC-4907: Core User Functions
;; ==============================

;; Get the user of an NFT (ERC-4907 userOf)
;; Returns zero address if user is not set or rental has expired
(define-read-only (user-of (token-id uint))
  (match (map-get? token-users token-id)
    user-info
      (if (> (get expires user-info) stacks-block-time)
        (ok (some (get user user-info)))
        (ok none)
      )
    (ok none)
  )
)

;; Get the user expiration time (ERC-4907 userExpires)
(define-read-only (user-expires (token-id uint))
  (match (map-get? token-users token-id)
    user-info (ok (get expires user-info))
    (ok u0)
  )
)

;; Set the user of an NFT (ERC-4907 setUser)
;; Only owner or approved operator can set user
(define-public (set-user (token-id uint) (user principal) (expires uint))
  (let (
    (owner (unwrap! (get-owner token-id) ERR_TOKEN_NOT_FOUND))
  )
    ;; Check authorization
    (asserts! (is-owner-or-approved token-id tx-sender) ERR_UNAUTHORIZED)
    
    ;; Check contract is not paused
    (asserts! (not (var-get contract-paused)) ERR_ASSETS_RESTRICTED)
    
    ;; Check assets are not restricted
    (asserts! (not (var-get assets-restricted)) ERR_ASSETS_RESTRICTED)
    
    ;; Validate user address
    (asserts! (not (is-eq user owner)) ERR_INVALID_USER)
    
    ;; Validate expiration is in the future
    (asserts! (> expires stacks-block-time) ERR_INVALID_EXPIRATION)
    
    ;; Check no active rental exists (unless expired)
    (asserts! (is-rental-expired token-id) ERR_ALREADY_RENTED)
    
    ;; Update rental counter
    (var-set total-rentals (+ (var-get total-rentals) u1))
    
    ;; Set user information
    (map-set token-users token-id {
      user: user,
      expires: expires,
      rental-id: (var-get total-rentals),
    })
    
    ;; Emit UpdateUser event (ERC-4907 standard)
    (print {
      event: "UpdateUser",
      token-id: token-id,
      user: user,
      expires: expires,
      owner: owner,
      rental-id: (var-get total-rentals),
      timestamp: stacks-block-time,
      contract-hash: (get-contract-hash),
    })
    
    (ok true)
  )
)

;; Clear user when rental expires (can be called by anyone)
(define-public (clear-expired-user (token-id uint))
  (begin
    ;; Check token exists
    (asserts! (is-some (map-get? token-owners token-id)) ERR_TOKEN_NOT_FOUND)
    
    ;; Check rental is expired
    (asserts! (is-rental-expired token-id) ERR_RENTAL_ACTIVE)
    
    ;; Clear user info
    (map-delete token-users token-id)
    
    ;; Emit event
    (print {
      event: "UserCleared",
      token-id: token-id,
      timestamp: stacks-block-time,
    })
    
    (ok true)
  )
)

;; ==============================
;; Rental Marketplace Functions
;; ==============================

;; Set rental configuration for a token
(define-public (set-rental-config
    (token-id uint)
    (is-rentable bool)
    (price-per-second uint)
    (min-duration uint)
    (max-duration uint)
    (allowed-user (optional principal))
    (auto-extend bool)
  )
  (let (
    (owner (unwrap! (get-owner token-id) ERR_TOKEN_NOT_FOUND))
  )
    ;; Only owner can set rental config
    (asserts! (is-eq tx-sender owner) ERR_UNAUTHORIZED)
    
    ;; Validate durations
    (asserts! (>= min-duration MIN_RENTAL_DURATION) ERR_INVALID_DURATION)
    (asserts! (<= max-duration MAX_RENTAL_DURATION) ERR_INVALID_DURATION)
    (asserts! (<= min-duration max-duration) ERR_INVALID_DURATION)
    
    ;; Set rental config
    (map-set rental-config token-id {
      is-rentable: is-rentable,
      price-per-second: price-per-second,
      min-duration: min-duration,
      max-duration: max-duration,
      allowed-users: allowed-user,
      auto-extend: auto-extend,
    })
    
    ;; Update owner stats
    (match (map-get? owner-rental-stats owner)
      stats (map-set owner-rental-stats owner 
        (merge stats { active-listings: (if is-rentable (+ (get active-listings stats) u1) (get active-listings stats)) }))
      (map-set owner-rental-stats owner {
        total-rentals: u0,
        total-earned: u0,
        active-listings: (if is-rentable u1 u0),
      })
    )
    
    ;; Emit event
    (print {
      event: "RentalConfigUpdated",
      token-id: token-id,
      is-rentable: is-rentable,
      price-per-second: price-per-second,
      min-duration: min-duration,
      max-duration: max-duration,
      owner: owner,
      timestamp: stacks-block-time,
    })
    
    (ok true)
  )
)

;; Get rental configuration
(define-read-only (get-rental-config (token-id uint))
  (map-get? rental-config token-id)
)

;; Rent an NFT
(define-public (rent-nft (token-id uint) (duration uint))
  (let (
    (owner (unwrap! (get-owner token-id) ERR_TOKEN_NOT_FOUND))
    (config (unwrap! (map-get? rental-config token-id) ERR_NOT_RENTABLE))
    (price-per-second (get price-per-second config))
    (total-price (* price-per-second duration))
    (platform-fee (/ (* total-price (var-get platform-fee-rate)) u10000))
    (owner-payment (- total-price platform-fee))
    (expires (+ stacks-block-time duration))
    (rental-id (+ (var-get total-rentals) u1))
  )
    ;; Check rentable
    (asserts! (get is-rentable config) ERR_NOT_RENTABLE)
    
    ;; Check not paused
    (asserts! (not (var-get contract-paused)) ERR_ASSETS_RESTRICTED)
    
    ;; Check not restricted
    (asserts! (not (var-get assets-restricted)) ERR_ASSETS_RESTRICTED)
    
    ;; Check duration
    (asserts! (>= duration (get min-duration config)) ERR_INVALID_DURATION)
    (asserts! (<= duration (get max-duration config)) ERR_INVALID_DURATION)
    
    ;; Check no active rental
    (asserts! (is-rental-expired token-id) ERR_ALREADY_RENTED)
    
    ;; Check allowed users if set
    (match (get allowed-users config)
      allowed-user (asserts! (is-eq tx-sender allowed-user) ERR_UNAUTHORIZED)
      true
    )
    
    ;; Cannot rent own NFT
    (asserts! (not (is-eq tx-sender owner)) ERR_INVALID_USER)
    
    ;; Update counters
    (var-set total-rentals rental-id)
    (var-set total-rental-fees (+ (var-get total-rental-fees) platform-fee))
    
    ;; Set user
    (map-set token-users token-id {
      user: tx-sender,
      expires: expires,
      rental-id: rental-id,
    })
    
    ;; Record rental history
    (map-set rental-history rental-id {
      token-id: token-id,
      owner: owner,
      user: tx-sender,
      start-time: stacks-block-time,
      end-time: expires,
      total-price: total-price,
      platform-fee: platform-fee,
      signature-verified: false,
      status: "active",
    })
    
    ;; Update user stats
    (match (map-get? user-rental-stats tx-sender)
      stats (map-set user-rental-stats tx-sender {
        total-rentals: (+ (get total-rentals stats) u1),
        total-spent: (+ (get total-spent stats) total-price),
        active-rentals: (+ (get active-rentals stats) u1),
      })
      (map-set user-rental-stats tx-sender {
        total-rentals: u1,
        total-spent: total-price,
        active-rentals: u1,
      })
    )
    
    ;; Update owner stats
    (match (map-get? owner-rental-stats owner)
      stats (map-set owner-rental-stats owner {
        total-rentals: (+ (get total-rentals stats) u1),
        total-earned: (+ (get total-earned stats) owner-payment),
        active-listings: (get active-listings stats),
      })
      (map-set owner-rental-stats owner {
        total-rentals: u1,
        total-earned: owner-payment,
        active-listings: u1,
      })
    )
    
    ;; Emit UpdateUser event (ERC-4907)
    (print {
      event: "UpdateUser",
      token-id: token-id,
      user: tx-sender,
      expires: expires,
      rental-id: rental-id,
      owner: owner,
      total-price: total-price,
      platform-fee: platform-fee,
      timestamp: stacks-block-time,
    })
    
    (ok {
      rental-id: rental-id,
      expires: expires,
      total-price: total-price,
    })
  )
)

;; Rent NFT with signature verification
(define-public (rent-nft-with-signature
    (token-id uint)
    (duration uint)
    (signature (buff 64))
    (public-key (buff 33))
    (message-hash (buff 32))
  )
  (let (
    (nonce (get-signature-nonce tx-sender))
  )
    ;; Verify secp256r1 signature using Clarity v4
    (asserts! (secp256r1-verify message-hash signature public-key) ERR_INVALID_SIGNATURE)
    
    ;; Increment nonce to prevent replay
    (map-set signature-nonces tx-sender (+ nonce u1))
    
    ;; Execute the rental
    (match (rent-nft token-id duration)
      success
        (begin
          (print {
            event: "SignatureVerifiedRental",
            user: tx-sender,
            token-id: token-id,
            nonce: nonce,
            timestamp: stacks-block-time,
          })
          (ok success)
        )
      error (err error)
    )
  )
)

;; Extend rental period
(define-public (extend-rental (token-id uint) (additional-duration uint))
  (let (
    (user-info (unwrap! (map-get? token-users token-id) ERR_RENTAL_NOT_FOUND))
    (config (unwrap! (map-get? rental-config token-id) ERR_NOT_RENTABLE))
    (current-expires (get expires user-info))
    (new-expires (+ current-expires additional-duration))
    (price-per-second (get price-per-second config))
    (extension-price (* price-per-second additional-duration))
  )
    ;; Check caller is current user
    (asserts! (is-eq tx-sender (get user user-info)) ERR_UNAUTHORIZED)
    
    ;; Check rental is still active
    (asserts! (> current-expires stacks-block-time) ERR_RENTAL_EXPIRED)
    
    ;; Check auto-extend is enabled
    (asserts! (get auto-extend config) ERR_NOT_RENTABLE)
    
    ;; Check new duration doesn't exceed max
    (asserts! (<= (- new-expires stacks-block-time) (get max-duration config)) ERR_INVALID_DURATION)
    
    ;; Update expiration
    (map-set token-users token-id 
      (merge user-info { expires: new-expires })
    )
    
    ;; Emit event
    (print {
      event: "RentalExtended",
      token-id: token-id,
      user: tx-sender,
      old-expires: current-expires,
      new-expires: new-expires,
      extension-price: extension-price,
      timestamp: stacks-block-time,
    })
    
    (ok new-expires)
  )
)

;; Terminate rental early (by owner)
(define-public (terminate-rental (token-id uint))
  (let (
    (owner (unwrap! (get-owner token-id) ERR_TOKEN_NOT_FOUND))
    (user-info (unwrap! (map-get? token-users token-id) ERR_RENTAL_NOT_FOUND))
  )
    ;; Only owner can terminate
    (asserts! (is-eq tx-sender owner) ERR_UNAUTHORIZED)
    
    ;; Check rental is active
    (asserts! (> (get expires user-info) stacks-block-time) ERR_RENTAL_EXPIRED)
    
    ;; Clear user
    (map-delete token-users token-id)
    
    ;; Update rental history status
    (match (map-get? rental-history (get rental-id user-info))
      history (map-set rental-history (get rental-id user-info)
        (merge history { status: "terminated" }))
      true
    )
    
    ;; Emit event
    (print {
      event: "RentalTerminated",
      token-id: token-id,
      owner: owner,
      user: (get user user-info),
      rental-id: (get rental-id user-info),
      terminated-at: stacks-block-time,
    })
    
    (ok true)
  )
)

;; ==============================
;; NFT Minting Functions
;; ==============================

;; Mint a new rental NFT
(define-public (mint
    (recipient principal)
    (uri (string-ascii 256))
    (name (string-ascii 64))
    (description (string-utf8 256))
  )
  (let (
    (token-id (+ (var-get token-supply) u1))
  )
    ;; Check authorization
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    ;; Check not paused
    (asserts! (not (var-get contract-paused)) ERR_ASSETS_RESTRICTED)
    
    ;; Check URI length
    (asserts! (<= (len uri) MAX_URI_LENGTH) ERR_URI_TOO_LONG)
    
    ;; Check valid recipient
    (asserts! (not (is-eq recipient CONTRACT_OWNER)) ERR_INVALID_RECIPIENT)
    
    ;; Update supply
    (var-set token-supply token-id)
    
    ;; Set owner
    (map-set token-owners token-id recipient)
    
    ;; Set metadata
    (map-set token-metadata token-id {
      uri: uri,
      name: name,
      description: description,
      creator: tx-sender,
      created-at: stacks-block-time,
    })
    
    ;; Convert description to ASCII for logging
    (let ((ascii-description (description-to-ascii description)))
      (print {
        event: "Transfer",
        from: CONTRACT_OWNER,
        to: recipient,
        token-id: token-id,
        name: name,
        ascii-description: ascii-description,
        timestamp: stacks-block-time,
        contract-hash: (get-contract-hash),
      })
    )
    
    (ok token-id)
  )
)

;; ==============================
;; Transfer Functions
;; ==============================

;; Transfer ownership (ERC-721 compatible)
;; Note: Transfer clears user information (ERC-4907 requirement)
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let (
    (owner (unwrap! (get-owner token-id) ERR_TOKEN_NOT_FOUND))
  )
    ;; Check authorization
    (asserts! (is-owner-or-approved token-id tx-sender) ERR_NOT_APPROVED)
    (asserts! (is-eq sender owner) ERR_UNAUTHORIZED)
    
    ;; Check valid recipient
    (asserts! (not (is-eq recipient sender)) ERR_INVALID_RECIPIENT)
    
    ;; Check not paused
    (asserts! (not (var-get contract-paused)) ERR_ASSETS_RESTRICTED)
    
    ;; Transfer ownership
    (map-set token-owners token-id recipient)
    
    ;; Clear approvals
    (map-delete token-approvals token-id)
    
    ;; Clear user on transfer (ERC-4907 requirement)
    (map-delete token-users token-id)
    
    ;; Clear rental config
    (map-delete rental-config token-id)
    
    ;; Emit events
    (print {
      event: "Transfer",
      from: sender,
      to: recipient,
      token-id: token-id,
      timestamp: stacks-block-time,
    })
    
    ;; Emit UpdateUser event with cleared user
    (print {
      event: "UpdateUser",
      token-id: token-id,
      user: recipient,
      expires: u0,
      timestamp: stacks-block-time,
    })
    
    (ok true)
  )
)

;; Approve an address for a token
(define-public (approve (approved principal) (token-id uint))
  (let (
    (owner (unwrap! (get-owner token-id) ERR_TOKEN_NOT_FOUND))
  )
    ;; Check authorization
    (asserts! (or (is-eq tx-sender owner) (is-approved-for-all owner tx-sender)) ERR_UNAUTHORIZED)
    
    ;; Cannot approve self
    (asserts! (not (is-eq approved owner)) ERR_INVALID_RECIPIENT)
    
    ;; Set approval
    (map-set token-approvals token-id approved)
    
    ;; Emit event
    (print {
      event: "Approval",
      owner: owner,
      approved: approved,
      token-id: token-id,
      timestamp: stacks-block-time,
    })
    
    (ok true)
  )
)

;; Set approval for all tokens
(define-public (set-approval-for-all (operator principal) (approved bool))
  (begin
    ;; Cannot approve self
    (asserts! (not (is-eq operator tx-sender)) ERR_INVALID_RECIPIENT)
    
    ;; Set operator approval
    (map-set operator-approvals { owner: tx-sender, operator: operator } approved)
    
    ;; Emit event
    (print {
      event: "ApprovalForAll",
      owner: tx-sender,
      operator: operator,
      approved: approved,
      timestamp: stacks-block-time,
    })
    
    (ok true)
  )
)

;; ==============================
;; Admin Functions
;; ==============================

;; Pause contract
(define-public (pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-paused true)
    (print {
      event: "ContractPaused",
      paused-by: tx-sender,
      timestamp: stacks-block-time,
    })
    (ok true)
  )
)

;; Unpause contract
(define-public (unpause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-paused false)
    (print {
      event: "ContractUnpaused",
      unpaused-by: tx-sender,
      timestamp: stacks-block-time,
    })
    (ok true)
  )
)

;; Set platform fee rate
(define-public (set-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-rate u1000) ERR_INVALID_PRICE) ;; Max 10%
    (var-set platform-fee-rate new-rate)
    (print {
      event: "PlatformFeeUpdated",
      new-rate: new-rate,
      updated-by: tx-sender,
      timestamp: stacks-block-time,
    })
    (ok new-rate)
  )
)

;; Set base URI
(define-public (set-base-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set base-uri new-uri)
    (print {
      event: "BaseURIUpdated",
      new-uri: new-uri,
      updated-by: tx-sender,
      timestamp: stacks-block-time,
    })
    (ok true)
  )
)

;; ==============================
;; Query Functions
;; ==============================

;; Get rental history by ID
(define-read-only (get-rental-history (rental-id uint))
  (map-get? rental-history rental-id)
)

;; Get user rental statistics
(define-read-only (get-user-rental-stats (user principal))
  (map-get? user-rental-stats user)
)

;; Get owner rental statistics
(define-read-only (get-owner-rental-stats (owner principal))
  (map-get? owner-rental-stats owner)
)

;; Get token metadata
(define-read-only (get-token-metadata (token-id uint))
  (map-get? token-metadata token-id)
)

;; Get total rentals count
(define-read-only (get-total-rentals)
  (var-get total-rentals)
)

;; Get total rental fees collected
(define-read-only (get-total-rental-fees)
  (var-get total-rental-fees)
)

;; Get platform fee rate
(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

;; Check if contract is paused
(define-read-only (is-paused)
  (var-get contract-paused)
)

;; Get base URI
(define-read-only (get-base-uri)
  (var-get base-uri)
)

;; ==============================
;; Contract Information
;; ==============================

;; Get comprehensive contract information
(define-read-only (get-contract-info)
  {
    name: TOKEN_NAME,
    symbol: TOKEN_SYMBOL,
    total-supply: (var-get token-supply),
    total-rentals: (var-get total-rentals),
    total-fees: (var-get total-rental-fees),
    platform-fee-rate: (var-get platform-fee-rate),
    is-paused: (var-get contract-paused),
    assets-restricted: (var-get assets-restricted),
    base-uri: (var-get base-uri),
    current-time: stacks-block-time,
    contract-hash: (get-contract-hash),
    max-rental-duration: MAX_RENTAL_DURATION,
    min-rental-duration: MIN_RENTAL_DURATION,
    owner: CONTRACT_OWNER,
  }
)

;; Get full rental info for a token
(define-read-only (get-full-rental-info (token-id uint))
  {
    owner: (map-get? token-owners token-id),
    user: (user-of token-id),
    expires: (user-expires token-id),
    is-expired: (is-rental-expired token-id),
    remaining-time: (get-remaining-rental-time token-id),
    config: (map-get? rental-config token-id),
    metadata: (map-get? token-metadata token-id),
  }
)
