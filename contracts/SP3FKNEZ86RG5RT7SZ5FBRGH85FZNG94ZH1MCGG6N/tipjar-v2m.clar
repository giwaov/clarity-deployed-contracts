;; TipJar Contract v2m - Enhanced with validation, admin controls, and improved events
;; Contract 2 of 3 for Stacks Transaction Hub

;; ============================================
;; CONTRACT METADATA
;; ============================================
(define-constant CONTRACT-NAME "tipjar")
(define-constant VERSION u5)

;; ============================================
;; CONFIGURATION
;; ============================================
(define-constant contract-owner tx-sender)
(define-constant interaction-fee u1000) ;; 0.001 STX = 1000 microSTX
(define-constant MIN-TIP u1000) ;; Minimum tip: 0.001 STX
(define-constant MAX-TIP u100000000000) ;; Maximum tip: 100,000 STX

;; ============================================
;; ERROR CODES
;; ============================================
;; Fee/Transfer errors (100-109)
(define-constant ERR-INSUFFICIENT-BALANCE (err u100))
(define-constant ERR-TRANSFER-FAILED (err u101))

;; Authorization errors (110-119)
(define-constant ERR-NOT-OWNER (err u110))
(define-constant ERR-UNAUTHORIZED (err u111))
(define-constant ERR-SELF-TIP (err u112))

;; State errors (120-129)
(define-constant ERR-CONTRACT-PAUSED (err u120))

;; Input validation errors (130-139)
(define-constant ERR-INVALID-AMOUNT (err u130))
(define-constant ERR-ZERO-VALUE (err u131))
(define-constant ERR-TIP-TOO-SMALL (err u132))
(define-constant ERR-TIP-TOO-LARGE (err u133))
(define-constant ERR-INVALID-RECIPIENT (err u134))

;; ============================================
;; DATA VARIABLES
;; ============================================
(define-data-var total-tips uint u0)
(define-data-var tip-count uint u0)
(define-data-var total-fees-collected uint u0)
(define-data-var last-activity-block uint u0)
(define-data-var unique-tippers uint u0)
(define-data-var largest-tip uint u0)
(define-data-var is-paused bool false)

;; ============================================
;; DATA MAPS
;; ============================================
(define-map user-tips-sent principal uint)
(define-map user-tips-received principal uint)
(define-map user-tip-count principal uint)
(define-map user-first-tip principal uint)

;; ============================================
;; PRIVATE FUNCTIONS
;; ============================================

;; Check if contract is active
(define-private (check-not-paused)
  (ok (asserts! (not (var-get is-paused)) ERR-CONTRACT-PAUSED))
)

;; Check if caller is owner
(define-private (check-owner)
  (ok (asserts! (is-eq tx-sender contract-owner) ERR-NOT-OWNER))
)

;; Collect interaction fee
(define-private (collect-fee)
  (begin
    (try! (stx-transfer? interaction-fee tx-sender contract-owner))
    (var-set total-fees-collected (+ (var-get total-fees-collected) interaction-fee))
    (ok true)
  )
)

;; Validate tip amount
(define-private (validate-tip-amount (amount uint))
  (begin
    (asserts! (> amount u0) ERR-ZERO-VALUE)
    (asserts! (>= amount MIN-TIP) ERR-TIP-TOO-SMALL)
    (asserts! (<= amount MAX-TIP) ERR-TIP-TOO-LARGE)
    (ok true)
  )
)

;; Track new tipper
(define-private (track-new-tipper)
  (if (is-eq (default-to u0 (map-get? user-tip-count tx-sender)) u0)
    (begin
      (var-set unique-tippers (+ (var-get unique-tippers) u1))
      (map-set user-first-tip tx-sender block-height)
      true
    )
    false
  )
)

;; Track largest tip
(define-private (track-largest-tip (amount uint))
  (if (> amount (var-get largest-tip))
    (begin
      (var-set largest-tip amount)
      true
    )
    false
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-version)
  VERSION
)

(define-read-only (get-contract-name)
  CONTRACT-NAME
)

(define-read-only (get-total-tips)
  (var-get total-tips)
)

(define-read-only (get-tip-count)
  (var-get tip-count)
)

(define-read-only (get-total-fees-collected)
  (var-get total-fees-collected)
)

(define-read-only (get-interaction-fee)
  interaction-fee
)

(define-read-only (get-user-tips-sent (user principal))
  (default-to u0 (map-get? user-tips-sent user))
)

(define-read-only (get-user-tips-received (user principal))
  (default-to u0 (map-get? user-tips-received user))
)

(define-read-only (get-user-tip-count (user principal))
  (default-to u0 (map-get? user-tip-count user))
)

(define-read-only (get-unique-tippers)
  (var-get unique-tippers)
)

(define-read-only (get-largest-tip)
  (var-get largest-tip)
)

(define-read-only (get-last-activity-block)
  (var-get last-activity-block)
)

(define-read-only (is-contract-paused)
  (var-get is-paused)
)

(define-read-only (get-stats)
  {
    total-tips: (var-get total-tips),
    tip-count: (var-get tip-count),
    fees-collected: (var-get total-fees-collected),
    largest-tip: (var-get largest-tip),
    paused: (var-get is-paused)
  }
)

(define-read-only (get-contract-info)
  {
    name: CONTRACT-NAME,
    version: VERSION,
    total-tips: (var-get total-tips),
    tip-count: (var-get tip-count),
    unique-tippers: (var-get unique-tippers),
    largest-tip: (var-get largest-tip),
    fee: interaction-fee,
    min-tip: MIN-TIP,
    max-tip: MAX-TIP,
    last-activity: (var-get last-activity-block),
    owner: contract-owner,
    paused: (var-get is-paused)
  }
)

;; ============================================
;; PUBLIC FUNCTIONS
;; ============================================

;; Tip the owner - send additional STX + 0.001 STX fee
(define-public (tip (amount uint))
  (let
    (
      (current-sent (get-user-tips-sent tx-sender))
      (current-received (get-user-tips-received contract-owner))
      (current-tip-count (get-user-tip-count tx-sender))
      (new-tip-count (+ (var-get tip-count) u1))
      (new-total-tips (+ (var-get total-tips) amount))
    )
    ;; Check contract is active
    (try! (check-not-paused))
    ;; Validate tip amount
    (try! (validate-tip-amount amount))
    ;; Track new tipper
    (track-new-tipper)
    ;; Collect fee first
    (try! (collect-fee))
    ;; Transfer tip
    (try! (stx-transfer? amount tx-sender contract-owner))
    ;; Update state
    (map-set user-tips-sent tx-sender (+ current-sent amount))
    (map-set user-tips-received contract-owner (+ current-received amount))
    (map-set user-tip-count tx-sender (+ current-tip-count u1))
    (var-set total-tips new-total-tips)
    (var-set tip-count new-tip-count)
    (var-set last-activity-block block-height)
    (track-largest-tip amount)
    ;; Emit enhanced event
    (print {
      event: "tip",
      version: VERSION,
      from: tx-sender,
      to: contract-owner,
      amount: amount,
      total-tips: new-total-tips,
      tip-number: new-tip-count,
      block: block-height
    })
    (ok amount)
  )
)

;; Tip a specific user - send STX + 0.001 STX fee
(define-public (tip-user (recipient principal) (amount uint))
  (let
    (
      (current-sent (get-user-tips-sent tx-sender))
      (current-received (get-user-tips-received recipient))
      (current-tip-count (get-user-tip-count tx-sender))
      (new-tip-count (+ (var-get tip-count) u1))
      (new-total-tips (+ (var-get total-tips) amount))
    )
    ;; Check contract is active
    (try! (check-not-paused))
    ;; Validate recipient
    (asserts! (not (is-eq tx-sender recipient)) ERR-SELF-TIP)
    ;; Validate tip amount
    (try! (validate-tip-amount amount))
    ;; Track new tipper
    (track-new-tipper)
    ;; Collect fee first
    (try! (collect-fee))
    ;; Transfer tip
    (try! (stx-transfer? amount tx-sender recipient))
    ;; Update state
    (map-set user-tips-sent tx-sender (+ current-sent amount))
    (map-set user-tips-received recipient (+ current-received amount))
    (map-set user-tip-count tx-sender (+ current-tip-count u1))
    (var-set total-tips new-total-tips)
    (var-set tip-count new-tip-count)
    (var-set last-activity-block block-height)
    (track-largest-tip amount)
    ;; Emit enhanced event
    (print {
      event: "tip-user",
      version: VERSION,
      from: tx-sender,
      to: recipient,
      amount: amount,
      total-tips: new-total-tips,
      tip-number: new-tip-count,
      block: block-height
    })
    (ok amount)
  )
)

;; Quick tip (fixed small amount) - 0.01 STX + 0.001 STX fee
(define-public (quick-tip)
  (let
    (
      (tip-amount u10000) ;; 0.01 STX
      (current-sent (get-user-tips-sent tx-sender))
      (current-received (get-user-tips-received contract-owner))
      (current-tip-count (get-user-tip-count tx-sender))
      (new-tip-count (+ (var-get tip-count) u1))
      (new-total-tips (+ (var-get total-tips) tip-amount))
    )
    ;; Check contract is active
    (try! (check-not-paused))
    ;; Track new tipper
    (track-new-tipper)
    ;; Collect fee first
    (try! (collect-fee))
    ;; Transfer tip
    (try! (stx-transfer? tip-amount tx-sender contract-owner))
    ;; Update state
    (map-set user-tips-sent tx-sender (+ current-sent tip-amount))
    (map-set user-tips-received contract-owner (+ current-received tip-amount))
    (map-set user-tip-count tx-sender (+ current-tip-count u1))
    (var-set total-tips new-total-tips)
    (var-set tip-count new-tip-count)
    (var-set last-activity-block block-height)
    ;; Emit enhanced event
    (print {
      event: "quick-tip",
      version: VERSION,
      from: tx-sender,
      to: contract-owner,
      amount: tip-amount,
      total-tips: new-total-tips,
      block: block-height
    })
    (ok tip-amount)
  )
)

;; Ping - costs 0.001 STX
(define-public (ping)
  (begin
    (try! (check-not-paused))
    (try! (collect-fee))
    (var-set last-activity-block block-height)
    (print {
      event: "ping",
      version: VERSION,
      user: tx-sender,
      block: block-height
    })
    (ok block-height)
  )
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

;; Pause contract (owner only)
(define-public (pause)
  (begin
    (try! (check-owner))
    (var-set is-paused true)
    (print {
      event: "contract-paused",
      version: VERSION,
      by: tx-sender,
      block: block-height
    })
    (ok true)
  )
)

;; Unpause contract (owner only)
(define-public (unpause)
  (begin
    (try! (check-owner))
    (var-set is-paused false)
    (print {
      event: "contract-unpaused",
      version: VERSION,
      by: tx-sender,
      block: block-height
    })
    (ok true)
  )
)
