;; StackSusu Emergency v6
;; Enhanced emergency system with insurance pool, graduated fees, and appeals

(define-constant CONTRACT-OWNER tx-sender)

;; Emergency types
(define-constant EMERGENCY-MEDICAL u1)
(define-constant EMERGENCY-FAMILY u2)
(define-constant EMERGENCY-FINANCIAL u3)
(define-constant EMERGENCY-DISASTER u4)
(define-constant EMERGENCY-OTHER u5)

;; Emergency status
(define-constant STATUS-PENDING u0)
(define-constant STATUS-APPROVED u1)
(define-constant STATUS-REJECTED u2)
(define-constant STATUS-PAID u3)
(define-constant STATUS-APPEALED u4)       ;; NEW: Under appeal
(define-constant STATUS-APPEAL-APPROVED u5) ;; NEW: Appeal succeeded
(define-constant STATUS-APPEAL-REJECTED u6) ;; NEW: Appeal failed

;; Appeal reasons
(define-constant APPEAL-INSUFFICIENT-DOCS u1)
(define-constant APPEAL-WRONG-CATEGORY u2)
(define-constant APPEAL-AMOUNT-DISPUTE u3)
(define-constant APPEAL-OTHER u4)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u5000))
(define-constant ERR-NOT-MEMBER (err u5001))
(define-constant ERR-REQUEST-NOT-FOUND (err u5002))
(define-constant ERR-ALREADY-PROCESSED (err u5003))
(define-constant ERR-INVALID-AMOUNT (err u5004))
(define-constant ERR-CIRCLE-NOT-FOUND (err u5005))
(define-constant ERR-PAUSED (err u5006))
(define-constant ERR-COOLDOWN-ACTIVE (err u5007))
(define-constant ERR-LIMIT-EXCEEDED (err u5008))
(define-constant ERR-INSURANCE-DEPLETED (err u5009))
(define-constant ERR-APPEAL-EXPIRED (err u5010))
(define-constant ERR-ALREADY-APPEALED (err u5011))
(define-constant ERR-NOT-REJECTABLE (err u5012))

;; Parameters
(define-constant BASE-FEE-BPS u200)         ;; 2% base fee
(define-constant MIN-COOLDOWN-BLOCKS u1008) ;; ~7 days minimum between requests
(define-constant MAX-EMERGENCY-PERCENT u50) ;; Max 50% of circle funds
(define-constant APPEAL-WINDOW-BLOCKS u432) ;; ~3 days to appeal
(define-constant INSURANCE-CONTRIBUTION-BPS u50) ;; 0.5% to insurance pool

;; Emergency request counter
(define-data-var request-counter uint u0)

;; Insurance pool balance
(define-data-var insurance-pool-balance uint u0)

;; Emergency requests
(define-map emergency-requests
  uint
  {
    circle-id: uint,
    requester: principal,
    emergency-type: uint,
    description: (string-ascii 500),
    amount-requested: uint,
    amount-approved: uint,
    status: uint,
    created-at: uint,
    processed-at: uint,
    processor: (optional principal),
    evidence-hash: (buff 32),           ;; NEW: Hash of evidence docs
    use-insurance: bool,                ;; NEW: Request from insurance pool
    fee-paid: uint,
    appeal-deadline: uint,
    appeal-reason: (optional uint),
    appeal-notes: (optional (string-ascii 200))
  }
)

;; Circle emergency settings
(define-map circle-emergency-settings
  uint
  {
    enabled: bool,
    max-amount: uint,
    cooldown-blocks: uint,
    required-approvers: uint,
    insurance-contribution: uint        ;; Contribution to circle insurance
  }
)

;; Member emergency history
(define-map member-emergency-history
  { circle-id: uint, member: principal }
  {
    total-requests: uint,
    total-approved: uint,
    total-amount: uint,
    last-request-at: uint,
    last-approved-at: uint,
    trust-score: uint                   ;; NEW: Emergency trust score
  }
)

;; Circle insurance pool
(define-map circle-insurance
  uint
  {
    balance: uint,
    total-contributions: uint,
    total-payouts: uint,
    last-contribution-at: uint
  }
)

;; Request approvals tracking
(define-map request-approvals
  { request-id: uint, approver: principal }
  { approved: bool, approved-at: uint, notes: (string-ascii 200) }
)

;; Appeal arbitrators
(define-map appeal-arbitrators principal bool)

;; Graduated fee tiers (based on request frequency)
(define-map fee-tiers
  uint  ;; Number of requests in period
  uint  ;; Fee in basis points
)


;; ============================================
;; Initialization
;; ============================================

(map-set fee-tiers u1 u200)  ;; 2% for 1st request
(map-set fee-tiers u2 u300)  ;; 3% for 2nd request
(map-set fee-tiers u3 u500)  ;; 5% for 3rd request
(map-set fee-tiers u4 u750)  ;; 7.5% for 4th+ request

(define-public (add-arbitrator (arbitrator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set appeal-arbitrators arbitrator true))
  )
)

(define-public (remove-arbitrator (arbitrator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-delete appeal-arbitrators arbitrator))
  )
)


;; ============================================
;; Circle Settings
;; ============================================

(define-public (configure-circle-emergency 
    (circle-id uint)
    (enabled bool)
    (max-amount uint)
    (cooldown-blocks uint)
    (required-approvers uint)
    (insurance-contribution uint))
  (begin
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (contract-call? .stacksusu-admin-v6 is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (>= cooldown-blocks MIN-COOLDOWN-BLOCKS) ERR-INVALID-AMOUNT)
    
    (map-set circle-emergency-settings circle-id
      {
        enabled: enabled,
        max-amount: max-amount,
        cooldown-blocks: cooldown-blocks,
        required-approvers: required-approvers,
        insurance-contribution: insurance-contribution
      }
    )
    
    (ok true)
  )
)


;; ============================================
;; Insurance Pool (NEW in v6)
;; ============================================

(define-public (contribute-to-insurance (circle-id uint) (amount uint))
  (let
    (
      (current-insurance (default-to 
                           { balance: u0, total-contributions: u0, total-payouts: u0, last-contribution-at: u0 }
                           (map-get? circle-insurance circle-id)))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (contract-call? .stacksusu-core-v6 is-member circle-id tx-sender) ERR-NOT-MEMBER)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Transfer to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set circle-insurance circle-id
      {
        balance: (+ (get balance current-insurance) amount),
        total-contributions: (+ (get total-contributions current-insurance) amount),
        total-payouts: (get total-payouts current-insurance),
        last-contribution-at: block-height
      }
    )
    
    (ok true)
  )
)

(define-read-only (get-circle-insurance (circle-id uint))
  (map-get? circle-insurance circle-id)
)

(define-read-only (get-insurance-pool-balance)
  (var-get insurance-pool-balance)
)


;; ============================================
;; Emergency Requests
;; ============================================

(define-public (create-emergency-request
    (circle-id uint)
    (emergency-type uint)
    (description (string-ascii 500))
    (amount uint)
    (evidence-hash (buff 32))
    (use-insurance bool))
  (let
    (
      (requester tx-sender)
      (request-id (+ (var-get request-counter) u1))
      (settings (default-to 
                  { enabled: false, max-amount: u0, cooldown-blocks: MIN-COOLDOWN-BLOCKS, 
                    required-approvers: u1, insurance-contribution: u0 }
                  (map-get? circle-emergency-settings circle-id)))
      (history (default-to 
                 { total-requests: u0, total-approved: u0, total-amount: u0, 
                   last-request-at: u0, last-approved-at: u0, trust-score: u100 }
                 (map-get? member-emergency-history { circle-id: circle-id, member: requester })))
      (circle-info (unwrap! (contract-call? .stacksusu-core-v6 get-circle-info circle-id)
                            ERR-CIRCLE-NOT-FOUND))
      (circle (unwrap! circle-info ERR-CIRCLE-NOT-FOUND))
      (max-requestable (/ (* (get current-pot circle) MAX-EMERGENCY-PERCENT) u100))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (get enabled settings) ERR-NOT-AUTHORIZED)
    (asserts! (contract-call? .stacksusu-core-v6 is-member circle-id requester) ERR-NOT-MEMBER)
    (asserts! (and (>= emergency-type EMERGENCY-MEDICAL) (<= emergency-type EMERGENCY-OTHER)) 
              ERR-INVALID-AMOUNT)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount (get max-amount settings)) ERR-LIMIT-EXCEEDED)
    (asserts! (<= amount max-requestable) ERR-LIMIT-EXCEEDED)
    
    ;; Check cooldown
    (asserts! (or (is-eq (get last-request-at history) u0)
                  (>= block-height (+ (get last-request-at history) (get cooldown-blocks settings))))
              ERR-COOLDOWN-ACTIVE)
    
    ;; If using insurance, check balance
    (if use-insurance
      (let
        (
          (insurance (default-to { balance: u0, total-contributions: u0, total-payouts: u0, last-contribution-at: u0 }
                       (map-get? circle-insurance circle-id)))
        )
        (asserts! (>= (get balance insurance) amount) ERR-INSURANCE-DEPLETED)
        true
      )
      true
    )
    
    ;; Create request
    (map-set emergency-requests request-id
      {
        circle-id: circle-id,
        requester: requester,
        emergency-type: emergency-type,
        description: description,
        amount-requested: amount,
        amount-approved: u0,
        status: STATUS-PENDING,
        created-at: block-height,
        processed-at: u0,
        processor: none,
        evidence-hash: evidence-hash,
        use-insurance: use-insurance,
        fee-paid: u0,
        appeal-deadline: u0,
        appeal-reason: none,
        appeal-notes: none
      }
    )
    
    ;; Update history
    (map-set member-emergency-history { circle-id: circle-id, member: requester }
      (merge history {
        total-requests: (+ (get total-requests history) u1),
        last-request-at: block-height
      })
    )
    
    (var-set request-counter request-id)
    (ok request-id)
  )
)


;; ============================================
;; Approval System
;; ============================================

(define-public (approve-request (request-id uint) (approved-amount uint) (notes (string-ascii 200)))
  (let
    (
      (request (unwrap! (map-get? emergency-requests request-id) ERR-REQUEST-NOT-FOUND))
      (approver tx-sender)
      (settings (default-to 
                  { enabled: false, max-amount: u0, cooldown-blocks: MIN-COOLDOWN-BLOCKS, 
                    required-approvers: u1, insurance-contribution: u0 }
                  (map-get? circle-emergency-settings (get circle-id request))))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (is-eq (get status request) STATUS-PENDING) ERR-ALREADY-PROCESSED)
    (asserts! (contract-call? .stacksusu-admin-v6 is-admin approver) ERR-NOT-AUTHORIZED)
    (asserts! (<= approved-amount (get amount-requested request)) ERR-INVALID-AMOUNT)
    
    ;; Record approval
    (map-set request-approvals 
      { request-id: request-id, approver: approver }
      { approved: true, approved-at: block-height, notes: notes }
    )
    
    ;; For simplicity, single approval workflow (could extend to multi-sig)
    (map-set emergency-requests request-id
      (merge request {
        amount-approved: approved-amount,
        status: STATUS-APPROVED,
        processed-at: block-height,
        processor: (some approver),
        appeal-deadline: (+ block-height APPEAL-WINDOW-BLOCKS)
      })
    )
    
    (ok true)
  )
)

(define-public (reject-request (request-id uint) (notes (string-ascii 200)))
  (let
    (
      (request (unwrap! (map-get? emergency-requests request-id) ERR-REQUEST-NOT-FOUND))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (is-eq (get status request) STATUS-PENDING) ERR-ALREADY-PROCESSED)
    (asserts! (contract-call? .stacksusu-admin-v6 is-admin tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-set request-approvals 
      { request-id: request-id, approver: tx-sender }
      { approved: false, approved-at: block-height, notes: notes }
    )
    
    (map-set emergency-requests request-id
      (merge request {
        status: STATUS-REJECTED,
        processed-at: block-height,
        processor: (some tx-sender),
        appeal-deadline: (+ block-height APPEAL-WINDOW-BLOCKS)
      })
    )
    
    (ok true)
  )
)


;; ============================================
;; Disbursement with Graduated Fees
;; ============================================

(define-public (disburse-emergency (request-id uint))
  (let
    (
      (request (unwrap! (map-get? emergency-requests request-id) ERR-REQUEST-NOT-FOUND))
      (circle-id (get circle-id request))
      (requester (get requester request))
      (amount (get amount-approved request))
      (history (default-to 
                 { total-requests: u0, total-approved: u0, total-amount: u0, 
                   last-request-at: u0, last-approved-at: u0, trust-score: u100 }
                 (map-get? member-emergency-history { circle-id: circle-id, member: requester })))
      (fee-rate (calculate-fee-rate (get total-approved history)))
      (fee-amount (/ (* amount fee-rate) u10000))
      (insurance-fee (/ (* amount INSURANCE-CONTRIBUTION-BPS) u10000))
      (net-amount (- amount (+ fee-amount insurance-fee)))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (or (is-eq (get status request) STATUS-APPROVED)
                  (is-eq (get status request) STATUS-APPEAL-APPROVED))
              ERR-NOT-AUTHORIZED)
    
    (if (get use-insurance request)
      ;; Pay from insurance pool
      (let
        (
          (insurance (unwrap! (map-get? circle-insurance circle-id) ERR-INSURANCE-DEPLETED))
        )
        (try! (as-contract (stx-transfer? net-amount tx-sender requester)))
        
        (map-set circle-insurance circle-id
          (merge insurance {
            balance: (- (get balance insurance) amount),
            total-payouts: (+ (get total-payouts insurance) amount)
          })
        )
        true
      )
      ;; Pay from escrow
      true  ;; Would call escrow contract
    )
    
    ;; Add insurance contribution
    (var-set insurance-pool-balance (+ (var-get insurance-pool-balance) insurance-fee))
    
    ;; Update request
    (map-set emergency-requests request-id
      (merge request { status: STATUS-PAID, fee-paid: fee-amount })
    )
    
    ;; Update history
    (map-set member-emergency-history { circle-id: circle-id, member: requester }
      (merge history {
        total-approved: (+ (get total-approved history) u1),
        total-amount: (+ (get total-amount history) amount),
        last-approved-at: block-height
      })
    )
    
    ;; Update reputation
    (try! (contract-call? .stacksusu-reputation-v6 record-action requester u3))  ;; Emergency withdrawal
    
    (ok net-amount)
  )
)

(define-private (calculate-fee-rate (previous-approvals uint))
  (if (<= previous-approvals u0)
    (default-to u200 (map-get? fee-tiers u1))
    (if (<= previous-approvals u1)
      (default-to u300 (map-get? fee-tiers u2))
      (if (<= previous-approvals u2)
        (default-to u500 (map-get? fee-tiers u3))
        (default-to u750 (map-get? fee-tiers u4))
      )
    )
  )
)


;; ============================================
;; Appeal System (NEW in v6)
;; ============================================

(define-public (appeal-decision 
    (request-id uint) 
    (appeal-reason uint) 
    (notes (string-ascii 200)))
  (let
    (
      (request (unwrap! (map-get? emergency-requests request-id) ERR-REQUEST-NOT-FOUND))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (is-eq tx-sender (get requester request)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request) STATUS-REJECTED) ERR-NOT-REJECTABLE)
    (asserts! (< block-height (get appeal-deadline request)) ERR-APPEAL-EXPIRED)
    (asserts! (is-none (get appeal-reason request)) ERR-ALREADY-APPEALED)
    (asserts! (and (>= appeal-reason APPEAL-INSUFFICIENT-DOCS) 
                   (<= appeal-reason APPEAL-OTHER))
              ERR-INVALID-AMOUNT)
    
    (map-set emergency-requests request-id
      (merge request {
        status: STATUS-APPEALED,
        appeal-reason: (some appeal-reason),
        appeal-notes: (some notes)
      })
    )
    
    (ok true)
  )
)

(define-public (resolve-appeal (request-id uint) (approve bool) (new-amount uint))
  (let
    (
      (request (unwrap! (map-get? emergency-requests request-id) ERR-REQUEST-NOT-FOUND))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (is-eq (get status request) STATUS-APPEALED) ERR-REQUEST-NOT-FOUND)
    (asserts! (default-to false (map-get? appeal-arbitrators tx-sender)) ERR-NOT-AUTHORIZED)
    
    (if approve
      (begin
        (map-set emergency-requests request-id
          (merge request {
            status: STATUS-APPEAL-APPROVED,
            amount-approved: (if (> new-amount u0) new-amount (get amount-requested request)),
            processed-at: block-height,
            processor: (some tx-sender)
          })
        )
        ;; Increase trust score for valid appeal
        (update-trust-score (get circle-id request) (get requester request) 5)
      )
      (begin
        (map-set emergency-requests request-id
          (merge request {
            status: STATUS-APPEAL-REJECTED,
            processed-at: block-height,
            processor: (some tx-sender)
          })
        )
        ;; Decrease trust score for rejected appeal
        (update-trust-score (get circle-id request) (get requester request) (- 0 10))
      )
    )
    
    (ok true)
  )
)

(define-private (update-trust-score (circle-id uint) (member principal) (delta int))
  (let
    (
      (history (default-to 
                 { total-requests: u0, total-approved: u0, total-amount: u0, 
                   last-request-at: u0, last-approved-at: u0, trust-score: u100 }
                 (map-get? member-emergency-history { circle-id: circle-id, member: member })))
      (current-score (get trust-score history))
      (new-score (if (< delta 0)
                   (if (> current-score (to-uint (* delta (- 1))))
                     (- current-score (to-uint (* delta (- 1))))
                     u0)
                   (+ current-score (to-uint delta))))
    )
    (map-set member-emergency-history { circle-id: circle-id, member: member }
      (merge history { trust-score: (if (> new-score u200) u200 new-score) })
    )
  )
)


;; ============================================
;; Read-Only Functions
;; ============================================

(define-read-only (get-emergency-request (request-id uint))
  (ok (map-get? emergency-requests request-id))
)

(define-read-only (get-circle-settings (circle-id uint))
  (map-get? circle-emergency-settings circle-id)
)

(define-read-only (get-member-history (circle-id uint) (member principal))
  (map-get? member-emergency-history { circle-id: circle-id, member: member })
)

(define-read-only (get-request-count)
  (var-get request-counter)
)

(define-read-only (get-fee-for-member (circle-id uint) (member principal))
  (let
    (
      (history (default-to 
                 { total-requests: u0, total-approved: u0, total-amount: u0, 
                   last-request-at: u0, last-approved-at: u0, trust-score: u100 }
                 (map-get? member-emergency-history { circle-id: circle-id, member: member })))
    )
    (calculate-fee-rate (get total-approved history))
  )
)

(define-read-only (can-request-emergency (circle-id uint) (member principal))
  (let
    (
      (settings (default-to 
                  { enabled: false, max-amount: u0, cooldown-blocks: MIN-COOLDOWN-BLOCKS, 
                    required-approvers: u1, insurance-contribution: u0 }
                  (map-get? circle-emergency-settings circle-id)))
      (history (default-to 
                 { total-requests: u0, total-approved: u0, total-amount: u0, 
                   last-request-at: u0, last-approved-at: u0, trust-score: u100 }
                 (map-get? member-emergency-history { circle-id: circle-id, member: member })))
    )
    (and 
      (get enabled settings)
      (contract-call? .stacksusu-core-v6 is-member circle-id member)
      (or (is-eq (get last-request-at history) u0)
          (>= block-height (+ (get last-request-at history) (get cooldown-blocks settings))))
    )
  )
)

(define-read-only (get-appeal-info (request-id uint))
  (match (map-get? emergency-requests request-id)
    request
      (ok {
        status: (get status request),
        appeal-reason: (get appeal-reason request),
        appeal-notes: (get appeal-notes request),
        appeal-deadline: (get appeal-deadline request),
        can-appeal: (and (is-eq (get status request) STATUS-REJECTED)
                         (< block-height (get appeal-deadline request))
                         (is-none (get appeal-reason request)))
      })
    ERR-REQUEST-NOT-FOUND
  )
)

(define-read-only (is-arbitrator (address principal))
  (default-to false (map-get? appeal-arbitrators address))
)
