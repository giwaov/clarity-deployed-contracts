;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;;                               CaracolSwap                                 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 

;; Storage
(define-map offers-map
  uint
  {
    txid: (buff 32),
    index: uint,
    amount: uint,
    output: (buff 128),
    sender: principal,
    recipient: principal,
  }
)

(define-map offers-accepted-map uint bool)
(define-map offers-cancelled-map uint uint)
(define-map offers-refunded-map uint bool)

(define-data-var last-id-var uint u0)

;; Constants
(define-constant ERR_TX_NOT_MINED (err u100))
(define-constant ERR_INVALID_TX (err u101))
(define-constant ERR_INVALID_OFFER (err u102))
(define-constant ERR_OFFER_MISMATCH (err u103))
(define-constant ERR_OFFER_ACCEPTED (err u104))
(define-constant ERR_OFFER_CANCELLED (err u105))
(define-constant ERR_NOT_AUTHORIZED (err u106))

;; Public Functions
(define-public (create-offer
    (txid (buff 32))
    (index uint)
    (amount uint)
    (output (buff 128))
    (recipient principal)
  )
  (let ((id (make-next-id)))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-insert offers-map id {
      txid: txid,
      index: index,
      amount: amount,
      output: output,
      sender: tx-sender,
      recipient: recipient,
    })
    (print {
      topic: "new-offer",
      offer: {
        id: id,
        txid: txid,
        index: index,
        amount: amount,
        output: output,
        sender: tx-sender,
        recipient: recipient,
      },
    })
    (ok id)
  )
)

(define-public (finalize-offer
    (block { header: (buff 80), height: uint })
    (prev-blocks (list 10 (buff 80)))
    (tx (buff 1024))
    (proof { tx-index: uint, hashes: (list 12 (buff 32)), tree-depth: uint })
    (output-index uint)
    (input-index uint)
    (offer-id uint)
  )
  (let (
      (offer (try! (validate-offer-transfer block prev-blocks tx proof input-index output-index offer-id)))
      (amount (get amount offer))
      (seller (get recipient offer))
    )
    (asserts! (map-insert offers-accepted-map offer-id true) ERR_OFFER_ACCEPTED)
    (try! (as-contract (stx-transfer? amount tx-sender seller)))
    (print {
      topic: "offer-finalized",
      offer: (merge offer { id: offer-id }),
      txid: (contract-call? 'SP1WN90HKT0E1FWCJT9JFPMC8YP7XGBGFNZGHRVZX.clarity-bitcoin get-txid tx),
    })
    (ok offer-id)
  )
)

(define-public (cancel-offer (id uint))
  (let ((offer (unwrap! (map-get? offers-map id) ERR_INVALID_OFFER)))
    (asserts! (is-eq (get sender offer) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (map-insert offers-cancelled-map id (+ burn-block-height u50)) ERR_OFFER_CANCELLED)
    (print {
      topic: "offer-cancelled",
      offer: (merge offer { id: id }),
    })
    (ok true)
  )
)

(define-public (refund-cancelled-offer (id uint))
  (let (
      (offer (unwrap! (map-get? offers-map id) ERR_INVALID_OFFER))
      (amount (get amount offer))
      (cancelled-at (unwrap! (map-get? offers-cancelled-map id) ERR_INVALID_OFFER))
    )
    (asserts! (> burn-block-height cancelled-at) ERR_OFFER_CANCELLED)
    (asserts! (map-insert offers-refunded-map id true) ERR_INVALID_OFFER)
    (try! (as-contract (stx-transfer? amount tx-sender (get sender offer))))
    (print {
      topic: "offer-refunded",
      offer: (merge offer { id: id }),
    })
    (ok id)
  )
)

;; Read-only Functions
(define-read-only (validate-offer-transfer
    (block { header: (buff 80), height: uint })
    (prev-blocks (list 10 (buff 80)))
    (tx (buff 1024))
    (proof { tx-index: uint, hashes: (list 12 (buff 32)), tree-depth: uint })
    (input-index uint)
    (output-index uint)
    (offer-id uint)
  )
  (let (
      (was-mined-bool (unwrap! (contract-call? 'SP1WN90HKT0E1FWCJT9JFPMC8YP7XGBGFNZGHRVZX.clarity-bitcoin was-tx-mined-prev? block prev-blocks tx proof) ERR_TX_NOT_MINED))
      (parsed-tx (unwrap! (contract-call? 'SP1WN90HKT0E1FWCJT9JFPMC8YP7XGBGFNZGHRVZX.clarity-bitcoin parse-tx tx) ERR_INVALID_TX))
      (output (unwrap! (element-at (get outs parsed-tx) output-index) ERR_INVALID_TX))
      (offer (unwrap! (map-get? offers-map offer-id) ERR_INVALID_OFFER))
      (input (get outpoint (unwrap! (element-at (get ins parsed-tx) input-index) ERR_INVALID_TX)))
      (input-txid (get hash input))
      (input-idx (get index input))
    )
    (asserts! (is-eq input-txid (get txid offer)) ERR_OFFER_MISMATCH)
    (asserts! (is-eq input-idx (get index offer)) ERR_OFFER_MISMATCH)
    (asserts! (is-eq (get scriptPubKey output) (get output offer)) ERR_OFFER_MISMATCH)
    (asserts! (is-none (map-get? offers-accepted-map offer-id)) ERR_OFFER_ACCEPTED)
    (match (map-get? offers-cancelled-map offer-id)
      cancelled-at (if (< burn-block-height cancelled-at)
        (ok offer)
        ERR_OFFER_CANCELLED
      )
      (ok offer)
    )
  )
)

(define-read-only (get-offer (id uint)) (map-get? offers-map id))
(define-read-only (get-offer-accepted (id uint)) (map-get? offers-accepted-map id))
(define-read-only (get-offer-cancelled (id uint)) (map-get? offers-cancelled-map id))
(define-read-only (get-offer-refunded (id uint)) (map-get? offers-refunded-map id))
(define-read-only (get-last-id) (var-get last-id-var))

;; Private Functions
(define-private (make-next-id)
  (let ((last-id (var-get last-id-var)))
    (var-set last-id-var (+ last-id u1))
    last-id
  )
)
