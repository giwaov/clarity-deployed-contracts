;; Stacks Tip Jar - Creator Monetization
;; Accept tips and donations on Stacks

;; Constants
(define-constant err-owner-only (err u100))
(define-constant err-invalid-amount (err u101))
(define-constant err-creator-not-found (err u102))

;; Data Variables
(define-data-var total-tips uint u0)
(define-data-var total-creators uint u0)
(define-data-var total-tippers uint u0)

;; Creator profiles
(define-map creators principal
  {
    name: (string-utf8 64),
    bio: (string-utf8 256),
    total-received: uint,
    tip-count: uint,
    registered-at: uint
  }
)

;; Tip history
(define-map tips uint
  {
    from: principal,
    to: principal,
    amount: uint,
    message: (optional (string-utf8 128)),
    block: uint
  }
)

(define-data-var tip-nonce uint u0)

;; Tipper stats
(define-map tipper-stats principal
  {
    total-tipped: uint,
    tip-count: uint,
    creators-supported: uint
  }
)

;; Track unique creator support
(define-map supporter-creator { supporter: principal, creator: principal } bool)

;; Read-only functions
(define-read-only (get-creator (creator principal))
  (map-get? creators creator)
)

(define-read-only (get-tip (tip-id uint))
  (map-get? tips tip-id)
)

(define-read-only (get-tipper-stats (tipper principal))
  (default-to 
    { total-tipped: u0, tip-count: u0, creators-supported: u0 }
    (map-get? tipper-stats tipper)
  )
)

(define-read-only (is-creator-registered (creator principal))
  (is-some (map-get? creators creator))
)

(define-read-only (get-platform-stats)
  {
    total-tips: (var-get total-tips),
    total-creators: (var-get total-creators),
    total-tippers: (var-get total-tippers),
    total-tip-count: (var-get tip-nonce)
  }
)

;; Public functions

;; Register as a creator
(define-public (register-creator (name (string-utf8 64)) (bio (string-utf8 256)))
  (begin
    (asserts! (not (is-creator-registered tx-sender)) err-owner-only)
    
    (map-set creators tx-sender {
      name: name,
      bio: bio,
      total-received: u0,
      tip-count: u0,
      registered-at: stacks-block-height
    })
    
    (var-set total-creators (+ (var-get total-creators) u1))
    
    (ok { creator: tx-sender, registered: true })
  )
)

;; Update creator profile
(define-public (update-profile (name (string-utf8 64)) (bio (string-utf8 256)))
  (match (map-get? creators tx-sender)
    creator
    (begin
      (map-set creators tx-sender 
        (merge creator { name: name, bio: bio })
      )
      (ok true)
    )
    err-creator-not-found
  )
)

;; Send a tip (accounting only - STX goes to treasury)
(define-public (send-tip (creator principal) (amount uint) (message (optional (string-utf8 128))))
  (let (
    (tip-id (var-get tip-nonce))
    (is-new-supporter (not (default-to false (map-get? supporter-creator { supporter: tx-sender, creator: creator }))))
    (tipper-stat (get-tipper-stats tx-sender))
    (is-first-tip (is-eq (get tip-count tipper-stat) u0))
  )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (is-creator-registered creator) err-creator-not-found)
    
    ;; Record tip
    (map-set tips tip-id {
      from: tx-sender,
      to: creator,
      amount: amount,
      message: message,
      block: stacks-block-height
    })
    
    ;; Update creator stats
    (match (map-get? creators creator)
      c
      (map-set creators creator 
        (merge c {
          total-received: (+ (get total-received c) amount),
          tip-count: (+ (get tip-count c) u1)
        })
      )
      false
    )
    
    ;; Update tipper stats
    (map-set tipper-stats tx-sender {
      total-tipped: (+ (get total-tipped tipper-stat) amount),
      tip-count: (+ (get tip-count tipper-stat) u1),
      creators-supported: (if is-new-supporter 
                           (+ (get creators-supported tipper-stat) u1)
                           (get creators-supported tipper-stat))
    })
    
    ;; Mark supporter-creator relationship
    (if is-new-supporter
      (map-set supporter-creator { supporter: tx-sender, creator: creator } true)
      false
    )
    
    ;; Update globals
    (var-set tip-nonce (+ tip-id u1))
    (var-set total-tips (+ (var-get total-tips) amount))
    (if is-first-tip
      (var-set total-tippers (+ (var-get total-tippers) u1))
      false
    )
    
    (ok { tip-id: tip-id, amount: amount, to: creator })
  )
)

;; Get recent tips for a creator
(define-read-only (get-creator-tip-count (creator principal))
  (match (map-get? creators creator)
    c (get tip-count c)
    u0
  )
)

