;; Clout Prediction Market V2
;; "Fun-first, infinite-betting" logic

;; Errors
(define-constant ERR-NOT-ADMIN (err u100))
(define-constant ERR-MARKET-NOT-FOUND (err u101))
(define-constant ERR-MARKET-CLOSED (err u102))
(define-constant ERR-WRONG-SIDE (err u103)) ;; New Error
(define-constant ERR-INVALID-AMOUNT (err u104))
(define-constant ERR-ALREADY-CLAIMED (err u105))

;; State Variables
(define-data-var admin principal tx-sender)
(define-data-var market-counter uint u0)

;; Data Maps
(define-map markets uint {
    description: (string-ascii 100),
    betting-open: bool,
    resolved: bool,
    outcome: bool
})

(define-map predictions { market-id: uint, user: principal } { 
    choice: bool, 
    stake: uint,
    claimed: bool 
})

(define-map user-clout principal uint)

;; Read-Only Helpers
(define-read-only (get-clout (user principal))
  (default-to u100 (map-get? user-clout user))
)

(define-read-only (get-market (market-id uint))
  (map-get? markets market-id)
)

(define-read-only (get-last-market-id)
  (ok (var-get market-counter))
)

;; Public Functions

;; 1. Admin creates a market
(define-public (create-market (description (string-ascii 100)))
  (let ((id (var-get market-counter)))
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-ADMIN)
    (map-set markets id { description: description, betting-open: true, resolved: false, outcome: false })
    (var-set market-counter (+ id u1))
    (ok id)
  )
)

;; 2. PREDICT V2 (Allows multiple bets)
(define-public (predict (market-id uint) (choice bool) (stake uint))
  (let ((market (unwrap! (map-get? markets market-id) ERR-MARKET-NOT-FOUND))
        (current-clout (get-clout tx-sender))
        (prev-prediction (map-get? predictions { market-id: market-id, user: tx-sender })))
    
    ;; Checks
    (asserts! (get betting-open market) ERR-MARKET-CLOSED)
    (asserts! (>= current-clout stake) ERR-INVALID-AMOUNT)
    (asserts! (> stake u0) ERR-INVALID-AMOUNT)

    ;; V2 LOGIC: Check previous bet
    (match prev-prediction
       existing-bet 
       (begin
          ;; If they bet before, ENSURE they are betting on the same side
          (asserts! (is-eq (get choice existing-bet) choice) ERR-WRONG-SIDE)
          ;; Update: Add new stake to old stake
          (map-set predictions { market-id: market-id, user: tx-sender } 
             (merge existing-bet { stake: (+ (get stake existing-bet) stake) }))
       )
       ;; Else (First time betting)
       (begin
          (map-set predictions { market-id: market-id, user: tx-sender } 
             { choice: choice, stake: stake, claimed: false })
       )
    )

    ;; Deduct clout
    (map-set user-clout tx-sender (- current-clout stake))
    (ok true)
  )
)

;; 3. Admin resolves the market
(define-public (resolve-market (market-id uint) (outcome bool))
  (let ((market (unwrap! (map-get? markets market-id) ERR-MARKET-NOT-FOUND)))
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-ADMIN)
    (map-set markets market-id (merge market { betting-open: false, resolved: true, outcome: outcome }))
    (ok true)
  )
)

;; 4. User claims winnings
(define-public (claim (market-id uint))
  (let ((market (unwrap! (map-get? markets market-id) ERR-MARKET-NOT-FOUND))
        (prediction (unwrap! (map-get? predictions { market-id: market-id, user: tx-sender }) (err u106))))
    
    (asserts! (get resolved market) ERR-MARKET-CLOSED)
    (asserts! (not (get claimed prediction)) ERR-ALREADY-CLAIMED)

    (map-set predictions { market-id: market-id, user: tx-sender } (merge prediction { claimed: true }))

    (if (is-eq (get choice prediction) (get outcome market))
        (begin
           ;; Win: Refund stake + match it (2x total)
           (map-set user-clout tx-sender (+ (get-clout tx-sender) (* (get stake prediction) u2)))
           (ok true)
        )
        (ok false)
    )
  )
)

(define-read-only (get-user-clout (user principal))
  (ok (get-clout user))
)