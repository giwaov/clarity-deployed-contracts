;; title: sbtc-paylings
;; version:
;; summary:
;; description:

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

;; State constants
(define-constant STATE-PENDING "pending")
(define-constant STATE-PAID "paid")
(define-constant STATE-EXPIRED "expired")
(define-constant STATE-CANCELED "canceled")

;; Official sBTC token contract
(define-constant SBTC-CONTRACT 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token)

;; Contract owner (for potential upgrades or admin functions)
(define-constant CONTRACT-OWNER tx-sender)

;; Maximum expiration time (30 days in blocks, assuming ~10 min per block)
(define-constant MAX-EXPIRATION-BLOCKS u4320) ;; ~30 days

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
  { ids: (list 50 uint) }
)

;; Index of tags by recipient
(define-map tags-by-recipient
  { recipient: principal }
  { ids: (list 50 uint) }
)

;; ========== Variables ==========

;; Counter for auto-incrementing IDs
(define-data-var last-id uint u0)

;; ========== Internal Functions ==========
(define-private (add-id-to-principal-list
    (user principal)
    (id uint)
  )
  (let (
      (current-list-data (default-to { ids: (list) } (map-get? tags-by-creator { creator: user })))
      (current-list (get ids current-list-data))
      (new-list (unwrap! (as-max-len? (append current-list id) u50) current-list))
    )
    (begin
      (map-set tags-by-creator { creator: user } { ids: new-list })
      new-list
    )
  )
)

;; Check if current block height is past the expiration
(define-private (is-expired (expires-at uint))
  (>= stacks-block-height expires-at)
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

;; ========== Public Functions ==========
;; Create a new PayTag
(define-public (create-pay-tag
    (amount uint)
    (expires-in uint)
    (memo (optional (string-ascii 256)))
  )
  (let (
      (new-id (+ (var-get last-id) u1))
      (expiration-height (+ stacks-block-height expires-in))
      (recipient tx-sender)
    )
    ;; Default recipient is sender, could be a parameter
    (begin
      ;; Validate inputs
      (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
      (asserts! (<= expires-in MAX-EXPIRATION-BLOCKS)
        (err ERR-MAX-EXPIRATION-EXCEEDED)
      )

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

      ;; Add to creator's index - store result locally to discard it
      (let ((creator-result (add-id-to-principal-list tx-sender new-id)))
        ;; If recipient is different from creator, add to recipient's index too
        (if (not (is-eq recipient tx-sender))
          ;; Store the result locally, effectively discarding it
          (let ((recipient-result (add-id-to-principal-list recipient new-id)))
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
        amount: amount,
      })
      (ok new-id)
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
