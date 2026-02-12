;; Simple Message Board Contract with Clarity v4
;; This contract allows users to read and post messages for a fee in sBTC.

;; Define contract owner
(define-constant CONTRACT_OWNER tx-sender)

;; Define error codes
(define-constant ERR_NOT_ENOUGH_SBTC (err u1004))
(define-constant ERR_NOT_CONTRACT_OWNER (err u1005))
(define-constant ERR_BLOCK_NOT_FOUND (err u1003))
(define-constant ERR_INVALID_SIGNATURE (err u1006))
(define-constant ERR_ASSET_RESTRICTION (err u1007))
(define-constant ERR_CONVERSION_FAILED (err u1008))

;; Define asset restriction settings
(define-data-var assets-restricted bool false)

;; Define a map to store messages
;; Each message has an ID, content, author, Bitcoin block height timestamp, and Stacks block time
(define-map messages
  uint
  {
    message: (string-utf8 280),
    author: principal,
    burn-block-time: uint,
    stacks-block-time: uint,
    signature-verified: bool,
  }
)

;; Map to store verified signatures for messages
(define-map message-signatures
  uint
  {
    signature: (buff 64),
    public-key: (buff 33),
  }
)

;; Counter for total messages
(define-data-var message-count uint u0)

;; Public function to add a new message for 1 satoshi of sBTC
(define-public (add-message (content (string-utf8 280)))
  (let ((id (+ (var-get message-count) u1)))
    ;; Check if assets are restricted
    (asserts! (not (var-get assets-restricted)) ERR_ASSET_RESTRICTION)
    ;; Charge 1 satoshi of sBTC from the caller (user pays the fee but it goes to contract owner)
    (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      transfer u1 contract-caller CONTRACT_OWNER none
    ))
    ;; Store the message with current Bitcoin block height and Stacks block time
    (map-set messages id {
      message: content,
      author: contract-caller,
      burn-block-time: burn-block-height,
      stacks-block-time: stacks-block-time,
      signature-verified: false,
    })
    ;; Update message count
    (var-set message-count id)
    ;; Emit event for the new message
    (print {
      event: "[Stacks Dev Quickstart] New Message",
      message: content,
      id: id,
      author: contract-caller,
      burn-block-time: burn-block-height,
      stacks-block-time: stacks-block-time,
    })
    ;; Return the message ID
    (ok id)
  )
)

;; Withdraw function for contract owner to withdraw accumulated sBTC
(define-public (withdraw-funds)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err u1005))
    ;; For now, just return true since funds go directly to owner
    ;; In a real implementation, you might want to track accumulated fees separately
    (ok true)
  )
)

;; Read-only function to get a message by ID
(define-read-only (get-message (id uint))
  (map-get? messages id)
)

;; Read-only function to get message author
(define-read-only (get-message-author (id uint))
  (get author (map-get? messages id))
)

;; Read-only function to get message count at a specific Stacks block height
(define-read-only (get-message-count-at-block (block uint))
  (ok (at-block
    (unwrap! (get-stacks-block-info? id-header-hash block) ERR_BLOCK_NOT_FOUND)
    (var-get message-count)
  ))
)

;; Clarity v4 Functions

;; Function to get the hash of this contract using contract-hash?
(define-read-only (get-contract-hash)
  (contract-hash? tx-sender)
)

;; Function to toggle asset restrictions
(define-public (toggle-asset-restrictions (restricted bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_CONTRACT_OWNER)
    (var-set assets-restricted restricted)
    ;; Note: restrict-assets? function may not be available in all environments
    ;; For this demo, we're just setting the internal state
    (ok restricted)
  )
)

;; Function to convert message content to ASCII using to-ascii?
(define-read-only (get-message-ascii (id uint))
  (match (get-message id)
    message-data (ok (unwrap-panic (to-ascii? (get message message-data))))
    (err u404)
  )
)

;; Function to get current Stacks block time
(define-read-only (get-current-stacks-time)
  stacks-block-time
)

;; Function to add a message with secp256r1 signature verification
(define-public (add-message-with-signature 
    (content (string-utf8 280))
    (signature (buff 64))
    (public-key (buff 33))
    (message-hash (buff 32))
  )
  (let ((id (+ (var-get message-count) u1)))
    ;; Check if assets are restricted
    (asserts! (not (var-get assets-restricted)) ERR_ASSET_RESTRICTION)
    ;; Verify secp256r1 signature
    (asserts! (secp256r1-verify message-hash signature public-key) ERR_INVALID_SIGNATURE)
    ;; Charge 1 satoshi of sBTC from the caller
    (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      transfer u1 contract-caller CONTRACT_OWNER none
    ))
    ;; Store the message with signature verification
    (map-set messages id {
      message: content,
      author: contract-caller,
      burn-block-time: burn-block-height,
      stacks-block-time: stacks-block-time,
      signature-verified: true,
    })
    ;; Store signature data
    (map-set message-signatures id {
      signature: signature,
      public-key: public-key,
    })
    ;; Update message count
    (var-set message-count id)
    ;; Emit event for the new verified message
    (print {
      event: "[Stacks Dev Quickstart] New Verified Message",
      message: content,
      id: id,
      author: contract-caller,
      burn-block-time: burn-block-height,
      stacks-block-time: stacks-block-time,
      signature-verified: true,
    })
    ;; Return the message ID
    (ok id)
  )
)

;; Function to get signature data for a message
(define-read-only (get-message-signature (id uint))
  (map-get? message-signatures id)
)

;; Function to verify if a message has a valid signature
(define-read-only (is-message-signature-valid (id uint) (message-hash (buff 32)))
  (match (map-get? message-signatures id)
    signature-data 
      (secp256r1-verify 
        message-hash 
        (get signature signature-data) 
        (get public-key signature-data)
      )
    false
  )
)

;; Function to get contract information including hash
(define-read-only (get-contract-info)
  {
    hash: (contract-hash? tx-sender),
    owner: CONTRACT_OWNER,
    assets-restricted: (var-get assets-restricted),
    message-count: (var-get message-count),
    current-stacks-time: stacks-block-time,
  }
)