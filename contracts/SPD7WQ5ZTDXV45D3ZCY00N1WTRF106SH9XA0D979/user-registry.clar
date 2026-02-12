;; User Registry Contract
;; Manages user profiles and KYC status

(define-map users 
  { user-address: principal }
  {
    username: (string-ascii 50),
    registration-block: uint,
    kyc-verified: bool,
    reputation-score: uint
  }
)

(define-data-var total-users uint u0)

;; Register new user
(define-public (register-user (username (string-ascii 50)))
  (let
    (
      (caller tx-sender)
      (user-exists (map-get? users { user-address: caller }))
    )
    (asserts! (is-none user-exists) (err u100)) ;; User already registered
    (asserts! (> (len username) u0) (err u101)) ;; Username required
    
    (map-set users
      { user-address: caller }
      {
        username: username,
        registration-block: stacks-block-height,
        kyc-verified: false,
        reputation-score: u100
      }
    )
    
    (var-set total-users (+ (var-get total-users) u1))
    (ok true)
  )
)

;; Update KYC status (admin only)
(define-public (verify-kyc (user principal))
  (let
    (
      (user-data (unwrap! (map-get? users { user-address: user }) (err u102)))
    )
    (asserts! (is-eq tx-sender contract-owner) (err u103)) ;; Only owner can verify
    
    (map-set users
      { user-address: user }
      (merge user-data { kyc-verified: true })
    )
    (ok true)
  )
)

;; Get user details
(define-read-only (get-user (user principal))
  (map-get? users { user-address: user })
)

;; Get total users
(define-read-only (get-total-users)
  (ok (var-get total-users))
)

(define-constant contract-owner tx-sender)
