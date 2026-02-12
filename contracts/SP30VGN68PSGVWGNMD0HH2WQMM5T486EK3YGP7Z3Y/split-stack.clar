;; Split Payment Contract with Withdrawal Mechanism
;; Allows automatic payment distribution or accumulated withdrawal

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_SHARES (err u101))
(define-constant ERR_SPLIT_NOT_FOUND (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_TOO_MANY_RECIPIENTS (err u104))
(define-constant ERR_INVALID_RECIPIENT (err u105))
(define-constant ERR_INSUFFICIENT_BALANCE (err u106))
(define-constant ERR_NO_BALANCE (err u107))
(define-constant MAX_RECIPIENTS u10)

;; Data Variables
(define-data-var split-nonce uint u0)

;; Data Maps
(define-map splits
  uint
  {
    owner: principal,
    name: (string-ascii 50),
    active: bool,
    total-received: uint,
    pending-balance: uint,
    auto-distribute: bool  ;; If true, sends immediately; if false, accumulates
  }
)

(define-map split-recipients
  { split-id: uint, recipient-index: uint }
  {
    recipient: principal,
    share: uint  ;; Percentage (out of 10000 for 2 decimal precision: 100.00%)
  }
)

(define-map split-recipient-count
  uint
  uint
)

(define-map user-splits
  principal
  (list 100 uint)
)

;; Track individual recipient balances for accumulated mode
(define-map recipient-balances
  { split-id: uint, recipient: principal }
  uint
)

;; Private Functions

(define-private (validate-shares (recipients (list 10 {recipient: principal, share: uint})))
  (let
    (
      (total-shares (fold + (map get-share recipients) u0))
    )
    (is-eq total-shares u10000)
  )
)

(define-private (get-share (recipient {recipient: principal, share: uint}))
  (get share recipient)
)

(define-private (calculate-payment (amount uint) (share uint))
  (/ (* amount share) u10000)
)

(define-private (send-to-recipient (recipient-data {recipient: principal, amount: uint}))
  (let
    (
      (recipient (get recipient recipient-data))
      (amount (get amount recipient-data))
    )
    (if (> amount u0)
      (unwrap-panic (as-contract (stx-transfer? amount tx-sender recipient)))
      true
    )
  )
)

;; Public Functions

;; Create a new split
(define-public (create-split 
  (name (string-ascii 50))
  (recipients (list 10 {recipient: principal, share: uint}))
  (auto-distribute bool))
  (let
    (
      (new-split-id (+ (var-get split-nonce) u1))
      (recipient-count (len recipients))
    )
    ;; Validations
    (asserts! (> recipient-count u0) ERR_INVALID_RECIPIENT)
    (asserts! (<= recipient-count MAX_RECIPIENTS) ERR_TOO_MANY_RECIPIENTS)
    (asserts! (validate-shares recipients) ERR_INVALID_SHARES)
    
    ;; Create split
    (map-set splits
      new-split-id
      {
        owner: tx-sender,
        name: name,
        active: true,
        total-received: u0,
        pending-balance: u0,
        auto-distribute: auto-distribute
      }
    )
    
    ;; Store recipients
    (map store-recipient-helper 
      (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9)
      recipients
      (list new-split-id new-split-id new-split-id new-split-id new-split-id 
            new-split-id new-split-id new-split-id new-split-id new-split-id)
    )
    
    (map-set split-recipient-count new-split-id recipient-count)
    
    ;; Update user's split list
    (map-set user-splits 
      tx-sender 
      (unwrap-panic (as-max-len? 
        (append (default-to (list) (map-get? user-splits tx-sender)) new-split-id) 
        u100))
    )
    
    ;; Increment nonce
    (var-set split-nonce new-split-id)
    
    (ok new-split-id)
  )
)

(define-private (store-recipient-helper (index uint) (recipient {recipient: principal, share: uint}) (split-id uint))
  (if (< index (len (list recipient)))
    (map-set split-recipients
      { split-id: split-id, recipient-index: index }
      recipient
    )
    false
  )
)

;; Send payment to split (distributes immediately or accumulates based on mode)
(define-public (send-to-split (split-id uint) (amount uint))
  (let
    (
      (split-data (unwrap! (map-get? splits split-id) ERR_SPLIT_NOT_FOUND))
      (recipient-count (unwrap! (map-get? split-recipient-count split-id) ERR_SPLIT_NOT_FOUND))
    )
    ;; Validations
    (asserts! (get active split-data) ERR_SPLIT_NOT_FOUND)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (if (get auto-distribute split-data)
      ;; Distribute immediately
      (begin
        (let
          (
            (distribution-list (build-distribution-list split-id recipient-count amount))
          )
          (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
          (map send-to-recipient distribution-list)
        )
        (map-set splits
          split-id
          (merge split-data { total-received: (+ (get total-received split-data) amount) })
        )
        (ok true)
      )
      ;; Accumulate for later withdrawal
      (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (accumulate-balances split-id recipient-count amount)
        (map-set splits
          split-id
          (merge split-data { 
            total-received: (+ (get total-received split-data) amount),
            pending-balance: (+ (get pending-balance split-data) amount)
          })
        )
        (ok true)
      )
    )
  )
)

;; Accumulate balances for each recipient
(define-private (accumulate-balances (split-id uint) (count uint) (amount uint))
  (begin
    (map accumulate-from-payment
      (build-distribution-list split-id count amount)
      (list split-id split-id split-id split-id split-id split-id split-id split-id split-id split-id)
    )
    true
  )
)

(define-private (accumulate-from-payment (payment {recipient: principal, amount: uint}) (split-id uint))
  (let
    (
      (recipient (get recipient payment))
      (payment-amount (get amount payment))
      (current-balance (default-to u0 (map-get? recipient-balances { split-id: split-id, recipient: recipient })))
    )
    (map-set recipient-balances
      { split-id: split-id, recipient: recipient }
      (+ current-balance payment-amount)
    )
  )
)
(define-private (is-positive (amount uint))
  (> amount u0)
)


;; Withdraw accumulated balance (recipient only)
(define-public (withdraw (split-id uint))
  (let
    (
      (split-data (unwrap! (map-get? splits split-id) ERR_SPLIT_NOT_FOUND))
      (balance (unwrap! (get-recipient-balance split-id tx-sender) ERR_NO_BALANCE))
    )
    (asserts! (> balance u0) ERR_NO_BALANCE)
    (asserts! (not (get auto-distribute split-data)) ERR_UNAUTHORIZED)
    
    ;; Transfer balance to recipient
    (try! (as-contract (stx-transfer? balance tx-sender tx-sender)))
    
    ;; Reset recipient balance
    (map-set recipient-balances
      { split-id: split-id, recipient: tx-sender }
      u0
    )
    
    ;; Update split pending balance
    (map-set splits
      split-id
      (merge split-data { pending-balance: (- (get pending-balance split-data) balance) })
    )
    
    (ok balance)
  )
)

;; Distribute all pending balances (owner only)
(define-public (distribute-all (split-id uint))
  (let
    (
      (split-data (unwrap! (map-get? splits split-id) ERR_SPLIT_NOT_FOUND))
      (recipient-count (unwrap! (map-get? split-recipient-count split-id) ERR_SPLIT_NOT_FOUND))
      (pending (get pending-balance split-data))
    )
    (asserts! (is-eq tx-sender (get owner split-data)) ERR_UNAUTHORIZED)
    (asserts! (> pending u0) ERR_NO_BALANCE)
    (asserts! (not (get auto-distribute split-data)) ERR_UNAUTHORIZED)
    
    ;; Distribute to all recipients
    (let
      (
        (distribution-list (build-distribution-list split-id recipient-count pending))
      )
      (map send-to-recipient distribution-list)
    )
    
    ;; Reset all balances and pending
    (reset-recipient-balances split-id recipient-count)
    
    (map-set splits
      split-id
      (merge split-data { pending-balance: u0 })
    )
    
    (ok true)
  )
)

(define-private (reset-recipient-balances (split-id uint) (count uint))
  (begin
    (map reset-balance-from-payment
      (build-distribution-list split-id count u10000)  ;; Use dummy amount just to get recipient list
      (list split-id split-id split-id split-id split-id split-id split-id split-id split-id split-id)
    )
    true
  )
)

(define-private (reset-balance-from-payment (payment {recipient: principal, amount: uint}) (split-id uint))
  (map-set recipient-balances
    { split-id: split-id, recipient: (get recipient payment) }
    u0
  )
)


(define-private (build-distribution-list (split-id uint) (count uint) (amount uint))
  (let
    (
      (r0 (map-get? split-recipients {split-id: split-id, recipient-index: u0}))
      (r1 (map-get? split-recipients {split-id: split-id, recipient-index: u1}))
      (r2 (map-get? split-recipients {split-id: split-id, recipient-index: u2}))
      (r3 (map-get? split-recipients {split-id: split-id, recipient-index: u3}))
      (r4 (map-get? split-recipients {split-id: split-id, recipient-index: u4}))
      (r5 (map-get? split-recipients {split-id: split-id, recipient-index: u5}))
      (r6 (map-get? split-recipients {split-id: split-id, recipient-index: u6}))
      (r7 (map-get? split-recipients {split-id: split-id, recipient-index: u7}))
      (r8 (map-get? split-recipients {split-id: split-id, recipient-index: u8}))
      (r9 (map-get? split-recipients {split-id: split-id, recipient-index: u9}))
    )
    (unwrap-panic (as-max-len?
      (filter is-valid-payment
        (list
          (if (is-some r0) {recipient: (get recipient (unwrap-panic r0)), amount: (calculate-payment amount (get share (unwrap-panic r0)))} {recipient: CONTRACT_OWNER, amount: u0})
          (if (is-some r1) {recipient: (get recipient (unwrap-panic r1)), amount: (calculate-payment amount (get share (unwrap-panic r1)))} {recipient: CONTRACT_OWNER, amount: u0})
          (if (is-some r2) {recipient: (get recipient (unwrap-panic r2)), amount: (calculate-payment amount (get share (unwrap-panic r2)))} {recipient: CONTRACT_OWNER, amount: u0})
          (if (is-some r3) {recipient: (get recipient (unwrap-panic r3)), amount: (calculate-payment amount (get share (unwrap-panic r3)))} {recipient: CONTRACT_OWNER, amount: u0})
          (if (is-some r4) {recipient: (get recipient (unwrap-panic r4)), amount: (calculate-payment amount (get share (unwrap-panic r4)))} {recipient: CONTRACT_OWNER, amount: u0})
          (if (is-some r5) {recipient: (get recipient (unwrap-panic r5)), amount: (calculate-payment amount (get share (unwrap-panic r5)))} {recipient: CONTRACT_OWNER, amount: u0})
          (if (is-some r6) {recipient: (get recipient (unwrap-panic r6)), amount: (calculate-payment amount (get share (unwrap-panic r6)))} {recipient: CONTRACT_OWNER, amount: u0})
          (if (is-some r7) {recipient: (get recipient (unwrap-panic r7)), amount: (calculate-payment amount (get share (unwrap-panic r7)))} {recipient: CONTRACT_OWNER, amount: u0})
          (if (is-some r8) {recipient: (get recipient (unwrap-panic r8)), amount: (calculate-payment amount (get share (unwrap-panic r8)))} {recipient: CONTRACT_OWNER, amount: u0})
          (if (is-some r9) {recipient: (get recipient (unwrap-panic r9)), amount: (calculate-payment amount (get share (unwrap-panic r9)))} {recipient: CONTRACT_OWNER, amount: u0})
        )
      )
      u10
    ))
  )
)

(define-private (is-valid-payment (payment {recipient: principal, amount: uint}))
  (> (get amount payment) u0)
)

;; Toggle split active status (owner only)
(define-public (toggle-split-status (split-id uint))
  (let
    (
      (split-data (unwrap! (map-get? splits split-id) ERR_SPLIT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner split-data)) ERR_UNAUTHORIZED)
    
    (map-set splits
      split-id
      (merge split-data { active: (not (get active split-data)) })
    )
    
    (ok true)
  )
)

;; Toggle auto-distribute mode (owner only)
(define-public (toggle-auto-distribute (split-id uint))
  (let
    (
      (split-data (unwrap! (map-get? splits split-id) ERR_SPLIT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner split-data)) ERR_UNAUTHORIZED)
    
    (map-set splits
      split-id
      (merge split-data { auto-distribute: (not (get auto-distribute split-data)) })
    )
    
    (ok true)
  )
)

;; Read-only functions

(define-read-only (get-split-info (split-id uint))
  (map-get? splits split-id)
)

(define-read-only (get-split-recipient (split-id uint) (recipient-index uint))
  (map-get? split-recipients { split-id: split-id, recipient-index: recipient-index })
)

(define-read-only (get-split-recipient-count (split-id uint))
  (map-get? split-recipient-count split-id)
)

(define-read-only (get-user-splits (user principal))
  (default-to (list) (map-get? user-splits user))
)

(define-read-only (get-current-split-id)
  (var-get split-nonce)
)

(define-read-only (get-recipient-balance (split-id uint) (recipient principal))
  (map-get? recipient-balances { split-id: split-id, recipient: recipient })
)

