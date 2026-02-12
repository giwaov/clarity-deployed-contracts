;; UserProfile Contract
;; This contract manages user profiles, including usernames, bios, ratings, and reputation scores.
;; It provides functions for users to register, update their profiles, and rate each other.

;; --- Constants ---
;; Defines immutable values used throughout the contract for error handling and configuration.

(define-constant CONTRACT_OWNER tx-sender) ;; Sets the contract deployer as the owner.
(define-constant ERR_NOT_AUTHORIZED (err u100)) ;; Error for unauthorized actions.
(define-constant ERR_USER_NOT_FOUND (err u101)) ;; Error when a user profile cannot be found.
(define-constant ERR_INVALID_RATING (err u102)) ;; Error for invalid rating values (must be between 1 and 5).
(define-constant ERR_SELF_RATING (err u103)) ;; Error when a user attempts to rate themselves.
(define-constant ERR_ALREADY_REGISTERED (err u104)) ;; Error if a user is already registered.
(define-constant ERR_INVALID_INPUT (err u105)) ;; Error for invalid input parameters.
(define-constant ERR_DATA_STORE_FAILURE (err u106)) ;; Error for data storage failures.
(define-constant ERR_INVALID_PRINCIPAL (err u107)) ;; Error for invalid principal addresses.
(define-constant ERR_INVALID_USERNAME (err u108)) ;; Error for invalid usernames.
(define-constant ERR_INVALID_BIO (err u109)) ;; Error for invalid bio lengths.
(define-constant ERR_INVALID_EMAIL (err u110)) ;; Error for invalid email formats or lengths.

;; --- Data Maps ---
;; Defines the data structures used to store user profile information.

(define-map Users principal
  {
    username: (string-utf8 64), ;; The user's chosen username.
    bio: (string-utf8 256), ;; A short biography or description.
    email: (string-utf8 64), ;; The user's email address.
    registration-date: uint, ;; The block height of the user's registration.
    total-ratings: uint, ;; The total number of ratings the user has received.
    rating-sum: uint, ;; The sum of all ratings received.
    reputation-score: uint ;; A calculated score based on ratings and other factors.
  }
)

(define-map UserAuthorization principal bool) ;; Stores authorization status for specific users.

;; --- Private Functions ---
;; Helper functions for internal contract use.

;; Checks if a string is within the specified length constraints.
(define-private (is-valid-string (str (string-utf8 256)) (max-len uint))
  (and (>= (len str) u1) (<= (len str) max-len))
)

;; Checks if a principal is a valid user address.
(define-private (is-valid-principal (user principal))
  (not (is-eq user (as-contract tx-sender)))
)

;; Validates the format and length of a username.
(define-private (validate-username (username (string-utf8 64)))
  (if (is-valid-string username u64)
    (ok username)
    (err ERR_INVALID_USERNAME))
)

;; Validates the length of a user's bio.
(define-private (validate-bio (bio (string-utf8 256)))
  (if (is-valid-string bio u256)
    (ok bio)
    (err ERR_INVALID_BIO))
)

;; Validates the format and length of an email address.
(define-private (validate-email (email (string-utf8 64)))
  (if (is-valid-string email u64)
    (ok email)
    (err ERR_INVALID_EMAIL))
)

;; Sets the user data in the Users map.
(define-private (set-user-data (user principal) (data {
    username: (string-utf8 64),
    bio: (string-utf8 256),
    email: (string-utf8 64),
    registration-date: uint,
    total-ratings: uint,
    rating-sum: uint,
    reputation-score: uint
  }))
  (if (map-set Users user data)
    (ok true)
    (err ERR_DATA_STORE_FAILURE))
)

;; --- Read-Only Functions ---
;; Functions for retrieving data from the contract without making state changes.

;; Retrieves a user's profile.
;; @param user: The principal of the user to retrieve.
;; @returns (ok {<user-data>}): The user's profile data or an error if not found.
(define-read-only (get-user-profile (user principal))
  (match (map-get? Users user)
    user-data (ok user-data)
    (err ERR_USER_NOT_FOUND)))

;; Retrieves a user's average rating.
;; @param user: The principal of the user.
;; @returns (ok uint): The user's average rating or 0 if no ratings.
(define-read-only (get-user-rating (user principal))
  (match (map-get? Users user)
    user-data (let (
      (total-ratings (get total-ratings user-data))
      (rating-sum (get rating-sum user-data))
    )
    (if (> total-ratings u0)
      (ok (/ rating-sum total-ratings))
      (ok u0)))
    (err ERR_USER_NOT_FOUND)
  )
)

;; Checks if a user is authorized.
;; @param user: The principal to check.
;; @returns (ok bool): True if the user is authorized.
(define-read-only (is-user-authorized (user principal))
  (ok (default-to false (map-get? UserAuthorization user))))


;; --- Public Functions ---
;; Functions that can be called by any user.

;; Registers a new user.
;; @param username: The desired username.
;; @param bio: A short bio.
;; @param email: The user's email address.
;; @returns (ok bool): True if registration is successful.
(define-public (register-user (username (string-utf8 64)) (bio (string-utf8 256)) (email (string-utf8 64)))
  (let (
    (existing-user (map-get? Users tx-sender))
  )
  (asserts! (is-none existing-user) (err ERR_ALREADY_REGISTERED))
  (asserts! (and 
              (> (len username) u0)
              (>= (len username) u1)
              (<= (len username) u64)
              (> (len bio) u0)
              (>= (len bio) u1)
              (<= (len bio) u256)
              (> (len email) u0)
              (>= (len email) u1)
              (<= (len email) u64))
            (err ERR_INVALID_INPUT))
  (let (
    (validated-username (try! (validate-username username)))
    (validated-bio (try! (validate-bio bio)))
    (validated-email (try! (validate-email email)))
  )
    (match (set-user-data tx-sender
      {
        username: validated-username,
        bio: validated-bio,
        email: validated-email,
        registration-date: stacks-block-height,
        total-ratings: u0,
        rating-sum: u0,
        reputation-score: u0
      })
      success (ok true)
      error (err ERR_DATA_STORE_FAILURE))
  ))
)

;; Updates a user's profile.
;; @param bio: The new bio.
;; @param email: The new email address.
;; @returns (ok bool): True if the update is successful.
(define-public (update-profile (bio (string-utf8 256)) (email (string-utf8 64)))
  (begin
    (asserts! (and 
                (> (len bio) u0)
                (>= (len bio) u1)
                (<= (len bio) u256)
                (> (len email) u0)
                (>= (len email) u1)
                (<= (len email) u64))
              (err ERR_INVALID_INPUT))
    (let (
      (validated-bio (try! (validate-bio bio)))
      (validated-email (try! (validate-email email)))
    )
      (match (map-get? Users tx-sender)
        user-data 
          (match (set-user-data tx-sender
            (merge user-data
              {
                bio: validated-bio,
                email: validated-email
              }
            ))
            success (ok true)
            error (err ERR_DATA_STORE_FAILURE))
        (err ERR_USER_NOT_FOUND)
      )
    )
  )
)

;; Rates a user.
;; @param user: The principal of the user to rate.
;; @param rating: The rating value (1-5).
;; @returns (ok bool): True if the rating is successful.
(define-public (rate-user (user principal) (rating uint))
  (begin
    (asserts! (is-valid-principal user) (err ERR_INVALID_PRINCIPAL))
    (asserts! (not (is-eq tx-sender user)) (err ERR_SELF_RATING))
    (asserts! (and (>= rating u1) (<= rating u5)) (err ERR_INVALID_RATING))
    (match (map-get? Users user)
      user-data
        (match (set-user-data user
          (merge user-data
            {
              total-ratings: (+ (get total-ratings user-data) u1),
              rating-sum: (+ (get rating-sum user-data) rating)
            }
          ))
          success (ok true)
          error (err ERR_DATA_STORE_FAILURE))
      (err ERR_USER_NOT_FOUND)
    )
  )
)

;; Calculates a user's reputation score.
;; @param user: The principal of the user.
;; @returns (ok bool): True if the calculation is successful.
(define-public (calculate-reputation (user principal))
  (begin
    (asserts! (is-valid-principal user) (err ERR_INVALID_PRINCIPAL))
    (match (map-get? Users user)
      user-data
        (let (
          (total-ratings (get total-ratings user-data))
          (rating-sum (get rating-sum user-data))
          (avg-rating (if (> total-ratings u0) (/ rating-sum total-ratings) u0))
          (new-reputation (+ (* avg-rating u20) (* total-ratings u2)))
        )
        (match (set-user-data user
          (merge user-data
            {
              reputation-score: new-reputation
            }
          ))
          success (ok true)
          error (err ERR_DATA_STORE_FAILURE)))
      (err ERR_USER_NOT_FOUND)
    )
  )
)

;; Authorizes a user for specific actions.
;; @param user: The principal to authorize.
;; @returns (ok bool): True if authorization is successful.
(define-public (authorize-user (user principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_NOT_AUTHORIZED))
    (asserts! (is-valid-principal user) (err ERR_INVALID_PRINCIPAL))
    (ok (map-set UserAuthorization user true))
  )
)

;; Revokes a user's authorization.
;; @param user: The principal to revoke authorization from.
;; @returns (ok bool): True if revocation is successful.
(define-public (revoke-authorization (user principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_NOT_AUTHORIZED))
    (asserts! (is-valid-principal user) (err ERR_INVALID_PRINCIPAL))
    (ok (map-set UserAuthorization user false))
  )
)

;; --- Contract Initialization ---
;; Initializes the contract upon deployment.
(begin
  (map-set UserAuthorization CONTRACT_OWNER true)
  (print "UserProfile contract initialized")
  (ok true)
)
