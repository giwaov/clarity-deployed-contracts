;; Position NFT - SIP-009 NFT for Time-Locked Positions
;; Extended with rich on-chain metadata

;; Define NFT trait locally
(define-trait nft-trait
  (
    (get-last-token-id () (response uint uint))
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
    (get-owner (uint) (response (optional principal) uint))
    (transfer (uint principal principal) (response bool uint))
  ))

;; Token name
(define-non-fungible-token position uint)

;; Storage
(define-data-var last-token-id uint u0)
(define-data-var token-uri (string-ascii 256) "https://timelock-exchange.com/metadata/")
(define-data-var base-image-uri (string-ascii 256) "https://timelock-exchange.com/nft/")

;; Position metadata stored on-chain
(define-map position-metadata
  uint
  {
    amount: uint,
    asset-type: (string-ascii 10),
    lock-duration: uint,
    created-at: uint,
    unlock-time: uint,
    original-owner: principal,
    transfer-count: uint,
    tier: uint
  }
)

;; Transfer history
(define-map transfer-history
  { token-id: uint, transfer-index: uint }
  { from: principal, to: principal, timestamp: uint }
)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INVALID_METADATA (err u410))

;; SIP-009 Functions

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id)))

(define-read-only (get-token-uri (token-id uint))
  (ok (some (var-get token-uri))))

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? position token-id)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let (
    (metadata (unwrap! (map-get? position-metadata token-id) ERR_NOT_FOUND))
    (current-count (get transfer-count metadata))
  )
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    
    ;; Record transfer history
    (map-set transfer-history
      { token-id: token-id, transfer-index: current-count }
      { from: sender, to: recipient, timestamp: stacks-block-time }
    )
    
    ;; Update transfer count
    (map-set position-metadata token-id 
      (merge metadata { transfer-count: (+ current-count u1) })
    )
    
    (print {
      event: "nft-transferred",
      token-id: token-id,
      from: sender,
      to: recipient,
      transfer-index: current-count,
      timestamp: stacks-block-time
    })
    
    (nft-transfer? position token-id sender recipient)))

;; Mint function (called by exchange contract)
(define-public (mint (recipient principal))
  (let ((token-id (+ (var-get last-token-id) u1)))
    (try! (nft-mint? position token-id recipient))
    (var-set last-token-id token-id)
    (ok token-id)))

;; Mint with full metadata
(define-public (mint-with-metadata 
  (recipient principal)
  (amount uint)
  (asset-type (string-ascii 10))
  (lock-duration uint)
  (unlock-time uint)
  (tier uint))
  (let ((token-id (+ (var-get last-token-id) u1)))
    (try! (nft-mint? position token-id recipient))
    
    ;; Store metadata
    (map-set position-metadata token-id {
      amount: amount,
      asset-type: asset-type,
      lock-duration: lock-duration,
      created-at: stacks-block-time,
      unlock-time: unlock-time,
      original-owner: recipient,
      transfer-count: u0,
      tier: tier
    })
    
    (var-set last-token-id token-id)
    
    (print {
      event: "position-nft-minted",
      token-id: token-id,
      recipient: recipient,
      amount: amount,
      lock-duration: lock-duration,
      unlock-time: unlock-time,
      tier: tier,
      timestamp: stacks-block-time
    })
    
    (ok token-id)))

;; Burn function (called when position is closed)
(define-public (burn (token-id uint))
  (let ((owner (unwrap! (nft-get-owner? position token-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender owner) ERR_NOT_AUTHORIZED)
    (map-delete position-metadata token-id)
    (print {
      event: "position-nft-burned",
      token-id: token-id,
      owner: owner,
      timestamp: stacks-block-time
    })
    (nft-burn? position token-id owner)))

;; ============================================
;; METADATA READ FUNCTIONS
;; ============================================

;; Get position metadata
(define-read-only (get-position-metadata (token-id uint))
  (map-get? position-metadata token-id))

;; Get full position info including owner
(define-read-only (get-full-position-info (token-id uint))
  (let (
    (metadata (map-get? position-metadata token-id))
    (owner (nft-get-owner? position token-id))
  )
    (match metadata
      meta (some {
        token-id: token-id,
        owner: owner,
        amount: (get amount meta),
        asset-type: (get asset-type meta),
        lock-duration: (get lock-duration meta),
        created-at: (get created-at meta),
        unlock-time: (get unlock-time meta),
        original-owner: (get original-owner meta),
        transfer-count: (get transfer-count meta),
        tier: (get tier meta),
        is-unlockable: (>= stacks-block-time (get unlock-time meta))
      })
      none)))

;; Get transfer history entry
(define-read-only (get-transfer-entry (token-id uint) (transfer-index uint))
  (map-get? transfer-history { token-id: token-id, transfer-index: transfer-index }))

;; Check if position is unlockable
(define-read-only (is-position-unlockable (token-id uint))
  (match (map-get? position-metadata token-id)
    meta (>= stacks-block-time (get unlock-time meta))
    false))

;; Get time remaining until unlock
(define-read-only (get-time-until-unlock (token-id uint))
  (match (map-get? position-metadata token-id)
    meta (if (>= stacks-block-time (get unlock-time meta))
           u0
           (- (get unlock-time meta) stacks-block-time))
    u0))

;; Admin function to update URI
(define-public (set-token-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set token-uri new-uri)
    (ok true)))
