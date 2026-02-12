---
title: "Trait paylinkr"
draft: true
---
```
;; pay-tag.clar
;; PayTag Contract for creating and fulfilling payment requests using real sBTC
;; Version: 1.0.0
;; ========== Constants ==========
;; Error codes
(define-constant ERR-TAG-EXISTS u100)
(define-constant ERR-NOT-PENDING u101)
(define-constant ERR-INSUFFICIENT-FUNDS u102)
(define-constant ERR-NOT-FOUND u103)
(define-constant ERR-UNAUTHORIZED u104)
(define-constant ERR-EXPIRED u105)
(define-constant ERR-INVALID-AMOUNT u106)
(define-constant ERR-EMPTY-MEMO u107)
(define-constant ERR-MAX-EXPIRATION-EXCEEDED u108)
(define-constant ERR-INVALID-RECIPIENT u109)
(define-constant ERR-INVALID-FEE-PERCENT u110)
(define-constant ERR-FEE-BELOW-MINIMUM u111)
(define-constant ERR-FEE-ABOVE-MAXIMUM u112)
(define-constant ERR-ONLY-ADMIN u113)
;; State constants
(define-constant STATE-PENDING "pending")
(define-constant STATE-PAID "paid")
(define-constant STATE-EXPIRED "expired")
(define-constant STATE-CANCELED "canceled")
;; Define the sBTC token contract reference
(define-constant sbtc-token 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)
;; Maximum expiration time (365 days in blocks, assuming ~10 min per block)
(define-constant MAX-EXPIRATION-BLOCKS u52560) ;; ~365 days
;; Fee configuration constants
(define-constant MIN-FEE-PERCENT u0) ;; 0% minimum
(define-constant MAX-FEE-PERCENT u1000) ;; 10% maximum (1000 = 10.00%)
(define-constant FEE-DENOMINATOR u10000) ;; 10000 = 100.00%
(define-constant MIN-FEE-AMOUNT u100) ;; Minimum fee in sBTC smallest units
(define-constant MAX-FEE-AMOUNT u100000000) ;; Maximum fee in sBTC smallest units (1 sBTC)
;; ========== Data Maps ==========
;; Main map to store payment tags
(define-map pay-tags
  { id: uint }
  {
    creator: principal,
    recipient: principal,
    amount: uint,
    created-at: uint,
    expires-at: uint,
    memo: (optional (string-ascii 256)),
    state: (string-ascii 16),
    payment-tx: (optional (buff 32)), ;; txid when paid
  }
)
;; Index of tags by creator
(define-map tags-by-creator
  { creator: principal }
  { ids: (list 200 uint) }
)
;; Index of tags by recipient
(define-map tags-by-recipient
  { recipient: principal }
  { ids: (list 200 uint) }
)
;; ========== Variables ==========
;; Counter for auto-incrementing IDs
(define-data-var last-id uint u0)
;; Admin wallet address
(define-data-var admin-wallet principal tx-sender)
;; Processing fee percentage (in basis points, e.g., 100 = 1%)
(define-data-var fee-percent uint u500) ;; 5%
;; ========== Internal Functions ==========
(define-private (add-id-to-principal-list
    (user principal)
    (id uint)
    (is-creator bool)
  )
  (if is-creator
    (let (
        (current-list-data (default-to { ids: (list) } (map-get? tags-by-creator { creator: user })))
        (current-list (get ids current-list-data))
        (new-list (unwrap! (as-max-len? (append current-list id) u200) current-list))
      )
      (begin
        (map-set tags-by-creator { creator: user } { ids: new-list })
        new-list
      )
    )
    (let (
        (current-list-data (default-to { ids: (list) } (map-get? tags-by-recipient { recipient: user })))
        (current-list (get ids current-list-data))
        (new-list (unwrap! (as-max-len? (append current-list id) u200) current-list))
      )
      (begin
        (map-set tags-by-recipient { recipient: user } { ids: new-list })
        new-list
      )
    )
  )
)

;; Check if current block height is past the expiration
(define-private (is-expired (expires-at uint))
  (>= stacks-block-height expires-at)
)

;; Calculate processing fee for a given amount
(define-private (calculate-fee (amount uint))
  (let (
      (fee-percent-value (var-get fee-percent))
      (calculated-fee (/ (* amount fee-percent-value) FEE-DENOMINATOR))
    )
    (if (> calculated-fee MIN-FEE-AMOUNT)
      (if (< calculated-fee MAX-FEE-AMOUNT)
        calculated-fee
        MAX-FEE-AMOUNT
      )
      MIN-FEE-AMOUNT
    )
  )
)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin-wallet))
)

;; ========== Read-Only Functions ==========
;; Get the current ID counter
(define-read-only (get-last-id)
  (ok (var-get last-id))
)

;; Get details of a specific PayTag
(define-read-only (get-pay-tag (id uint))
  (match (map-get? pay-tags { id: id })
    entry (ok entry)
    (err ERR-NOT-FOUND)
  )
)

;; Get IDs of all tags created by a principal
(define-read-only (get-creator-tags (creator principal))
  (match (map-get? tags-by-creator { creator: creator })
    entry (ok (get ids entry))
    (ok (list))
  )
)

;; Get IDs of all tags where principal is recipient
(define-read-only (get-recipient-tags (recipient principal))
  (match (map-get? tags-by-recipient { recipient: recipient })
    entry (ok (get ids entry))
    (ok (list))
  )
)

;; Check if a tag is expired but not marked as expired yet
(define-read-only (check-tag-expired (id uint))
  (match (map-get? pay-tags { id: id })
    tag (if (and
        (is-eq (get state tag) STATE-PENDING)
        (is-expired (get expires-at tag))
      )
      (ok true)
      (ok false)
    )
    (err ERR-NOT-FOUND)
  )
)

;; Get current admin wallet
(define-read-only (get-admin-wallet)
  (ok (var-get admin-wallet))
)

;; Get current fee percentage
(define-read-only (get-fee-percent)
  (ok (var-get fee-percent))
)

;; ========== Public Functions ==========
;; Create a new PayTag
(define-public (create-pay-tag
    (amount uint)
    (expires-in uint)
    (recipient principal)
    (memo (optional (string-ascii 256)))
  )
  (let (
      (new-id (+ (var-get last-id) u1))
      (expiration-height (+ stacks-block-height expires-in))
    )
    (begin
      ;; Validate inputs
      (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
      (asserts! (<= expires-in MAX-EXPIRATION-BLOCKS)
        (err ERR-MAX-EXPIRATION-EXCEEDED)
      )
      (asserts! (is-standard recipient) (err ERR-INVALID-RECIPIENT))
      ;; Set new ID and add to map
      (var-set last-id new-id)
      (map-set pay-tags { id: new-id } {
        creator: tx-sender,
        recipient: recipient,
        amount: amount,
        created-at: stacks-block-height,
        expires-at: expiration-height,
        memo: memo,
        state: STATE-PENDING,
        payment-tx: none,
      })
      ;; Add to creator's index
      (let ((creator-result (add-id-to-principal-list tx-sender new-id true)))
        ;; If recipient is different from creator, add to recipient's index too
        (if (not (is-eq recipient tx-sender))
          ;; Store the result locally, effectively discarding it
          (let ((recipient-result (add-id-to-principal-list recipient new-id false)))
            true
          )
          ;; Both branches return bool
          true
        )
      )
      ;; Emit event
      (print {
        event: "pay-tag-created",
        id: new-id,
        creator: tx-sender,
        recipient: recipient,
        amount: amount,
      })
      (ok new-id)
    )
  )
)

;; Fulfill a PayTag (pay the recipient)
(define-public (fulfill-pay-tag (id uint))
  (let (
      (tag (unwrap! (map-get? pay-tags { id: id }) (err ERR-NOT-FOUND)))
      (amount (get amount tag))
      (recipient (get recipient tag))
      (fee-amount (calculate-fee amount))
      (net-amount (- amount fee-amount))
      (admin-address (var-get admin-wallet))
    )
    (begin
      ;; Verify the tag is still pending
      (asserts! (is-eq (get state tag) STATE-PENDING) (err ERR-NOT-PENDING))
      ;; Verify the tag has not expired
      (asserts! (< stacks-block-height (get expires-at tag)) (err ERR-EXPIRED))
      ;; Transfer net amount to recipient
      ;; Note: sBTC token contract not available in test environment
      ;; In production, this would transfer the actual sBTC tokens
      (try! (contract-call? sbtc-token transfer net-amount tx-sender recipient none))
      ;; Transfer fee to admin wallet (if fee > 0)
      (if (> fee-amount u0)
        (try! (contract-call? sbtc-token transfer fee-amount tx-sender admin-address none))
        true
      )
      ;; Update tag state to paid
      (map-set pay-tags { id: id }
        (merge tag {
          state: STATE-PAID,
          payment-tx: none, ;; Setting to none since we can't access the actual tx hash
        })
      )
      ;; Emit payment event
      (print {
        event: "pay-tag-paid",
        id: id,
        from: tx-sender,
        to: recipient,
        amount: amount,
        net-amount: net-amount,
        fee-amount: fee-amount,
        memo: (get memo tag),
      })
      (ok id)
    )
  )
)

;; Cancel a PayTag (creator only)
(define-public (cancel-pay-tag (id uint))
  (let ((tag (unwrap! (map-get? pay-tags { id: id }) (err ERR-NOT-FOUND))))
    (begin
      ;; Verify sender is the creator
      (asserts! (is-eq tx-sender (get creator tag)) (err ERR-UNAUTHORIZED))
      ;; Verify the tag is still pending
      (asserts! (is-eq (get state tag) STATE-PENDING) (err ERR-NOT-PENDING))
      ;; Update tag state to canceled
      (map-set pay-tags { id: id } (merge tag { state: STATE-CANCELED }))
      ;; Emit event
      (print {
        event: "pay-tag-canceled",
        id: id,
        creator: tx-sender,
      })
      (ok id)
    )
  )
)

;; Mark a PayTag as expired (can be called by anyone, but only if actually expired)
(define-public (mark-expired (id uint))
  (let ((tag (unwrap! (map-get? pay-tags { id: id }) (err ERR-NOT-FOUND))))
    (begin
      ;; Verify the tag is still pending
      (asserts! (is-eq (get state tag) STATE-PENDING) (err ERR-NOT-PENDING))
      ;; Verify the tag has actually expired
      (asserts! (is-expired (get expires-at tag)) (err u107))
      ;; Update tag state to expired
      (map-set pay-tags { id: id } (merge tag { state: STATE-EXPIRED }))
      ;; Emit event
      (print {
        event: "pay-tag-expired",
        id: id,
      })
      (ok id)
    )
  )
)

;; Batch function to get multiple tags (useful for UIs)
(define-public (get-multiple-tags (ids (list 20 uint)))
  (ok (map get-tag-or-none ids))
)

;; Helper for batch function
(define-private (get-tag-or-none (id uint))
  (map-get? pay-tags { id: id })
)

;; ========== Admin Functions ==========
;; Set admin wallet (admin only)
(define-public (set-admin-wallet (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR-ONLY-ADMIN))
    (asserts! (is-standard new-admin) (err ERR-INVALID-RECIPIENT))
    (var-set admin-wallet new-admin)
    (print {
      event: "admin-wallet-updated",
      new-admin: new-admin,
      updated-by: tx-sender
    })
    (ok new-admin)
  )
)

;; Set fee percentage (admin only)
(define-public (set-fee-percent (new-fee-percent uint))
  (begin
    (asserts! (is-admin) (err ERR-ONLY-ADMIN))
    (asserts! (>= new-fee-percent MIN-FEE-PERCENT) (err ERR-FEE-BELOW-MINIMUM))
    (asserts! (<= new-fee-percent MAX-FEE-PERCENT) (err ERR-FEE-ABOVE-MAXIMUM))
    (var-set fee-percent new-fee-percent)
    (print {
      event: "fee-percent-updated",
      new-fee-percent: new-fee-percent,
      updated-by: tx-sender
    })
    (ok new-fee-percent)
  )
)

```
