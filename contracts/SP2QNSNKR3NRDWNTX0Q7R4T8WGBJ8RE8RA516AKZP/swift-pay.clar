
;; SwiftPay Engine - Robust Payment Streaming
;; Supports STX and SIP-010 tokens with NFT-based ownership

(use-trait sip-010 .sip-010-trait.sip-010-trait)

;; Error Codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-PARAMS (err u101))
(define-constant ERR-STREAM-NOT-FOUND (err u102))
(define-constant ERR-STREAM-CANCELLED (err u103))
(define-constant ERR-ALREADY-WITHDRAWN (err u104))
(define-constant ERR-PAUSED (err u105))

;; Constants
(define-constant CONTRACT-OWNER tx-sender)

;; Data Vars
(define-data-var next-stream-id uint u0)
(define-data-var is-paused bool false)
(define-data-var protocol-fee-percent uint u1) ;; 1% fee

;; Data Maps
(define-map streams 
    uint 
    {
        sender: principal,
        token-contract: (optional principal), ;; none for STX
        amount-total: uint,
        amount-withdrawn: uint,
        start-block: uint,
        stop-block: uint,
        is-cancelled: bool
    }
)

;; Authorization checks
(define-private (is-owner)
    (is-eq tx-sender CONTRACT-OWNER)
)

;; Read-Only Functions

(define-read-only (get-stream (stream-id uint))
    (map-get? streams stream-id)
)

(define-read-only (calculate-earned (stream-id uint))
    (let (
        (stream (unwrap! (map-get? streams stream-id) ERR-STREAM-NOT-FOUND))
        (current-height block-height)
    )
    (if (<= current-height (get start-block stream))
        (ok u0)
        (if (>= current-height (get stop-block stream))
            (ok (get amount-total stream))
            (let (
                (duration (- (get stop-block stream) (get start-block stream)))
                (elapsed (- current-height (get start-block stream)))
                ;; Using multiplication before division for precision
                (earned (/ (* (get amount-total stream) elapsed) duration))
            )
            (ok earned))
        )
    )
    )
)

;; Get the current recipient of a stream (from the NFT)
(define-read-only (get-recipient (stream-id uint))
    (contract-call? .swift-pay-nft get-owner stream-id)
)

;; Public Functions

;; Admin/Owner functions
(define-public (set-paused (paused bool))
    (begin
        (asserts! (is-owner) ERR-NOT-AUTHORIZED)
        (ok (var-set is-paused paused))
    )
)

;; Create STX stream
(define-public (create-stx-stream (recipient principal) (amount uint) (start-block uint) (stop-block uint))
    (let (
        (stream-id (var-get next-stream-id))
        (contract-addr (as-contract tx-sender))
    )
        (asserts! (not (var-get is-paused)) ERR-PAUSED)
        (asserts! (> amount u0) ERR-INVALID-PARAMS)
        (asserts! (> stop-block start-block) ERR-INVALID-PARAMS)
        (asserts! (>= start-block block-height) ERR-INVALID-PARAMS)

        ;; Transfer STX to contract
        (try! (stx-transfer? amount tx-sender contract-addr))

        ;; Record stream
        (map-set streams stream-id {
            sender: tx-sender,
            token-contract: none,
            amount-total: amount,
            amount-withdrawn: u0,
            start-block: start-block,
            stop-block: stop-block,
            is-cancelled: false
        })

        ;; Mint NFT to recipient
        (try! (contract-call? .swift-pay-nft mint recipient stream-id))

        (var-set next-stream-id (+ stream-id u1))
        (ok stream-id)
    )
)

;; Create SIP-010 stream
(define-public (create-ft-stream (token <sip-010>) (recipient principal) (amount uint) (start-block uint) (stop-block uint))
    (let (
        (stream-id (var-get next-stream-id))
        (contract-addr (as-contract tx-sender))
        (token-addr (contract-of token))
    )
        (asserts! (not (var-get is-paused)) ERR-PAUSED)
        (asserts! (> amount u0) ERR-INVALID-PARAMS)
        (asserts! (> stop-block start-block) ERR-INVALID-PARAMS)
        (asserts! (>= start-block block-height) ERR-INVALID-PARAMS)

        ;; Transfer tokens to contract
        (try! (contract-call? token transfer amount tx-sender contract-addr none))

        ;; Record stream
        (map-set streams stream-id {
            sender: tx-sender,
            token-contract: (some token-addr),
            amount-total: amount,
            amount-withdrawn: u0,
            start-block: start-block,
            stop-block: stop-block,
            is-cancelled: false
        })

        ;; Mint NFT to recipient
        (try! (contract-call? .swift-pay-nft mint recipient stream-id))

        (var-set next-stream-id (+ stream-id u1))
        (ok stream-id)
    )
)

;; Withdraw from stream
(define-public (withdraw (stream-id uint) (token-opt (optional <sip-010>)))
    (let (
        (stream (unwrap! (map-get? streams stream-id) ERR-STREAM-NOT-FOUND))
        (recipient (unwrap! (unwrap! (get-recipient stream-id) ERR-STREAM-NOT-FOUND) ERR-NOT-AUTHORIZED))
        (earned (unwrap! (calculate-earned stream-id) ERR-STREAM-NOT-FOUND))
        (withdrawable (- earned (get amount-withdrawn stream)))
    )
        (asserts! (not (get is-cancelled stream)) ERR-STREAM-CANCELLED)
        (asserts! (is-eq tx-sender recipient) ERR-NOT-AUTHORIZED)
        (asserts! (> withdrawable u0) ERR-ALREADY-WITHDRAWN)

        ;; Update stream
        (map-set streams stream-id (merge stream { amount-withdrawn: earned }))

        ;; Payout
        (match (get token-contract stream)
            t-addr (let ((token (unwrap! token-opt ERR-INVALID-PARAMS)))
                (asserts! (is-eq (contract-of token) t-addr) ERR-INVALID-PARAMS)
                (try! (as-contract (contract-call? token transfer withdrawable tx-sender recipient none)))
            )
            (try! (as-contract (stx-transfer? withdrawable tx-sender recipient)))
        )
        (ok withdrawable)
    )
)

;; Cancel stream
(define-public (cancel (stream-id uint) (token-opt (optional <sip-010>)))
    (let (
        (stream (unwrap! (map-get? streams stream-id) ERR-STREAM-NOT-FOUND))
        (sender (get sender stream))
        (recipient (unwrap! (unwrap! (get-recipient stream-id) ERR-STREAM-NOT-FOUND) ERR-NOT-AUTHORIZED))
        (earned (unwrap! (calculate-earned stream-id) ERR-STREAM-NOT-FOUND))
        (remaining (- (get amount-total stream) earned))
        (to-recipient (- earned (get amount-withdrawn stream)))
    )
        (asserts! (or (is-eq tx-sender sender) (is-eq tx-sender recipient)) ERR-NOT-AUTHORIZED)
        (asserts! (not (get is-cancelled stream)) ERR-STREAM-CANCELLED)

        ;; Update stream
        (map-set streams stream-id (merge stream { 
            is-cancelled: true,
            amount-withdrawn: earned 
        }))

        ;; Final payouts
        (match (get token-contract stream)
            t-addr (let ((token (unwrap! token-opt ERR-INVALID-PARAMS)))
                (asserts! (is-eq (contract-of token) t-addr) ERR-INVALID-PARAMS)
                (if (> to-recipient u0) 
                    (try! (as-contract (contract-call? token transfer to-recipient tx-sender recipient none)))
                    true
                )
                (if (> remaining u0)
                    (try! (as-contract (contract-call? token transfer remaining tx-sender sender none)))
                    true
                )
            )
            (begin
                (if (> to-recipient u0) 
                    (try! (as-contract (stx-transfer? to-recipient tx-sender recipient)))
                    true
                )
                (if (> remaining u0)
                    (try! (as-contract (stx-transfer? remaining tx-sender sender)))
                    true
                )
            )
        )

        ;; Burn NFT
        (try! (contract-call? .swift-pay-nft burn stream-id))

        (ok true)
    )
)
;; Final polish
