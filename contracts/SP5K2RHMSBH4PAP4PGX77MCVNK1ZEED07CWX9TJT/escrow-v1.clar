;; escrow.clar
;; Trustless escrow service for peer-to-peer trades
;; Supports milestone-based releases and dispute resolution

;; ============================================================================
;; Constants
;; ============================================================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-ESCROW-NOT-FOUND (err u402))
(define-constant ERR-INVALID-STATE (err u403))
(define-constant ERR-INSUFFICIENT-BALANCE (err u404))
(define-constant ERR-INVALID-AMOUNT (err u405))
(define-constant ERR-DEADLINE-PASSED (err u406))
(define-constant ERR-DEADLINE-NOT-PASSED (err u407))
(define-constant ERR-ALREADY-FUNDED (err u408))
(define-constant ERR-NOT-PARTY (err u409))
(define-constant ERR-DISPUTE-EXISTS (err u410))
(define-constant ERR-NO-DISPUTE (err u411))

;; Minimum amounts
(define-constant MIN-ESCROW-AMOUNT u1000) ;; 0.001 STX minimum (1000 microSTX)

;; Escrow states
(define-constant STATE-PENDING u0)
(define-constant STATE-FUNDED u1)
(define-constant STATE-RELEASED u2)
(define-constant STATE-REFUNDED u3)
(define-constant STATE-DISPUTED u4)
(define-constant STATE-RESOLVED u5)

;; ============================================================================
;; Data Variables
;; ============================================================================

(define-data-var escrow-count uint u0)
(define-data-var total-volume uint u0)
(define-data-var dispute-count uint u0)
(define-data-var arbitrator principal CONTRACT-OWNER)
(define-data-var fee-bps uint u50) ;; 0.5% fee

;; ============================================================================
;; Data Maps
;; ============================================================================

;; Main escrow storage
(define-map escrows uint
  {
    buyer: principal,
    seller: principal,
    amount: uint,
    fee: uint,
    state: uint,
    created-at: uint,
    deadline: uint,
    description: (string-ascii 256),
    milestone-count: uint,
    milestones-released: uint
  })

;; Milestone details
(define-map milestones
  { escrow-id: uint, milestone-id: uint }
  {
    amount: uint,
    description: (string-ascii 128),
    is-released: bool,
    released-at: uint
  })

;; Dispute information
(define-map disputes uint
  {
    escrow-id: uint,
    initiated-by: principal,
    reason: (string-ascii 256),
    created-at: uint,
    resolved: bool,
    resolution: (string-ascii 256),
    buyer-refund: uint,
    seller-payment: uint
  })

;; User statistics
(define-map user-stats principal
  {
    escrows-created: uint,
    escrows-completed: uint,
    total-volume: uint,
    disputes-initiated: uint,
    disputes-won: uint
  })

;; ============================================================================
;; Read-Only Functions
;; ============================================================================

(define-read-only (get-escrow (escrow-id uint))
  (map-get? escrows escrow-id))

(define-read-only (get-milestone (escrow-id uint) (milestone-id uint))
  (map-get? milestones { escrow-id: escrow-id, milestone-id: milestone-id }))

(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes dispute-id))

(define-read-only (get-user-stats (user principal))
  (default-to
    { escrows-created: u0, escrows-completed: u0, total-volume: u0, disputes-initiated: u0, disputes-won: u0 }
    (map-get? user-stats user)))

(define-read-only (get-escrow-count)
  (var-get escrow-count))

(define-read-only (get-total-volume)
  (var-get total-volume))

(define-read-only (get-fee-bps)
  (var-get fee-bps))

(define-read-only (calculate-fee (amount uint))
  (/ (* amount (var-get fee-bps)) u10000))

(define-read-only (is-party (escrow-id uint) (user principal))
  (match (map-get? escrows escrow-id)
    escrow (or (is-eq (get buyer escrow) user) (is-eq (get seller escrow) user))
    false))

(define-read-only (get-platform-stats)
  {
    total-escrows: (var-get escrow-count),
    total-volume: (var-get total-volume),
    total-disputes: (var-get dispute-count),
    fee-bps: (var-get fee-bps),
    arbitrator: (var-get arbitrator)
  })

;; ============================================================================
;; Escrow Creation
;; ============================================================================

;; Create basic escrow
(define-public (create-escrow 
    (seller principal)
    (amount uint)
    (deadline uint)
    (description (string-ascii 256)))
  (let
    (
      (escrow-id (+ (var-get escrow-count) u1))
      (fee (calculate-fee amount))
      (buyer-stats (get-user-stats tx-sender))
    )
    (asserts! (>= amount MIN-ESCROW-AMOUNT) ERR-INVALID-AMOUNT)
    (asserts! (> deadline stacks-block-height) ERR-DEADLINE-PASSED)
    (asserts! (not (is-eq tx-sender seller)) ERR-NOT-AUTHORIZED)
    
    ;; Create escrow
    (map-set escrows escrow-id
      {
        buyer: tx-sender,
        seller: seller,
        amount: amount,
        fee: fee,
        state: STATE-PENDING,
        created-at: stacks-block-height,
        deadline: deadline,
        description: description,
        milestone-count: u0,
        milestones-released: u0
      })
    
    ;; Update user stats
    (map-set user-stats tx-sender
      (merge buyer-stats { escrows-created: (+ (get escrows-created buyer-stats) u1) }))
    
    (var-set escrow-count escrow-id)
    
    (print { event: "escrow-created", escrow-id: escrow-id, buyer: tx-sender, seller: seller, amount: amount })
    (ok escrow-id)))

;; Create escrow with milestones
(define-public (create-milestone-escrow 
    (seller principal)
    (total-amount uint)
    (deadline uint)
    (description (string-ascii 256))
    (milestone-amounts (list 10 uint))
    (milestone-descriptions (list 10 (string-ascii 128))))
  (let
    (
      (escrow-id (+ (var-get escrow-count) u1))
      (fee (calculate-fee total-amount))
      (milestone-count (len milestone-amounts))
      (amount-sum (fold + milestone-amounts u0))
    )
    (asserts! (> total-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (is-eq amount-sum total-amount) ERR-INVALID-AMOUNT)
    (asserts! (> deadline stacks-block-height) ERR-DEADLINE-PASSED)
    (asserts! (> milestone-count u0) ERR-INVALID-AMOUNT)
    
    ;; Create escrow
    (map-set escrows escrow-id
      {
        buyer: tx-sender,
        seller: seller,
        amount: total-amount,
        fee: fee,
        state: STATE-PENDING,
        created-at: stacks-block-height,
        deadline: deadline,
        description: description,
        milestone-count: milestone-count,
        milestones-released: u0
      })
    
    (var-set escrow-count escrow-id)
    
    (print { event: "milestone-escrow-created", escrow-id: escrow-id, milestones: milestone-count })
    (ok escrow-id)))

;; ============================================================================
;; Funding
;; ============================================================================

;; Fund escrow (buyer)
(define-public (fund-escrow (escrow-id uint))
  (let
    (
      (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
      (total-amount (+ (get amount escrow) (get fee escrow)))
    )
    (asserts! (is-eq (get buyer escrow) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get state escrow) STATE-PENDING) ERR-INVALID-STATE)
    (asserts! (<= stacks-block-height (get deadline escrow)) ERR-DEADLINE-PASSED)
    
    ;; Transfer funds to contract
    (try! (stx-transfer? total-amount tx-sender current-contract))
    
    ;; Update state
    (map-set escrows escrow-id (merge escrow { state: STATE-FUNDED }))
    
    (print { event: "escrow-funded", escrow-id: escrow-id, amount: total-amount })
    (ok true)))

;; ============================================================================
;; Release & Refund
;; ============================================================================

;; Release funds to seller (buyer approves)
(define-public (release-funds (escrow-id uint))
  (let
    (
      (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
      (amount (get amount escrow))
      (fee (get fee escrow))
      (seller (get seller escrow))
      (seller-stats (get-user-stats seller))
      (buyer-stats (get-user-stats (get buyer escrow)))
    )
    (asserts! (is-eq (get buyer escrow) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get state escrow) STATE-FUNDED) ERR-INVALID-STATE)
    
    ;; Transfer to seller
    (try! (as-contract? ((with-stx amount)) (try! (stx-transfer? amount tx-sender seller))))
    
    ;; Update state
    (map-set escrows escrow-id (merge escrow { state: STATE-RELEASED }))
    
    ;; Update stats
    (map-set user-stats seller
      (merge seller-stats { 
        escrows-completed: (+ (get escrows-completed seller-stats) u1),
        total-volume: (+ (get total-volume seller-stats) amount)
      }))
    (map-set user-stats (get buyer escrow)
      (merge buyer-stats { escrows-completed: (+ (get escrows-completed buyer-stats) u1) }))
    
    (var-set total-volume (+ (var-get total-volume) amount))
    
    (print { event: "funds-released", escrow-id: escrow-id, amount: amount, to: seller })
    (ok amount)))

;; Refund to buyer (seller approves or deadline passed)
(define-public (refund-buyer (escrow-id uint))
  (let
    (
      (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
      (amount (get amount escrow))
      (fee (get fee escrow))
      (buyer (get buyer escrow))
    )
    (asserts! (is-eq (get state escrow) STATE-FUNDED) ERR-INVALID-STATE)
    (asserts! (or 
      (is-eq (get seller escrow) tx-sender)
      (> stacks-block-height (get deadline escrow)))
      ERR-NOT-AUTHORIZED)
    
    ;; Return funds to buyer (including fee since no trade happened)
    (try! (as-contract? ((with-stx (+ amount fee))) (try! (stx-transfer? (+ amount fee) tx-sender buyer))))
    
    ;; Update state
    (map-set escrows escrow-id (merge escrow { state: STATE-REFUNDED }))
    
    (print { event: "funds-refunded", escrow-id: escrow-id, amount: (+ amount fee), to: buyer })
    (ok (+ amount fee))))

;; ============================================================================
;; Milestone Release
;; ============================================================================

;; Release specific milestone
(define-public (release-milestone (escrow-id uint) (milestone-id uint))
  (let
    (
      (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
      (milestone (unwrap! (map-get? milestones { escrow-id: escrow-id, milestone-id: milestone-id }) ERR-ESCROW-NOT-FOUND))
    )
    (asserts! (is-eq (get buyer escrow) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get state escrow) STATE-FUNDED) ERR-INVALID-STATE)
    (asserts! (not (get is-released milestone)) ERR-INVALID-STATE)
    
    ;; Transfer milestone amount to seller
    (try! (as-contract? ((with-stx (get amount milestone))) (try! (stx-transfer? (get amount milestone) tx-sender (get seller escrow)))))
    
    ;; Update milestone
    (map-set milestones { escrow-id: escrow-id, milestone-id: milestone-id }
      (merge milestone { is-released: true, released-at: stacks-block-height }))
    
    ;; Update escrow
    (let ((new-released (+ (get milestones-released escrow) u1)))
      (map-set escrows escrow-id
        (merge escrow { 
          milestones-released: new-released,
          state: (if (is-eq new-released (get milestone-count escrow)) STATE-RELEASED (get state escrow))
        })))
    
    (print { event: "milestone-released", escrow-id: escrow-id, milestone-id: milestone-id })
    (ok true)))

;; ============================================================================
;; Dispute Resolution
;; ============================================================================

;; Initiate dispute
(define-public (initiate-dispute (escrow-id uint) (reason (string-ascii 256)))
  (let
    (
      (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
      (dispute-id (+ (var-get dispute-count) u1))
      (user-stat (get-user-stats tx-sender))
    )
    (asserts! (is-party escrow-id tx-sender) ERR-NOT-PARTY)
    (asserts! (is-eq (get state escrow) STATE-FUNDED) ERR-INVALID-STATE)
    
    ;; Create dispute
    (map-set disputes dispute-id
      {
        escrow-id: escrow-id,
        initiated-by: tx-sender,
        reason: reason,
        created-at: stacks-block-height,
        resolved: false,
        resolution: "",
        buyer-refund: u0,
        seller-payment: u0
      })
    
    ;; Update escrow state
    (map-set escrows escrow-id (merge escrow { state: STATE-DISPUTED }))
    
    ;; Update user stats
    (map-set user-stats tx-sender
      (merge user-stat { disputes-initiated: (+ (get disputes-initiated user-stat) u1) }))
    
    (var-set dispute-count dispute-id)
    
    (print { event: "dispute-initiated", dispute-id: dispute-id, escrow-id: escrow-id, by: tx-sender })
    (ok dispute-id)))

;; Resolve dispute (arbitrator only)
(define-public (resolve-dispute 
    (dispute-id uint)
    (buyer-refund-bps uint)
    (resolution (string-ascii 256)))
  (let
    (
      (dispute (unwrap! (map-get? disputes dispute-id) ERR-ESCROW-NOT-FOUND))
      (escrow-id (get escrow-id dispute))
      (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
      (amount (get amount escrow))
      (buyer-amount (/ (* amount buyer-refund-bps) u10000))
      (seller-amount (- amount buyer-amount))
    )
    (asserts! (is-eq tx-sender (var-get arbitrator)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get state escrow) STATE-DISPUTED) ERR-INVALID-STATE)
    (asserts! (not (get resolved dispute)) ERR-INVALID-STATE)
    (asserts! (<= buyer-refund-bps u10000) ERR-INVALID-AMOUNT)
    
    ;; Transfer to buyer
    (if (> buyer-amount u0)
      (try! (as-contract? ((with-stx buyer-amount)) (try! (stx-transfer? buyer-amount tx-sender (get buyer escrow)))))
      true)
    
    ;; Transfer to seller
    (if (> seller-amount u0)
      (try! (as-contract? ((with-stx seller-amount)) (try! (stx-transfer? seller-amount tx-sender (get seller escrow)))))
      true)
    
    ;; Update dispute
    (map-set disputes dispute-id
      (merge dispute {
        resolved: true,
        resolution: resolution,
        buyer-refund: buyer-amount,
        seller-payment: seller-amount
      }))
    
    ;; Update escrow
    (map-set escrows escrow-id (merge escrow { state: STATE-RESOLVED }))
    
    (print { 
      event: "dispute-resolved", 
      dispute-id: dispute-id, 
      buyer-refund: buyer-amount, 
      seller-payment: seller-amount 
    })
    (ok true)))

;; ============================================================================
;; Admin Functions
;; ============================================================================

;; Set arbitrator
(define-public (set-arbitrator (new-arbitrator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set arbitrator new-arbitrator)
    (print { event: "arbitrator-updated", arbitrator: new-arbitrator })
    (ok new-arbitrator)))

;; Update fee
(define-public (set-fee-bps (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee u500) ERR-INVALID-AMOUNT) ;; Max 5%
    (var-set fee-bps new-fee)
    (print { event: "fee-updated", fee-bps: new-fee })
    (ok new-fee)))
