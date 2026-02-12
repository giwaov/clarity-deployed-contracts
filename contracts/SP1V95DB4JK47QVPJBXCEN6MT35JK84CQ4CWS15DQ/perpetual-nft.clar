(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u900))
(define-constant ERR_NFT_NOT_FOUND (err u901))
(define-constant ERR_LOAN_NOT_FOUND (err u902))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u903))

(define-non-fungible-token perpetual-nft uint)

(define-data-var next-nft-id uint u1)
(define-data-var next-loan-id uint u1)

(define-map nft-collateral
  uint
  {
    owner: principal,
    locked-amount: uint,
    locked-at: uint,
    expiry: uint
  }
)

(define-map loans
  uint
  {
    nft-id: uint,
    borrower: principal,
    lender: principal,
    loan-amount: uint,
    interest-rate: uint,
    duration: uint,
    start-time: uint,
    repaid: bool
  }
)

(define-read-only (get-contract-hash)
  (contract-hash? .perpetual-nft)
)

(define-read-only (get-nft-collateral (nft-id uint))
  (ok (unwrap! (map-get? nft-collateral nft-id) ERR_NFT_NOT_FOUND))
)

(define-read-only (get-loan (loan-id uint))
  (ok (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
)

(define-public (mint-nft (to principal) (locked-amount uint) (expiry uint))
  (let
    (
      (nft-id (var-get next-nft-id))
    )
    (try! (nft-mint? perpetual-nft nft-id to))
    (map-set nft-collateral nft-id {
      owner: to,
      locked-amount: locked-amount,
      locked-at: stacks-block-time,
      expiry: expiry
    })
    (var-set next-nft-id (+ nft-id u1))
    (ok nft-id)
  )
)

(define-public (collateralize 
  (nft-id uint)
  (loan-amount uint)
  (interest-rate uint)
  (duration uint)
  (lender principal)
)
  (let
    (
      (loan-id (var-get next-loan-id))
      (collateral-data (unwrap! (map-get? nft-collateral nft-id) ERR_NFT_NOT_FOUND))
    )
    (asserts! (is-eq (get owner collateral-data) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (>= (get locked-amount collateral-data) loan-amount) ERR_INSUFFICIENT_COLLATERAL)
    (map-set loans loan-id {
      nft-id: nft-id,
      borrower: tx-sender,
      lender: lender,
      loan-amount: loan-amount,
      interest-rate: interest-rate,
      duration: duration,
      start-time: stacks-block-time,
      repaid: false
    })
    (var-set next-loan-id (+ loan-id u1))
    (ok loan-id)
  )
)

(define-public (repay-loan (loan-id uint))
  (let
    (
      (loan-data (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
      (total-repayment (+ (get loan-amount loan-data) 
        (/ (* (get loan-amount loan-data) (get interest-rate loan-data)) u100)))
    )
    (asserts! (is-eq (get borrower loan-data) tx-sender) ERR_NOT_AUTHORIZED)
    (try! (stx-transfer? total-repayment tx-sender (get lender loan-data)))
    (map-set loans loan-id (merge loan-data {repaid: true}))
    (ok true)
  )
)

(define-read-only (view-repay-amount (loan-id uint))
  (let
    (
      (loan-data (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
    )
    (ok (+ (get loan-amount loan-data) 
      (/ (* (get loan-amount loan-data) (get interest-rate loan-data)) u100)))
  )
)

(define-read-only (get-loan-terms (loan-id uint))
  (ok (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
)

(define-read-only (verify-secp256r1 (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (ok (secp256r1-verify message signature public-key))
)

(define-read-only (get-timestamp)
  stacks-block-time
)
