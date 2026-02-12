;; Loiters Core Contract
;; Main contract for user profiles, reputation, check-ins, and endorsements

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant CHECKIN-COOLDOWN u86400) ;; 24 hours in seconds
(define-constant ENDORSEMENT-COOLDOWN u604800) ;; 7 days in seconds
(define-constant BASE-CHECKIN-REWARD u10000000) ;; 10 LOIT (with 6 decimals)
(define-constant ENDORSEMENT-REWARD u5000000) ;; 5 LOIT
(define-constant MAX-USERNAME-LENGTH u32)
(define-constant MIN-USERNAME-LENGTH u3)

;; Error codes (importing from loiters-errors)
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-USER-NOT-REGISTERED (err u1100))
(define-constant ERR-USERNAME-TAKEN (err u1101))
(define-constant ERR-INVALID-USERNAME (err u1102))
(define-constant ERR-USER-ALREADY-REGISTERED (err u1103))
(define-constant ERR-CHECKIN-TOO-SOON (err u1300))
(define-constant ERR-CANNOT-ENDORSE-SELF (err u1400))
(define-constant ERR-ENDORSEMENT-COOLDOWN (err u1401))
(define-constant ERR-CONTRACT-PAUSED (err u1004))

;; Reputation tiers
(define-constant TIER-BRONZE u0)
(define-constant TIER-SILVER u1000)
(define-constant TIER-GOLD u5000)
(define-constant TIER-PLATINUM u15000)
(define-constant TIER-DIAMOND u50000)

;; Data Variables
(define-data-var contract-paused bool false)
(define-data-var total-users uint u0)
(define-data-var total-checkins uint u0)
(define-data-var loiters-token-contract principal tx-sender) ;; Will be set to token contract

;; Data Maps

;; User profiles
(define-map users
  principal
  {
    username: (string-utf8 32),
    bio: (string-utf8 256),
    avatar-uri: (string-utf8 256),
    reputation-score: uint,
    total-checkins: uint,
    current-streak: uint,
    longest-streak: uint,
    total-endorsements-received: uint,
    total-endorsements-given: uint,
    joined-at: uint,
    last-checkin: uint
  }
)

;; Username to principal mapping
(define-map usernames (string-utf8 32) principal)

;; Check-in history
(define-map checkins
  {user: principal, checkin-id: uint}
  {
    latitude: int,
    longitude: int,
    timestamp: uint,
    reward-amount: uint
  }
)

;; User check-in counter
(define-map user-checkin-count principal uint)

;; Endorsements
(define-map endorsements
  {endorser: principal, endorsed: principal}
  {
    timestamp: uint,
    message: (string-utf8 256)
  }
)

;; Endorsement cooldown tracking
(define-map endorsement-cooldowns
  {endorser: principal, endorsed: principal}
  uint
)

;; Read-only functions

(define-read-only (get-user (user principal))
  (map-get? users user)
)

(define-read-only (get-user-by-username (username (string-utf8 32)))
  (match (map-get? usernames username)
    user-principal (get-user user-principal)
    none
  )
)

(define-read-only (get-total-users)
  (var-get total-users)
)

(define-read-only (get-total-checkins)
  (var-get total-checkins)
)

(define-read-only (get-checkin (user principal) (checkin-id uint))
  (map-get? checkins {user: user, checkin-id: checkin-id})
)

(define-read-only (get-user-checkin-count (user principal))
  (default-to u0 (map-get? user-checkin-count user))
)

(define-read-only (get-endorsement (endorser principal) (endorsed principal))
  (map-get? endorsements {endorser: endorser, endorsed: endorsed})
)

(define-read-only (get-reputation-tier (reputation uint))
  (if (>= reputation TIER-DIAMOND)
    "Diamond"
    (if (>= reputation TIER-PLATINUM)
      "Platinum"
      (if (>= reputation TIER-GOLD)
        "Gold"
        (if (>= reputation TIER-SILVER)
          "Silver"
          "Bronze"
        )
      )
    )
  )
)

(define-read-only (calculate-checkin-reward (streak uint))
  (let
    (
      (multiplier (if (>= streak u30)
                    u5
                    (if (>= streak u14)
                      u3
                      (if (>= streak u7)
                        u2
                        u1
                      )
                    )
                  ))
    )
    (* BASE-CHECKIN-REWARD multiplier)
  )
)

;; Public functions

;; Register a new user
(define-public (register-user (username (string-utf8 32)) (bio (string-utf8 256)) (avatar-uri (string-utf8 256)))
  (let
    (
      (username-len (len username))
      (existing-user (map-get? users tx-sender))
      (existing-username (map-get? usernames username))
    )
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (is-none existing-user) ERR-USER-ALREADY-REGISTERED)
    (asserts! (is-none existing-username) ERR-USERNAME-TAKEN)
    (asserts! (and (>= username-len MIN-USERNAME-LENGTH) (<= username-len MAX-USERNAME-LENGTH)) ERR-INVALID-USERNAME)
    
    (map-set users tx-sender {
      username: username,
      bio: bio,
      avatar-uri: avatar-uri,
      reputation-score: u0,
      total-checkins: u0,
      current-streak: u0,
      longest-streak: u0,
      total-endorsements-received: u0,
      total-endorsements-given: u0,
      joined-at: stacks-block-height,
      last-checkin: u0
    })
    
    (map-set usernames username tx-sender)
    (var-set total-users (+ (var-get total-users) u1))
    
    (print {
      type: "user-registered",
      user: tx-sender,
      username: username,
      timestamp: stacks-block-height
    })
    
    (ok true)
  )
)

;; Update user profile
(define-public (update-profile (bio (string-utf8 256)) (avatar-uri (string-utf8 256)))
  (let
    (
      (user-data (unwrap! (map-get? users tx-sender) ERR-USER-NOT-REGISTERED))
    )
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    
    (map-set users tx-sender (merge user-data {
      bio: bio,
      avatar-uri: avatar-uri
    }))
    
    (ok true)
  )
)

;; Check-in at a location
(define-public (checkin (latitude int) (longitude int))
  (let
    (
      (user-data (unwrap! (map-get? users tx-sender) ERR-USER-NOT-REGISTERED))
      (last-checkin (get last-checkin user-data))
      (current-time stacks-block-height)
      (time-since-last (- current-time last-checkin))
      (checkin-count (get-user-checkin-count tx-sender))
      (new-streak (if (and (> last-checkin u0) (<= time-since-last CHECKIN-COOLDOWN))
                    (+ (get current-streak user-data) u1)
                    u1))
      (reward (calculate-checkin-reward new-streak))
    )
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (or (is-eq last-checkin u0) (>= time-since-last CHECKIN-COOLDOWN)) ERR-CHECKIN-TOO-SOON)
    
    ;; Record check-in
    (map-set checkins {user: tx-sender, checkin-id: checkin-count} {
      latitude: latitude,
      longitude: longitude,
      timestamp: current-time,
      reward-amount: reward
    })
    
    ;; Update user data
    (map-set users tx-sender (merge user-data {
      total-checkins: (+ (get total-checkins user-data) u1),
      current-streak: new-streak,
      longest-streak: (if (> new-streak (get longest-streak user-data)) new-streak (get longest-streak user-data)),
      last-checkin: current-time,
      reputation-score: (+ (get reputation-score user-data) u10) ;; +10 reputation per check-in
    }))
    
    (map-set user-checkin-count tx-sender (+ checkin-count u1))
    (var-set total-checkins (+ (var-get total-checkins) u1))
    
    ;; Mint reward tokens (will be implemented when token contract is integrated)
    ;; (try! (contract-call? .loiters-token mint reward tx-sender))
    
    (print {
      type: "checkin",
      user: tx-sender,
      checkin-id: checkin-count,
      latitude: latitude,
      longitude: longitude,
      streak: new-streak,
      reward: reward,
      timestamp: current-time
    })
    
    (ok reward)
  )
)

;; Endorse another user
(define-public (endorse-user (endorsed principal) (message (string-utf8 256)))
  (let
    (
      (endorser-data (unwrap! (map-get? users tx-sender) ERR-USER-NOT-REGISTERED))
      (endorsed-data (unwrap! (map-get? users endorsed) ERR-USER-NOT-REGISTERED))
      (last-endorsement (default-to u0 (map-get? endorsement-cooldowns {endorser: tx-sender, endorsed: endorsed})))
      (current-time stacks-block-height)
      (time-since-last (- current-time last-endorsement))
      (endorser-reputation (get reputation-score endorser-data))
      (reputation-bonus (/ endorser-reputation u100)) ;; 1% of endorser's reputation
    )
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (not (is-eq tx-sender endorsed)) ERR-CANNOT-ENDORSE-SELF)
    (asserts! (or (is-eq last-endorsement u0) (>= time-since-last ENDORSEMENT-COOLDOWN)) ERR-ENDORSEMENT-COOLDOWN)
    
    ;; Record endorsement
    (map-set endorsements {endorser: tx-sender, endorsed: endorsed} {
      timestamp: current-time,
      message: message
    })
    
    (map-set endorsement-cooldowns {endorser: tx-sender, endorsed: endorsed} current-time)
    
    ;; Update endorser stats
    (map-set users tx-sender (merge endorser-data {
      total-endorsements-given: (+ (get total-endorsements-given endorser-data) u1)
    }))
    
    ;; Update endorsed user stats and reputation
    (map-set users endorsed (merge endorsed-data {
      total-endorsements-received: (+ (get total-endorsements-received endorsed-data) u1),
      reputation-score: (+ (+ (get reputation-score endorsed-data) u50) reputation-bonus) ;; Base +50 + bonus
    }))
    
    ;; Reward endorsed user (will be implemented when token contract is integrated)
    ;; (try! (contract-call? .loiters-token mint ENDORSEMENT-REWARD endorsed))
    
    (print {
      type: "endorsement",
      endorser: tx-sender,
      endorsed: endorsed,
      message: message,
      reputation-bonus: reputation-bonus,
      timestamp: current-time
    })
    
    (ok true)
  )
)

;; Admin functions

(define-public (set-token-contract (token-contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set loiters-token-contract token-contract))
  )
)

(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-paused true))
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-paused false))
  )
)
