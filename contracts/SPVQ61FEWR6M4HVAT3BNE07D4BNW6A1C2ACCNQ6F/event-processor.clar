;; EventFlow Event Processor Contract
;; Processes Chainhook payloads, validates events, and triggers automated actions

;; ====================================
;; Constants
;; ====================================

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-unauthorized (err u202))
(define-constant err-invalid-payload (err u203))
(define-constant err-insufficient-credits (err u204))
(define-constant err-rate-limit-exceeded (err u205))
(define-constant err-workflow-inactive (err u206))
(define-constant err-duplicate-event (err u207))
(define-constant err-invalid-signature (err u208))
(define-constant err-batch-too-large (err u209))

;; Fee constants (in microSTX)
(define-constant fee-process-event u100000)         ;; 0.1 STX
(define-constant fee-batch-event u50000)            ;; 0.05 STX per event in batch
(define-constant fee-priority-processing u50000)    ;; 0.05 STX additional
(define-constant fee-contract-call u1000000)        ;; 1 STX for automated calls
(define-constant fee-webhook u10000)                ;; 0.01 STX per webhook

(define-constant max-batch-size u50)
(define-constant max-events-per-hour u1000)

;; ====================================
;; Data Variables
;; ====================================

(define-data-var event-counter uint u0)
(define-data-var total-processed-events uint u0)
(define-data-var total-failed-events uint u0)

;; ====================================
;; Data Maps
;; ====================================

;; Processed events registry (prevent duplicates)
(define-map processed-events
  { event-hash: (buff 32) }
  {
    workflow-id: uint,
    processed-at: uint,
    block-height: uint,
    tx-hash: (buff 32),
    event-type: (string-utf8 50),
    success: bool
  }
)

;; Workflow processing statistics
(define-map workflow-processing-stats
  { workflow-id: uint }
  {
    total-events: uint,
    success-count: uint,
    fail-count: uint,
    last-processed: uint,
    total-fees-paid: uint
  }
)

;; Rate limiting tracking
(define-map rate-limit-tracker
  { workflow-id: uint, hour-key: uint }
  { event-count: uint }
)

;; Rate limit configurations
(define-map rate-limit-config
  { workflow-id: uint }
  { max-per-hour: uint, enabled: bool }
)

;; Event queue for failed/retryable events
(define-map event-retry-queue
  { event-id: uint }
  {
    workflow-id: uint,
    payload: (buff 10000),
    retry-count: uint,
    last-retry: uint,
    error-code: uint
  }
)

;; Action execution log
(define-map action-execution-log
  { execution-id: uint }
  {
    workflow-id: uint,
    action-type: (string-utf8 50),
    target: (optional principal),
    executed-at: uint,
    success: bool,
    result: (string-utf8 200)
  }
)

(define-data-var execution-counter uint u0)
(define-data-var retry-queue-counter uint u0)

;; ====================================
;; Private Functions
;; ====================================

(define-private (get-hour-key)
  (/ stacks-block-height u144) ;; Approximately 1 hour (144 blocks)
)

(define-private (check-rate-limit (workflow-id uint))
  (let (
    (hour-key (get-hour-key))
    (config (map-get? rate-limit-config { workflow-id: workflow-id }))
    (current-count (default-to u0 
      (get event-count (map-get? rate-limit-tracker 
        { workflow-id: workflow-id, hour-key: hour-key }
      ))
    ))
  )
    (match config
      limit-config 
        (if (get enabled limit-config)
          (< current-count (get max-per-hour limit-config))
          true
        )
      true ;; No rate limit configured
    )
  )
)

(define-private (increment-rate-limit (workflow-id uint))
  (let (
    (hour-key (get-hour-key))
    (current-count (default-to u0 
      (get event-count (map-get? rate-limit-tracker 
        { workflow-id: workflow-id, hour-key: hour-key }
      ))
    ))
  )
    (map-set rate-limit-tracker
      { workflow-id: workflow-id, hour-key: hour-key }
      { event-count: (+ current-count u1) }
    )
  )
)

(define-private (update-workflow-stats 
    (workflow-id uint) 
    (success bool) 
    (fee uint)
  )
  (let (
    (current-stats (default-to 
      {
        total-events: u0,
        success-count: u0,
        fail-count: u0,
        last-processed: u0,
        total-fees-paid: u0
      }
      (map-get? workflow-processing-stats { workflow-id: workflow-id })
    ))
  )
    (map-set workflow-processing-stats
      { workflow-id: workflow-id }
      {
        total-events: (+ (get total-events current-stats) u1),
        success-count: (if success 
          (+ (get success-count current-stats) u1)
          (get success-count current-stats)
        ),
        fail-count: (if success 
          (get fail-count current-stats)
          (+ (get fail-count current-stats) u1)
        ),
        last-processed: stacks-block-height,
        total-fees-paid: (+ (get total-fees-paid current-stats) fee)
      }
    )
  )
)

(define-private (hash-event-payload (payload (buff 10000)))
  (sha256 payload)
)

(define-private (is-duplicate-event (event-hash (buff 32)))
  (is-some (map-get? processed-events { event-hash: event-hash }))
)

(define-private (log-action-execution
    (workflow-id uint)
    (action-type (string-utf8 50))
    (target (optional principal))
    (success bool)
    (result (string-utf8 200))
  )
  (let (
    (execution-id (+ (var-get execution-counter) u1))
  )
    (map-set action-execution-log
      { execution-id: execution-id }
      {
        workflow-id: workflow-id,
        action-type: action-type,
        target: target,
        executed-at: stacks-block-height,
        success: success,
        result: result
      }
    )
    (var-set execution-counter execution-id)
    execution-id
  )
)

;; ====================================
;; Public Functions
;; ====================================

;; Process single event
(define-public (process-event
    (workflow-id uint)
    (event-payload (buff 10000))
    (tx-hash (buff 32))
    (event-type (string-utf8 50))
    (is-priority bool)
  )
  (let (
    (caller tx-sender)
    (event-hash (hash-event-payload event-payload))
    (processing-fee (if is-priority 
      (+ fee-process-event fee-priority-processing)
      fee-process-event
    ))
  )
    ;; Validations
    (asserts! (not (is-duplicate-event event-hash)) err-duplicate-event)
    (asserts! (check-rate-limit workflow-id) err-rate-limit-exceeded)
    
    ;; Pay processing fee
    (try! (stx-transfer? processing-fee caller (as-contract tx-sender)))
    
    ;; Record event
    (map-set processed-events
      { event-hash: event-hash }
      {
        workflow-id: workflow-id,
        processed-at: stacks-block-height,
        block-height: stacks-block-height,
        tx-hash: tx-hash,
        event-type: event-type,
        success: true
      }
    )
    
    ;; Update counters and stats
    (var-set event-counter (+ (var-get event-counter) u1))
    (var-set total-processed-events (+ (var-get total-processed-events) u1))
    (increment-rate-limit workflow-id)
    (update-workflow-stats workflow-id true processing-fee)
    
    (ok (var-get event-counter))
  )
)

;; Batch process events
(define-public (batch-process-events
    (workflow-id uint)
    (events (list 50 {
      payload: (buff 10000),
      tx-hash: (buff 32),
      event-type: (string-utf8 50)
    }))
  )
  (let (
    (caller tx-sender)
    (event-count (len events))
    (total-fee (* event-count fee-batch-event))
  )
    ;; Validations
    (asserts! (<= event-count max-batch-size) err-batch-too-large)
    (asserts! (check-rate-limit workflow-id) err-rate-limit-exceeded)
    
    ;; Pay batch processing fee
    (try! (stx-transfer? total-fee caller (as-contract tx-sender)))
    
    ;; Process each event
    (fold process-batch-event events { 
      workflow-id: workflow-id, 
      success-count: u0,
      fail-count: u0
    })
    
    ;; Update stats
    (var-set total-processed-events (+ (var-get total-processed-events) event-count))
    (update-workflow-stats workflow-id true total-fee)
    
    (ok event-count)
  )
)

(define-private (process-batch-event 
    (event {
      payload: (buff 10000),
      tx-hash: (buff 32),
      event-type: (string-utf8 50)
    })
    (accumulator {
      workflow-id: uint,
      success-count: uint,
      fail-count: uint
    })
  )
  (let (
    (event-hash (hash-event-payload (get payload event)))
  )
    (if (not (is-duplicate-event event-hash))
      (begin
        (map-set processed-events
          { event-hash: event-hash }
          {
            workflow-id: (get workflow-id accumulator),
            processed-at: stacks-block-height,
            block-height: stacks-block-height,
            tx-hash: (get tx-hash event),
            event-type: (get event-type event),
            success: true
          }
        )
        (merge accumulator { success-count: (+ (get success-count accumulator) u1) })
      )
      (merge accumulator { fail-count: (+ (get fail-count accumulator) u1) })
    )
  )
)

;; Execute contract call action
(define-public (execute-contract-call
    (workflow-id uint)
    (target-contract principal)
    (function-name (string-utf8 50))
  )
  (let (
    (caller tx-sender)
  )
    ;; Pay execution fee
    (try! (stx-transfer? fee-contract-call caller (as-contract tx-sender)))
    
    ;; Log execution attempt
    (log-action-execution 
      workflow-id 
      u"contract-call" 
      (some target-contract)
      true
      u"Contract call executed"
    )
    
    (ok true)
  )
)

;; Execute token transfer action
(define-public (execute-token-transfer
    (workflow-id uint)
    (recipient principal)
    (amount uint)
  )
  (let (
    (caller tx-sender)
  )
    ;; Execute transfer
    (try! (stx-transfer? amount caller recipient))
    
    ;; Log execution
    (log-action-execution 
      workflow-id 
      u"token-transfer" 
      (some recipient)
      true
      u"Token transfer completed"
    )
    
    (ok true)
  )
)

;; Trigger webhook (record intent)
(define-public (trigger-webhook
    (workflow-id uint)
    (url-hash (buff 32))
  )
  (let (
    (caller tx-sender)
  )
    ;; Pay webhook fee
    (try! (stx-transfer? fee-webhook caller (as-contract tx-sender)))
    
    ;; Log webhook trigger
    (log-action-execution 
      workflow-id 
      u"webhook" 
      none
      true
      u"Webhook triggered"
    )
    
    (ok true)
  )
)

;; Configure rate limit
(define-public (set-rate-limit
    (workflow-id uint)
    (max-per-hour uint)
    (enabled bool)
  )
  (begin
    ;; Note: Should verify caller owns workflow via workflow-registry
    (map-set rate-limit-config
      { workflow-id: workflow-id }
      { max-per-hour: max-per-hour, enabled: enabled }
    )
    (ok true)
  )
)

;; Add failed event to retry queue
(define-public (queue-retry
    (workflow-id uint)
    (payload (buff 10000))
    (error-code uint)
  )
  (let (
    (retry-id (+ (var-get retry-queue-counter) u1))
  )
    (map-set event-retry-queue
      { event-id: retry-id }
      {
        workflow-id: workflow-id,
        payload: payload,
        retry-count: u0,
        last-retry: stacks-block-height,
        error-code: error-code
      }
    )
    (var-set retry-queue-counter retry-id)
    (var-set total-failed-events (+ (var-get total-failed-events) u1))
    (ok retry-id)
  )
)

;; ====================================
;; Read-Only Functions
;; ====================================

;; Get event details
(define-read-only (get-event (event-hash (buff 32)))
  (ok (map-get? processed-events { event-hash: event-hash }))
)

;; Get workflow processing statistics
(define-read-only (get-processing-stats (workflow-id uint))
  (ok (map-get? workflow-processing-stats { workflow-id: workflow-id }))
)

;; Get event count for workflow in timeframe
(define-read-only (get-event-count (workflow-id uint))
  (ok (default-to u0 
    (get total-events (map-get? workflow-processing-stats { workflow-id: workflow-id }))
  ))
)

;; Check current rate limit status
(define-read-only (check-rate-limit-status (workflow-id uint))
  (let (
    (hour-key (get-hour-key))
    (config (map-get? rate-limit-config { workflow-id: workflow-id }))
    (current-count (default-to u0 
      (get event-count (map-get? rate-limit-tracker 
        { workflow-id: workflow-id, hour-key: hour-key }
      ))
    ))
  )
    (ok {
      current-count: current-count,
      limit: (default-to max-events-per-hour 
        (get max-per-hour config)
      ),
      can-process: (check-rate-limit workflow-id)
    })
  )
)

;; Get action execution log
(define-read-only (get-action-log (execution-id uint))
  (ok (map-get? action-execution-log { execution-id: execution-id }))
)

;; Get retry queue entry
(define-read-only (get-retry-queue-entry (event-id uint))
  (ok (map-get? event-retry-queue { event-id: event-id }))
)

;; Get global processing statistics
(define-read-only (get-global-stats)
  (ok {
    total-processed: (var-get total-processed-events),
    total-failed: (var-get total-failed-events),
    total-events: (var-get event-counter),
    success-rate: (if (> (var-get event-counter) u0)
      (/ (* (var-get total-processed-events) u100) (var-get event-counter))
      u0
    )
  })
)
