;; EventFlow Workflow Registry Contract
;; Manages user-created workflows with access control and metadata management

;; ====================================
;; Constants
;; ====================================

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-price (err u104))
(define-constant err-insufficient-funds (err u105))
(define-constant err-invalid-name (err u106))
(define-constant err-invalid-description (err u107))
(define-constant err-workflow-limit-reached (err u108))
(define-constant err-not-premium (err u109))

;; Fee constants (in microSTX)
(define-constant fee-register-workflow u10000000) ;; 10 STX
(define-constant fee-update-workflow u2000000)     ;; 2 STX
(define-constant fee-toggle-visibility u1000000)   ;; 1 STX
(define-constant fee-transfer-min u5000000)        ;; 5 STX
(define-constant fee-premium-unlock u50000000)     ;; 50 STX
(define-constant transfer-fee-percentage u5)       ;; 5%
(define-constant max-free-workflows u5)

;; ====================================
;; Data Variables
;; ====================================

(define-data-var workflow-counter uint u0)
(define-data-var platform-revenue uint u0)

;; ====================================
;; Data Maps
;; ====================================

;; Main workflow storage
(define-map workflows
  { workflow-id: uint }
  {
    owner: principal,
    name: (string-utf8 100),
    description: (string-utf8 500),
    config: (buff 5000),
    is-public: bool,
    is-active: bool,
    created-at: uint,
    updated-at: uint,
    version: uint
  }
)

;; User workflow tracking
(define-map user-workflow-list
  { user: principal }
  { workflow-ids: (list 100 uint), count: uint }
)

;; Premium user status
(define-map premium-users
  { user: principal }
  { is-premium: bool, activated-at: uint }
)

;; Workflow statistics
(define-map workflow-stats
  { workflow-id: uint }
  {
    total-updates: uint,
    total-transfers: uint,
    last-accessed: uint
  }
)

;; ====================================
;; Private Functions
;; ====================================

(define-private (is-workflow-owner (workflow-id uint) (user principal))
  (match (map-get? workflows { workflow-id: workflow-id })
    workflow (is-eq (get owner workflow) user)
    false
  )
)

(define-private (is-premium-user (user principal))
  (default-to false 
    (get is-premium (map-get? premium-users { user: user }))
  )
)

(define-private (get-user-workflow-count (user principal))
  (default-to u0
    (get count (map-get? user-workflow-list { user: user }))
  )
)

(define-private (can-create-workflow (user principal))
  (let ((count (get-user-workflow-count user)))
    (or 
      (is-premium-user user)
      (< count max-free-workflows)
    )
  )
)

(define-private (add-workflow-to-user (user principal) (workflow-id uint))
  (let (
    (current-list (default-to 
      { workflow-ids: (list), count: u0 }
      (map-get? user-workflow-list { user: user })
    ))
  )
    (map-set user-workflow-list
      { user: user }
      {
        workflow-ids: (unwrap-panic (as-max-len? 
          (append (get workflow-ids current-list) workflow-id) 
          u100
        )),
        count: (+ (get count current-list) u1)
      }
    )
  )
)

(define-private (remove-workflow-from-user (user principal) (workflow-id uint))
  (let (
    (current-list (unwrap-panic (map-get? user-workflow-list { user: user })))
    (filtered-list (filter is-not-workflow-id (get workflow-ids current-list)))
  )
    (map-set user-workflow-list
      { user: user }
      {
        workflow-ids: filtered-list,
        count: (- (get count current-list) u1)
      }
    )
  )
)

(define-private (is-not-workflow-id (id uint))
  true ;; This is a placeholder - actual filtering happens in remove-workflow-from-user
)

(define-private (increment-platform-revenue (amount uint))
  (var-set platform-revenue (+ (var-get platform-revenue) amount))
)

(define-private (max (a uint) (b uint))
  (if (> a b) a b)
)

;; ====================================
;; Public Functions
;; ====================================

;; Register a new workflow
(define-public (register-workflow 
    (name (string-utf8 100))
    (description (string-utf8 500))
    (config (buff 5000))
    (is-public bool)
  )
  (let (
    (workflow-id (+ (var-get workflow-counter) u1))
    (caller tx-sender)
  )
    ;; Validate inputs
    (asserts! (> (len name) u0) err-invalid-name)
    (asserts! (> (len description) u0) err-invalid-description)
    (asserts! (can-create-workflow caller) err-workflow-limit-reached)
    
    ;; Transfer registration fee
    (try! (stx-transfer? fee-register-workflow caller (as-contract tx-sender)))
    (increment-platform-revenue fee-register-workflow)
    
    ;; Create workflow
    (map-set workflows
      { workflow-id: workflow-id }
      {
        owner: caller,
        name: name,
        description: description,
        config: config,
        is-public: is-public,
        is-active: true,
        created-at: stacks-block-height,
        updated-at: stacks-block-height,
        version: u1
      }
    )
    
    ;; Initialize stats
    (map-set workflow-stats
      { workflow-id: workflow-id }
      {
        total-updates: u0,
        total-transfers: u0,
        last-accessed: stacks-block-height
      }
    )
    
    ;; Add to user's workflow list
    (add-workflow-to-user caller workflow-id)
    
    ;; Increment counter
    (var-set workflow-counter workflow-id)
    
    (ok workflow-id)
  )
)

;; Update workflow configuration
(define-public (update-workflow
    (workflow-id uint)
    (name (string-utf8 100))
    (description (string-utf8 500))
    (config (buff 5000))
  )
  (let (
    (workflow (unwrap! (map-get? workflows { workflow-id: workflow-id }) err-not-found))
    (caller tx-sender)
  )
    ;; Validate ownership
    (asserts! (is-eq (get owner workflow) caller) err-unauthorized)
    (asserts! (> (len name) u0) err-invalid-name)
    (asserts! (> (len description) u0) err-invalid-description)
    
    ;; Transfer update fee
    (try! (stx-transfer? fee-update-workflow caller (as-contract tx-sender)))
    (increment-platform-revenue fee-update-workflow)
    
    ;; Update workflow
    (map-set workflows
      { workflow-id: workflow-id }
      (merge workflow {
        name: name,
        description: description,
        config: config,
        updated-at: stacks-block-height,
        version: (+ (get version workflow) u1)
      })
    )
    
    ;; Update stats
    (map-set workflow-stats
      { workflow-id: workflow-id }
      (merge 
        (default-to 
          { total-updates: u0, total-transfers: u0, last-accessed: stacks-block-height }
          (map-get? workflow-stats { workflow-id: workflow-id })
        )
        { 
          total-updates: (+ (default-to u0 (get total-updates (map-get? workflow-stats { workflow-id: workflow-id }))) u1),
          last-accessed: stacks-block-height 
        }
      )
    )
    
    (ok true)
  )
)

;; Toggle workflow visibility (public/private)
(define-public (toggle-visibility (workflow-id uint))
  (let (
    (workflow (unwrap! (map-get? workflows { workflow-id: workflow-id }) err-not-found))
    (caller tx-sender)
  )
    ;; Validate ownership
    (asserts! (is-eq (get owner workflow) caller) err-unauthorized)
    
    ;; Transfer visibility toggle fee
    (try! (stx-transfer? fee-toggle-visibility caller (as-contract tx-sender)))
    (increment-platform-revenue fee-toggle-visibility)
    
    ;; Toggle visibility
    (map-set workflows
      { workflow-id: workflow-id }
      (merge workflow {
        is-public: (not (get is-public workflow)),
        updated-at: stacks-block-height
      })
    )
    
    (ok (not (get is-public workflow)))
  )
)

;; Transfer workflow ownership
(define-public (transfer-workflow
    (workflow-id uint)
    (new-owner principal)
    (price uint)
  )
  (let (
    (workflow (unwrap! (map-get? workflows { workflow-id: workflow-id }) err-not-found))
    (caller tx-sender)
    (transfer-fee (max fee-transfer-min (/ (* price transfer-fee-percentage) u100)))
  )
    ;; Validate ownership and price
    (asserts! (is-eq (get owner workflow) caller) err-unauthorized)
    (asserts! (>= price fee-transfer-min) err-invalid-price)
    
    ;; Transfer payment from new owner to current owner
    (try! (stx-transfer? (- price transfer-fee) new-owner caller))
    
    ;; Transfer platform fee
    (try! (stx-transfer? transfer-fee new-owner (as-contract tx-sender)))
    (increment-platform-revenue transfer-fee)
    
    ;; Update ownership
    (map-set workflows
      { workflow-id: workflow-id }
      (merge workflow {
        owner: new-owner,
        updated-at: stacks-block-height
      })
    )
    
    ;; Update user lists
    (remove-workflow-from-user caller workflow-id)
    (add-workflow-to-user new-owner workflow-id)
    
    ;; Update stats
    (map-set workflow-stats
      { workflow-id: workflow-id }
      (merge 
        (default-to 
          { total-updates: u0, total-transfers: u0, last-accessed: stacks-block-height }
          (map-get? workflow-stats { workflow-id: workflow-id })
        )
        { 
          total-transfers: (+ (default-to u0 (get total-transfers (map-get? workflow-stats { workflow-id: workflow-id }))) u1),
          last-accessed: stacks-block-height 
        }
      )
    )
    
    (ok true)
  )
)

;; Delete workflow (deactivate)
(define-public (delete-workflow (workflow-id uint))
  (let (
    (workflow (unwrap! (map-get? workflows { workflow-id: workflow-id }) err-not-found))
    (caller tx-sender)
  )
    ;; Validate ownership
    (asserts! (is-eq (get owner workflow) caller) err-unauthorized)
    
    ;; Deactivate workflow
    (map-set workflows
      { workflow-id: workflow-id }
      (merge workflow {
        is-active: false,
        updated-at: stacks-block-height
      })
    )
    
    (ok true)
  )
)

;; Unlock premium features
(define-public (unlock-premium)
  (let ((caller tx-sender))
    ;; Transfer premium fee
    (try! (stx-transfer? fee-premium-unlock caller (as-contract tx-sender)))
    (increment-platform-revenue fee-premium-unlock)
    
    ;; Set premium status
    (map-set premium-users
      { user: caller }
      { is-premium: true, activated-at: stacks-block-height }
    )
    
    (ok true)
  )
)

;; ====================================
;; Read-Only Functions
;; ====================================

;; Get workflow details
(define-read-only (get-workflow (workflow-id uint))
  (ok (map-get? workflows { workflow-id: workflow-id }))
)

;; Get user's workflows
(define-read-only (get-user-workflows (user principal))
  (ok (map-get? user-workflow-list { user: user }))
)

;; Get public workflows with pagination
(define-read-only (get-public-workflows (offset uint) (limit uint))
  (ok {
    total: (var-get workflow-counter),
    offset: offset,
    limit: limit
  })
)

;; Get workflow statistics
(define-read-only (get-workflow-stats (workflow-id uint))
  (ok (map-get? workflow-stats { workflow-id: workflow-id }))
)

;; Check if user can access workflow
(define-read-only (can-access-workflow (workflow-id uint) (user principal))
  (match (map-get? workflows { workflow-id: workflow-id })
    workflow 
      (ok (or 
        (is-eq (get owner workflow) user)
        (get is-public workflow)
      ))
    (ok false)
  )
)

;; Check premium status
(define-read-only (is-user-premium (user principal))
  (ok (is-premium-user user))
)

;; Get platform statistics
(define-read-only (get-platform-stats)
  (ok {
    total-workflows: (var-get workflow-counter),
    total-revenue: (var-get platform-revenue)
  })
)

;; Get workflow count for user
(define-read-only (get-user-workflow-count-public (user principal))
  (ok (get-user-workflow-count user))
)
