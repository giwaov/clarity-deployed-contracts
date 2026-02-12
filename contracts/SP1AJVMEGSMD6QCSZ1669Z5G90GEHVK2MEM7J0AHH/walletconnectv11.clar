;; --------------------------------------------------
;; WalletConnect V11 - Reown Lightning Bridge (HTLC)
;; --------------------------------------------------

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-SWAP-NOT-FOUND (err u4001))
(define-constant ERR-ALREADY-EXISTS (err u4002))
(define-constant ERR-TIMELOCK-NOT-REACHED (err u4003))
(define-constant ERR-UNAUTHORIZED (err u4004))

;; Data Map
(define-map active-swaps
    (buff 32) ;; preimageHash
    {
        amount: uint,
        timelock: uint,
        initiator: principal,
        provider: principal,
        fee: uint
    }
)

;; --- Public Functions for AppKit Integration ---

;; 1. Lock STX for Swap
;; User initiates this from the AppKit UI to start the BTC swap
(define-public (lock-stx-for-lightning
    (hash (buff 32))
    (amount uint)
    (fee uint)
    (timelock uint)
    (provider principal)
  )
  (begin
    ;; Safety checks
    (asserts! (> amount u0) (err u4005))
    (asserts! (is-none (map-get? active-swaps hash)) ERR-ALREADY-EXISTS)
    
    ;; Transfer total (amount + fee) from user to contract
    (try! (stx-transfer? (+ amount fee) tx-sender (as-contract tx-sender)))
    
    (map-set active-swaps hash {
      amount: amount,
      timelock: timelock,
      initiator: tx-sender,
      provider: provider,
      fee: fee
    })
    
    (print { event: "swap-locked", hash: hash, user: tx-sender })
    (ok true)
  )
)

;; 2. Claim STX (Provider must provide the secret preimage)
;; This is called by the Lightning node/provider to get their STX
(define-public (claim-stx-with-secret (preimage (buff 32)))
  (let (
      (hash (sha256 preimage))
      (swap (unwrap! (map-get? active-swaps hash) ERR-SWAP-NOT-FOUND))
      (total-payout (+ (get amount swap) (get fee swap)))
      (provider (get provider swap))
    )
    ;; Only the designated provider can claim
    (asserts! (is-eq tx-sender provider) ERR-UNAUTHORIZED)
    
    ;; Delete first to prevent re-entrancy
    (map-delete active-swaps hash)
    
    ;; Pay the provider
    (try! (as-contract (stx-transfer? total-payout (as-contract tx-sender) provider)))
    
    (print { event: "swap-claimed", hash: hash, provider: provider })
    (ok true)
  )
)

;; 3. Refund (If swap fails and timelock expires)
(define-public (refund-swap (hash (buff 32)))
  (let (
      (swap (unwrap! (map-get? active-swaps hash) ERR-SWAP-NOT-FOUND))
      (total-payout (+ (get amount swap) (get fee swap)))
      (initiator (get initiator swap))
    )
    ;; Check block height (Timelock)
    (asserts! (> burn-block-height (get timelock swap)) ERR-TIMELOCK-NOT-REACHED)
    
    (map-delete active-swaps hash)
    
    ;; Refund the user
    (try! (as-contract (stx-transfer? total-payout (as-contract tx-sender) initiator)))
    
    (ok true)
  )
)

;; --- Read Only for Reown UI ---

(define-read-only (get-swap-status (hash (buff 32)))
    (map-get? active-swaps hash)
)
