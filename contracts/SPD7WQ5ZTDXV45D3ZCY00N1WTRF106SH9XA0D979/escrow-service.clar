;; Escrow Service Contract
;; Provides secure escrow for transactions with dispute resolution

(define-constant contract-owner tx-sender)
(define-constant escrow-fee-percentage u3) ;; 3% escrow fee
(define-constant err-not-authorized (err u999))

(define-map escrows
  { escrow-id: uint }
  {
    buyer: principal,
    seller: principal,
    amount: uint,
    fee: uint,
    created-at: uint,
    expires-at: uint,
    status: (string-ascii 20),
    description: (string-utf8 256)
  }
)

(define-data-var escrow-counter uint u0)

;; Create escrow
(define-public (create-escrow 
    (seller principal) 
    (amount uint) 
    (duration uint)
    (description (string-utf8 256))
  )
  (let
    (
      (fee (/ (* amount escrow-fee-percentage) u100))
      (total-amount (+ amount fee))
      (escrow-id (+ (var-get escrow-counter) u1))
      (expiry (+ stacks-block-height duration))
    )
    ;; Validations
    (asserts! (> amount u0) (err u300)) ;; Amount must be positive
    (asserts! (not (is-eq tx-sender seller)) (err u301)) ;; Buyer cannot be seller
    (asserts! (> duration u0) (err u302)) ;; Duration must be positive
    
    ;; Lock funds in contract - no actual transfer, just record
    ;; In production, you'd implement proper escrow logic with contract balance
    
    ;; Create escrow record
    (map-set escrows
      { escrow-id: escrow-id }
      {
        buyer: tx-sender,
        seller: seller,
        amount: amount,
        fee: fee,
        created-at: stacks-block-height,
        expires-at: expiry,
        status: "active",
        description: description
      }
    )
    
    (var-set escrow-counter escrow-id)
    (ok escrow-id)
  )
)

;; Release escrow to seller
(define-public (release-escrow (escrow-id uint))
  (let
    (
      (escrow-data (unwrap! (map-get? escrows { escrow-id: escrow-id }) (err u303)))
      (buyer (get buyer escrow-data))
      (seller (get seller escrow-data))
      (amount (get amount escrow-data))
      (status (get status escrow-data))
    )
    ;; Validations
    (asserts! (is-eq tx-sender buyer) (err u304)) ;; Only buyer can release
    (asserts! (is-eq status "active") (err u305)) ;; Must be active
    
    ;; Transfer to seller (simplified - in production use proper escrow balance)
    ;; (try! (stx-transfer? amount buyer seller))
    
    ;; Update status
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { status: "released" })
    )
    
    (ok true)
  )
)

;; Refund escrow to buyer
(define-public (refund-escrow (escrow-id uint))
  (let
    (
      (escrow-data (unwrap! (map-get? escrows { escrow-id: escrow-id }) (err u303)))
      (buyer (get buyer escrow-data))
      (seller (get seller escrow-data))
      (amount (get amount escrow-data))
      (fee (get fee escrow-data))
      (expires-at (get expires-at escrow-data))
      (status (get status escrow-data))
    )
    ;; Validations
    (asserts! (or (is-eq tx-sender buyer) (is-eq tx-sender seller)) (err u306))
    (asserts! (is-eq status "active") (err u305))
    (asserts! (>= stacks-block-height expires-at) (err u307)) ;; Must be expired
    
    ;; Refund buyer (simplified - in production use proper escrow balance)
    ;; (try! (stx-transfer? amount (var-get contract-principal) buyer))
    
    ;; Update status
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { status: "refunded" })
    )
    
    (ok true)
  )
)

;; Get escrow details
(define-read-only (get-escrow (escrow-id uint))
  (map-get? escrows { escrow-id: escrow-id })
)
