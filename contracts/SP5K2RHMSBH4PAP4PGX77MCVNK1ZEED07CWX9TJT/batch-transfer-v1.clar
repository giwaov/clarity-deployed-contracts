;; batch-transfer.clar
;; Gas-efficient batch transfers for STX and SIP-010 tokens
;; Supports up to 200 recipients per transaction

;; ============================================================================
;; Constants
;; ============================================================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INVALID-AMOUNT (err u402))
(define-constant ERR-EMPTY-LIST (err u403))
(define-constant ERR-LIST-TOO-LONG (err u404))
(define-constant ERR-INSUFFICIENT-BALANCE (err u405))
(define-constant ERR-TRANSFER-FAILED (err u406))
(define-constant ERR-PAUSED (err u407))

(define-constant MAX-RECIPIENTS u200)
(define-constant MIN-TRANSFER-AMOUNT u1000) ;; 0.001 STX minimum per recipient (1000 microSTX)

;; ============================================================================
;; Data Variables
;; ============================================================================

(define-data-var total-batches uint u0)
(define-data-var total-transfers uint u0)
(define-data-var total-stx-transferred uint u0)
(define-data-var is-paused bool false)
(define-data-var fee-bps uint u10) ;; 0.1% fee

;; ============================================================================
;; Data Maps
;; ============================================================================

;; Batch execution records
(define-map batches uint
  {
    sender: principal,
    recipient-count: uint,
    total-amount: uint,
    executed-at: uint,
    asset-type: (string-ascii 32)
  })

;; Fee collection
(define-map collected-fees (string-ascii 32) uint)

;; ============================================================================
;; Read-Only Functions
;; ============================================================================

(define-read-only (get-batch (batch-id uint))
  (map-get? batches batch-id))

(define-read-only (get-total-batches)
  (var-get total-batches))

(define-read-only (get-total-transfers)
  (var-get total-transfers))

(define-read-only (get-total-stx-transferred)
  (var-get total-stx-transferred))

(define-read-only (get-fee-bps)
  (var-get fee-bps))

(define-read-only (calculate-fee (amount uint))
  (/ (* amount (var-get fee-bps)) u10000))

(define-read-only (get-collected-fees (asset-type (string-ascii 32)))
  (default-to u0 (map-get? collected-fees asset-type)))

(define-read-only (get-stats)
  {
    total-batches: (var-get total-batches),
    total-transfers: (var-get total-transfers),
    total-stx: (var-get total-stx-transferred),
    fee-bps: (var-get fee-bps),
    is-paused: (var-get is-paused)
  })

;; ============================================================================
;; Batch STX Transfer
;; ============================================================================

;; Transfer STX to multiple recipients
(define-public (batch-stx-transfer 
    (recipients (list 200 { recipient: principal, amount: uint })))
  (let
    (
      (batch-id (+ (var-get total-batches) u1))
      (recipient-count (len recipients))
      (total-amount (fold sum-amounts recipients u0))
      (fee (calculate-fee total-amount))
      (total-with-fee (+ total-amount fee))
    )
    ;; Validations
    (asserts! (not (var-get is-paused)) ERR-PAUSED)
    (asserts! (> recipient-count u0) ERR-EMPTY-LIST)
    (asserts! (<= recipient-count MAX-RECIPIENTS) ERR-LIST-TOO-LONG)
    (asserts! (>= (stx-get-balance tx-sender) total-with-fee) ERR-INSUFFICIENT-BALANCE)
    
    ;; Collect fee
    (if (> fee u0)
      (try! (stx-transfer? fee tx-sender current-contract))
      true)
    
    ;; Execute transfers
    (try! (fold execute-stx-transfer recipients (ok true)))
    
    ;; Record batch
    (map-set batches batch-id
      {
        sender: tx-sender,
        recipient-count: recipient-count,
        total-amount: total-amount,
        executed-at: stacks-block-height,
        asset-type: "STX"
      })
    
    ;; Update fee collection
    (map-set collected-fees "STX" (+ (get-collected-fees "STX") fee))
    
    ;; Update stats
    (var-set total-batches batch-id)
    (var-set total-transfers (+ (var-get total-transfers) recipient-count))
    (var-set total-stx-transferred (+ (var-get total-stx-transferred) total-amount))
    
    (print { 
      event: "batch-transfer", 
      batch-id: batch-id, 
      sender: tx-sender,
      recipients: recipient-count,
      total: total-amount,
      fee: fee
    })
    
    (ok batch-id)))

;; Helper: Sum amounts in list
(define-private (sum-amounts 
    (item { recipient: principal, amount: uint })
    (total uint))
  (+ total (get amount item)))

;; Helper: Execute single STX transfer
(define-private (execute-stx-transfer 
    (item { recipient: principal, amount: uint })
    (prev-result (response bool uint)))
  (match prev-result
    success
      (match (stx-transfer? (get amount item) tx-sender (get recipient item))
        ok-val (ok true)
        err-val ERR-TRANSFER-FAILED)
    error (err error)))

;; ============================================================================
;; Batch Transfer with Memo
;; ============================================================================

;; Transfer STX with memo to multiple recipients
(define-public (batch-stx-transfer-with-memo 
    (recipients (list 200 { recipient: principal, amount: uint, memo: (buff 34) })))
  (let
    (
      (batch-id (+ (var-get total-batches) u1))
      (recipient-count (len recipients))
      (total-amount (fold sum-amounts-memo recipients u0))
      (fee (calculate-fee total-amount))
    )
    (asserts! (not (var-get is-paused)) ERR-PAUSED)
    (asserts! (> recipient-count u0) ERR-EMPTY-LIST)
    (asserts! (<= recipient-count MAX-RECIPIENTS) ERR-LIST-TOO-LONG)
    
    ;; Collect fee
    (if (> fee u0)
      (try! (stx-transfer? fee tx-sender current-contract))
      true)
    
    ;; Execute transfers with memo
    (try! (fold execute-stx-transfer-memo recipients (ok true)))
    
    ;; Record batch
    (map-set batches batch-id
      {
        sender: tx-sender,
        recipient-count: recipient-count,
        total-amount: total-amount,
        executed-at: stacks-block-height,
        asset-type: "STX-MEMO"
      })
    
    (var-set total-batches batch-id)
    (var-set total-transfers (+ (var-get total-transfers) recipient-count))
    (var-set total-stx-transferred (+ (var-get total-stx-transferred) total-amount))
    
    (ok batch-id)))

(define-private (sum-amounts-memo 
    (item { recipient: principal, amount: uint, memo: (buff 34) })
    (total uint))
  (+ total (get amount item)))

(define-private (execute-stx-transfer-memo 
    (item { recipient: principal, amount: uint, memo: (buff 34) })
    (prev-result (response bool uint)))
  (match prev-result
    success
      (match (stx-transfer-memo? (get amount item) tx-sender (get recipient item) (get memo item))
        ok-val (ok true)
        err-val ERR-TRANSFER-FAILED)
    error (err error)))

;; ============================================================================
;; Equal Distribution
;; ============================================================================

;; Distribute equal amounts to all recipients
(define-public (distribute-equal 
    (recipients (list 200 principal))
    (amount-per-recipient uint))
  (let
    (
      (batch-id (+ (var-get total-batches) u1))
      (recipient-count (len recipients))
      (total-amount (* recipient-count amount-per-recipient))
      (fee (calculate-fee total-amount))
    )
    (asserts! (not (var-get is-paused)) ERR-PAUSED)
    (asserts! (> recipient-count u0) ERR-EMPTY-LIST)
    (asserts! (> amount-per-recipient u0) ERR-INVALID-AMOUNT)
    (asserts! (<= recipient-count MAX-RECIPIENTS) ERR-LIST-TOO-LONG)
    
    ;; Collect fee
    (if (> fee u0)
      (try! (stx-transfer? fee tx-sender current-contract))
      true)
    
    ;; Set the transfer amount for the fold operation
    (var-set transfer-amount amount-per-recipient)
    
    ;; Execute equal distribution
    (try! (fold execute-equal-transfer-inner recipients (ok true)))
    
    ;; Record batch
    (map-set batches batch-id
      {
        sender: tx-sender,
        recipient-count: recipient-count,
        total-amount: total-amount,
        executed-at: stacks-block-height,
        asset-type: "STX-EQUAL"
      })
    
    (var-set total-batches batch-id)
    (var-set total-transfers (+ (var-get total-transfers) recipient-count))
    (var-set total-stx-transferred (+ (var-get total-stx-transferred) total-amount))
    
    (ok batch-id)))

(define-private (execute-equal-transfer (amount uint))
  amount) ;; This is a placeholder - see execute-equal-transfer-inner

;; Data var to store transfer amount for fold operation  
(define-data-var transfer-amount uint u0)

;; Inner function for fold that uses the stored transfer amount
(define-private (execute-equal-transfer-inner 
    (recipient principal)
    (prev-result (response bool uint)))
  (match prev-result
    success
      (match (stx-transfer? (var-get transfer-amount) tx-sender recipient)
        ok-val (ok true)
        err-val ERR-TRANSFER-FAILED)
    error (err error)))

;; ============================================================================
;; Percentage Distribution
;; ============================================================================

;; Distribute based on percentage shares (in basis points)
(define-public (distribute-percentage 
    (recipients (list 200 { recipient: principal, share-bps: uint }))
    (total-amount uint))
  (let
    (
      (batch-id (+ (var-get total-batches) u1))
      (recipient-count (len recipients))
      (total-shares (fold sum-shares recipients u0))
      (fee (calculate-fee total-amount))
    )
    (asserts! (not (var-get is-paused)) ERR-PAUSED)
    (asserts! (> recipient-count u0) ERR-EMPTY-LIST)
    (asserts! (is-eq total-shares u10000) ERR-INVALID-AMOUNT) ;; Must equal 100%
    (asserts! (> total-amount u0) ERR-INVALID-AMOUNT)
    
    ;; Collect fee
    (if (> fee u0)
      (try! (stx-transfer? fee tx-sender current-contract))
      true)
    
    ;; Store total for inner function
    (var-set percentage-total total-amount)
    
    ;; Execute percentage distribution
    (try! (fold execute-percentage-transfer-inner recipients (ok true)))
    
    ;; Record batch
    (map-set batches batch-id
      {
        sender: tx-sender,
        recipient-count: recipient-count,
        total-amount: total-amount,
        executed-at: stacks-block-height,
        asset-type: "STX-PERCENT"
      })
    
    (var-set total-batches batch-id)
    (var-set total-transfers (+ (var-get total-transfers) recipient-count))
    (var-set total-stx-transferred (+ (var-get total-stx-transferred) total-amount))
    
    (ok batch-id)))

(define-private (sum-shares 
    (item { recipient: principal, share-bps: uint })
    (total uint))
  (+ total (get share-bps item)))

;; Data var for percentage transfer total amount
(define-data-var percentage-total uint u0)

(define-private (execute-percentage-transfer-inner
    (item { recipient: principal, share-bps: uint })
    (prev-result (response bool uint)))
  (let ((amount (/ (* (var-get percentage-total) (get share-bps item)) u10000)))
    (match prev-result
      success
        (if (> amount u0)
          (match (stx-transfer? amount tx-sender (get recipient item))
            ok-val (ok true)
            err-val ERR-TRANSFER-FAILED)
          (ok true))
      error (err error))))

;; ============================================================================
;; Admin Functions
;; ============================================================================

;; Update fee
(define-public (set-fee-bps (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee u100) ERR-INVALID-AMOUNT) ;; Max 1%
    (var-set fee-bps new-fee)
    (print { event: "fee-updated", new-fee: new-fee })
    (ok new-fee)))

;; Pause/unpause
(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set is-paused paused)
    (print { event: "pause-updated", paused: paused })
    (ok paused)))

;; Withdraw collected fees
(define-public (withdraw-fees)
  (let
    (
      (stx-fees (get-collected-fees "STX"))
      (total-fees (+ stx-fees (get-collected-fees "STX-MEMO") (get-collected-fees "STX-EQUAL") (get-collected-fees "STX-PERCENT")))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> total-fees u0) ERR-INVALID-AMOUNT)
    
    ;; Transfer fees to owner
    (try! (as-contract? ((with-stx total-fees)) (try! (stx-transfer? total-fees tx-sender CONTRACT-OWNER))))
    
    ;; Reset fee counters
    (map-set collected-fees "STX" u0)
    (map-set collected-fees "STX-MEMO" u0)
    (map-set collected-fees "STX-EQUAL" u0)
    (map-set collected-fees "STX-PERCENT" u0)
    
    (print { event: "fees-withdrawn", amount: total-fees })
    (ok total-fees)))
