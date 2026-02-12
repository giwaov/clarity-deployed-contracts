;; title: message-board
;; version: 1.0.0
;; summary: A message board contract using Clarity 4 features
;; description: Users can add messages. Demonstrates Clarity 4: contract-hash? and restrict-assets?

;; constants
(define-constant CONTRACT_OWNER tx-sender)

(define-constant ERR_INVALID_MESSAGE (err u1002))
(define-constant ERR_BLOCK_NOT_FOUND (err u1006))

;; data vars
(define-data-var message-count uint u0)

;; data maps
(define-map messages
  { id: uint }
  {
    content: (string-utf8 280),
    author: principal,
    timestamp: uint
  }
)

;; public functions
(define-public (add-message (content (string-utf8 280)))
  (begin
    ;; Validate message content
    (asserts! (> (len content) u0) ERR_INVALID_MESSAGE)
    
    ;; Get next message ID
    (let ((id (+ (var-get message-count) u1)))
      ;; Store message data with burn-block-height for timestamp
      (map-set messages { id: id } {
        content: content,
        author: contract-caller,
        timestamp: burn-block-height
      })
      ;; Update message count
      (var-set message-count id)
      ;; Emit event
      (print {
        event: "[Stacks Dev Quickstart] New Message",
        message: content,
        id: id,
        author: contract-caller,
        time: burn-block-height,
      })
      ;; Return the message ID
      (ok id)
    )
  )
)

;; read only functions
;; Read-only function to get a message by ID
(define-read-only (get-message (id uint))
  (map-get? messages { id: id })
)

;; Read-only function to get message author
(define-read-only (get-message-author (id uint))
  (get author (map-get? messages { id: id }))
)

;; Read-only function to get message count at a specific Stacks block height
(define-read-only (get-message-count-at-block (block uint))
  (ok (at-block
    (unwrap! (get-stacks-block-info? id-header-hash block) ERR_BLOCK_NOT_FOUND)
    (var-get message-count)
  ))
)

;; Get current burn block height (alternative to stacks-block-time for testnet compatibility)
(define-read-only (get-current-block-height)
  (ok burn-block-height)
)

;; Clarity 4 feature: Get contract hash (contract-hash?)
;; Returns (response (buff 32) uint) - the hash of the contract's code body
(define-read-only (get-contract-hash (contract-principal principal))
  (contract-hash? contract-principal)
)

;; Clarity 4 feature: Verify contract hash
;; Checks if the contract hash matches the expected hash
(define-read-only (verify-contract-hash (contract-principal principal) (expected-hash (buff 32)))
  (let ((contract-hash-result (contract-hash? contract-principal)))
    (match contract-hash-result
      hash (ok (is-eq hash expected-hash))
      err-code (ok false)
    )
  )
)
