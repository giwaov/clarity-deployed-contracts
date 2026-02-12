;; Bill Split Contract
;; Allows a creator (e.g., coffee shop) to split a bill among multiple payers

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_SPLIT_NOT_FOUND (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_TOO_MANY_PAYERS (err u103))
(define-constant ERR_INVALID_PAYER (err u104))
(define-constant ERR_ALREADY_PAID (err u105))
(define-constant ERR_WRONG_AMOUNT (err u106))
(define-constant ERR_NOT_FULLY_PAID (err u107))
(define-constant ERR_ALREADY_WITHDRAWN (err u108))
(define-constant ERR_SPLIT_CANCELLED (err u109))
(define-constant MAX_PAYERS u10)

;; Data Variables
(define-data-var split-nonce uint u0)

;; Data Maps
(define-map splits
  uint
  {
    creator: principal,
    name: (string-ascii 50),
    total-amount: uint,
    amount-paid: uint,
    withdrawn: bool,
    cancelled: bool
  }
)

(define-map split-payers
  { split-id: uint, payer: principal }
  {
    amount-owed: uint,
    amount-paid: uint,
    paid: bool
  }
)

(define-map split-payer-list
  uint
  (list 10 principal)
)

(define-map user-splits
  principal
  (list 100 uint)
)

;; Private Functions

(define-private (sum-amounts (payer {payer: principal, amount: uint}) (total uint))
  (+ total (get amount payer))
)

;; Public Functions

;; Create a new bill split
(define-public (create-split 
  (name (string-ascii 50))
  (payers (list 10 {payer: principal, amount: uint})))
  (let
    (
      (new-split-id (+ (var-get split-nonce) u1))
      (payer-count (len payers))
      (total-amount (fold sum-amounts payers u0))
    )
    ;; Validations
    (asserts! (> payer-count u0) ERR_INVALID_PAYER)
    (asserts! (<= payer-count MAX_PAYERS) ERR_TOO_MANY_PAYERS)
    (asserts! (> total-amount u0) ERR_INVALID_AMOUNT)
    
    ;; Create split
    (map-set splits
      new-split-id
      {
        creator: tx-sender,
        name: name,
        total-amount: total-amount,
        amount-paid: u0,
        withdrawn: false,
        cancelled: false
      }
    )
    
    ;; Store payers and their amounts
    (map store-payer-data payers (list new-split-id new-split-id new-split-id new-split-id new-split-id 
                                       new-split-id new-split-id new-split-id new-split-id new-split-id))
    
    ;; Store payer list
    (map-set split-payer-list 
      new-split-id 
      (unwrap-panic (as-max-len? (map get-payer-principal payers) u10))
    )
    
    ;; Update creator's split list
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

(define-private (store-payer-data (payer-data {payer: principal, amount: uint}) (split-id uint))
  (map-set split-payers
    { split-id: split-id, payer: (get payer payer-data) }
    {
      amount-owed: (get amount payer-data),
      amount-paid: u0,
      paid: false
    }
  )
)

(define-private (get-payer-principal (payer-data {payer: principal, amount: uint}))
  (get payer payer-data)
)

;; Pay your share of the split
(define-public (pay-split (split-id uint))
  (let
    (
      (split-data (unwrap! (map-get? splits split-id) ERR_SPLIT_NOT_FOUND))
      (payer-data (unwrap! (map-get? split-payers { split-id: split-id, payer: tx-sender }) ERR_UNAUTHORIZED))
    )
    ;; Validations
    (asserts! (not (get cancelled split-data)) ERR_SPLIT_CANCELLED)
    (asserts! (not (get paid payer-data)) ERR_ALREADY_PAID)
    (asserts! (> (get amount-owed payer-data) u0) ERR_INVALID_AMOUNT)
    
    ;; Transfer payment to contract
    (try! (stx-transfer? (get amount-owed payer-data) tx-sender (as-contract tx-sender)))
    
    ;; Mark as paid
    (map-set split-payers
      { split-id: split-id, payer: tx-sender }
      (merge payer-data { 
        amount-paid: (get amount-owed payer-data),
        paid: true 
      })
    )
    
    ;; Update split total paid
    (map-set splits
      split-id
      (merge split-data { 
        amount-paid: (+ (get amount-paid split-data) (get amount-owed payer-data))
      })
    )
    
    (ok true)
  )
)

;; Withdraw funds (creator only, after all payments received)
(define-public (withdraw-split (split-id uint))
  (let
    (
      (split-data (unwrap! (map-get? splits split-id) ERR_SPLIT_NOT_FOUND))
    )
    ;; Validations
    (asserts! (is-eq tx-sender (get creator split-data)) ERR_UNAUTHORIZED)
    (asserts! (not (get cancelled split-data)) ERR_SPLIT_CANCELLED)
    (asserts! (not (get withdrawn split-data)) ERR_ALREADY_WITHDRAWN)
    (asserts! (is-eq (get amount-paid split-data) (get total-amount split-data)) ERR_NOT_FULLY_PAID)
    
    ;; Transfer funds to creator
    (try! (as-contract (stx-transfer? (get total-amount split-data) tx-sender (get creator split-data))))
    
    ;; Mark as withdrawn
    (map-set splits
      split-id
      (merge split-data { withdrawn: true })
    )
    
    (ok (get total-amount split-data))
  )
)

;; Cancel split and refund all payers (creator only)
(define-public (cancel-split (split-id uint))
  (let
    (
      (split-data (unwrap! (map-get? splits split-id) ERR_SPLIT_NOT_FOUND))
      (payer-list (unwrap! (map-get? split-payer-list split-id) ERR_SPLIT_NOT_FOUND))
    )
    ;; Validations
    (asserts! (is-eq tx-sender (get creator split-data)) ERR_UNAUTHORIZED)
    (asserts! (not (get withdrawn split-data)) ERR_ALREADY_WITHDRAWN)
    (asserts! (not (get cancelled split-data)) ERR_SPLIT_CANCELLED)
    
    ;; Refund all payers who have paid
    (map refund-payer payer-list (list split-id split-id split-id split-id split-id 
                                       split-id split-id split-id split-id split-id))
    
    ;; Mark as cancelled
    (map-set splits
      split-id
      (merge split-data { cancelled: true })
    )
    
    (ok true)
  )
)

(define-private (refund-payer (payer principal) (split-id uint))
  (let
    (
      (payer-data (map-get? split-payers { split-id: split-id, payer: payer }))
    )
    (match payer-data
      data
      (if (get paid data)
        (begin
          (unwrap-panic (as-contract (stx-transfer? (get amount-paid data) tx-sender payer)))
          true
        )
        true
      )
      true
    )
  )
)

;; Read-only functions

(define-read-only (get-split-info (split-id uint))
  (map-get? splits split-id)
)

(define-read-only (get-payer-info (split-id uint) (payer principal))
  (map-get? split-payers { split-id: split-id, payer: payer })
)

(define-read-only (get-split-payers (split-id uint))
  (map-get? split-payer-list split-id)
)

(define-read-only (is-split-fully-paid (split-id uint))
  (match (map-get? splits split-id)
    split-data (ok (is-eq (get amount-paid split-data) (get total-amount split-data)))
    ERR_SPLIT_NOT_FOUND
  )
)

(define-read-only (get-user-splits (user principal))
  (default-to (list) (map-get? user-splits user))
)

(define-read-only (get-current-split-id)
  (var-get split-nonce)
)

(define-read-only (get-split-status (split-id uint))
  (match (map-get? splits split-id)
    split-data 
    (ok {
      is-cancelled: (get cancelled split-data),
      is-withdrawn: (get withdrawn split-data),
      is-fully-paid: (is-eq (get amount-paid split-data) (get total-amount split-data)),
      amount-paid: (get amount-paid split-data),
      amount-remaining: (- (get total-amount split-data) (get amount-paid split-data))
    })
    ERR_SPLIT_NOT_FOUND
  )
)

