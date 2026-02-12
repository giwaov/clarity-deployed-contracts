;; StackSusu Referral v7
;; Simplified referral system

(define-constant CONTRACT-OWNER tx-sender)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u6000))
(define-constant ERR-CODE-EXISTS (err u6001))
(define-constant ERR-CODE-NOT-FOUND (err u6002))
(define-constant ERR-SELF-REFERRAL (err u6003))
(define-constant ERR-ALREADY-REFERRED (err u6004))

;; Configuration
(define-constant REFERRAL-BONUS-BPS u100) ;; 1% bonus to referrer

;; Referral codes
(define-map referral-codes
  (string-ascii 20)  ;; code
  {
    owner: principal,
    uses: uint,
    total-earned: uint,
    created-at: uint,
    active: bool
  }
)

;; User's referrer
(define-map user-referrer
  principal
  principal
)

;; User's referral stats
(define-map referral-stats
  principal
  {
    code: (string-ascii 20),
    referrals: uint,
    total-earned: uint
  }
)


;; ============================================
;; Referral Functions
;; ============================================

(define-public (create-referral-code (code (string-ascii 20)))
  (let
    (
      (creator tx-sender)
    )
    (asserts! (is-none (map-get? referral-codes code)) ERR-CODE-EXISTS)
    
    (map-set referral-codes code {
      owner: creator,
      uses: u0,
      total-earned: u0,
      created-at: block-height,
      active: true
    })
    
    (map-set referral-stats creator {
      code: code,
      referrals: u0,
      total-earned: u0
    })
    
    (ok true)
  )
)

(define-public (use-referral-code (code (string-ascii 20)))
  (let
    (
      (user tx-sender)
      (ref-data (unwrap! (map-get? referral-codes code) ERR-CODE-NOT-FOUND))
      (referrer (get owner ref-data))
    )
    (asserts! (not (is-eq user referrer)) ERR-SELF-REFERRAL)
    (asserts! (is-none (map-get? user-referrer user)) ERR-ALREADY-REFERRED)
    (asserts! (get active ref-data) ERR-CODE-NOT-FOUND)
    
    ;; Set referrer
    (map-set user-referrer user referrer)
    
    ;; Update code usage
    (map-set referral-codes code (merge ref-data {
      uses: (+ (get uses ref-data) u1)
    }))
    
    ;; Update referrer stats
    (match (map-get? referral-stats referrer)
      stats (map-set referral-stats referrer (merge stats {
        referrals: (+ (get referrals stats) u1)
      }))
      true
    )
    
    (ok true)
  )
)

(define-public (record-referral-bonus (user principal) (amount uint))
  (let
    (
      (referrer (map-get? user-referrer user))
    )
    (match referrer
      ref (let
        (
          (bonus (/ (* amount REFERRAL-BONUS-BPS) u10000))
          (ref-stats (default-to { code: "", referrals: u0, total-earned: u0 } (map-get? referral-stats ref)))
        )
        (map-set referral-stats ref (merge ref-stats {
          total-earned: (+ (get total-earned ref-stats) bonus)
        }))
        (ok bonus)
      )
      (ok u0)
    )
  )
)

(define-public (deactivate-code (code (string-ascii 20)))
  (let
    (
      (ref-data (unwrap! (map-get? referral-codes code) ERR-CODE-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get owner ref-data)) ERR-NOT-AUTHORIZED)
    
    (map-set referral-codes code (merge ref-data { active: false }))
    (ok true)
  )
)


;; ============================================
;; Read Functions
;; ============================================

(define-read-only (get-referral-code (code (string-ascii 20)))
  (map-get? referral-codes code)
)

(define-read-only (get-user-referrer (user principal))
  (map-get? user-referrer user)
)

(define-read-only (get-referral-stats (user principal))
  (map-get? referral-stats user)
)

(define-read-only (has-referrer (user principal))
  (is-some (map-get? user-referrer user))
)
