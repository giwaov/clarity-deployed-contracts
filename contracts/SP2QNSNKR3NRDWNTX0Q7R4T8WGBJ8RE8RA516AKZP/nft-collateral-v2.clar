;; NFT Collateral Contract
;; Accept SIP-009 NFTs as loan collateral

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u600))
(define-constant err-not-found (err u601))
(define-constant err-unauthorized (err u602))
(define-constant err-nft-locked (err u603))
(define-constant err-invalid-nft (err u604))
(define-constant err-insufficient-value (err u605))

;; Liquidation threshold: 80% LTV
(define-constant liquidation-threshold u8000)

;; Data Variables
(define-data-var loan-nonce uint u0)

;; Data Maps
(define-map nft-loans
  { loan-id: uint }
  {
    borrower: principal,
    lender: principal,
    nft-contract: principal,
    nft-id: uint,
    loan-amount: uint,
    nft-value: uint,
    interest-rate: uint,
    start-block: uint,
    due-block: uint,
    repaid: bool,
    liquidated: bool
  }
)

(define-map nft-valuations
  { nft-contract: principal }
  {
    floor-price: uint,
    last-updated: uint,
    oracle: principal
  }
)

(define-map locked-nfts
  { nft-contract: principal, nft-id: uint }
  { loan-id: uint, locked: bool }
)

;; Read-only functions
(define-read-only (get-nft-loan (loan-id uint))
  (map-get? nft-loans { loan-id: loan-id })
)

(define-read-only (get-nft-valuation (nft-contract principal))
  (map-get? nft-valuations { nft-contract: nft-contract })
)

(define-read-only (is-nft-locked (nft-contract principal) (nft-id uint))
  (default-to false
    (get locked (map-get? locked-nfts { nft-contract: nft-contract, nft-id: nft-id })))
)

(define-read-only (calculate-max-loan (nft-contract principal))
  (let
    (
      (valuation (unwrap! (get-nft-valuation nft-contract) (err err-not-found)))
      (floor-price (get floor-price valuation))
    )
    ;; Max loan = 50% of floor price
    (ok (/ floor-price u2))
  )
)

(define-read-only (get-loan-health (loan-id uint))
  (let
    (
      (loan (unwrap! (get-nft-loan loan-id) (err err-not-found)))
      (nft-value (get nft-value loan))
      (loan-amount (get loan-amount loan))
    )
    ;; Health = (nft-value / loan-amount) * 10000
    (ok (/ (* nft-value u10000) loan-amount))
  )
)

;; Public functions

;; Set NFT floor price (oracle only)
(define-public (set-nft-valuation 
  (nft-contract principal)
  (floor-price uint)
  (oracle principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set nft-valuations
      { nft-contract: nft-contract }
      {
        floor-price: floor-price,
        last-updated: stacks-block-height,
        oracle: oracle
      }
    )
    (ok true)
  )
)

;;  Create loan with NFT collateral
(define-public (create-nft-loan
  (nft-contract <nft-trait>)
  (nft-id uint)
  (loan-amount uint)
  (interest-rate uint)
  (duration uint)
  (lender principal))
  (let
    (
      (loan-id (var-get loan-nonce))
      (nft-contract-principal (contract-of nft-contract))
      (valuation (unwrap! (get-nft-valuation nft-contract-principal) err-invalid-nft))
      (floor-price (get floor-price valuation))
      (max-loan (/ floor-price u2))
    )
    (asserts! (<= loan-amount max-loan) err-insufficient-value)
    (asserts! (not (is-nft-locked nft-contract-principal nft-id)) err-nft-locked)
    
    ;; Transfer NFT to lender as collateral
    (try! (contract-call? nft-contract transfer nft-id tx-sender lender))
    
    ;; Lock NFT
    (map-set locked-nfts
      { nft-contract: nft-contract-principal, nft-id: nft-id }
      { loan-id: loan-id, locked: true }
    )
    
    ;; Transfer loan from lender to borrower
    (try! (stx-transfer? loan-amount lender tx-sender))
    
    ;; Create loan record
    (map-set nft-loans
      { loan-id: loan-id }
      {
        borrower: tx-sender,
        lender: lender,
        nft-contract: nft-contract-principal,
        nft-id: nft-id,
        loan-amount: loan-amount,
        nft-value: floor-price,
        interest-rate: interest-rate,
        start-block: stacks-block-height,
        due-block: (+ stacks-block-height duration),
        repaid: false,
        liquidated: false
      }
    )
    
    (var-set loan-nonce (+ loan-id u1))
    (ok loan-id)
  )
)

;; Repay NFT loan and get NFT back
(define-public (repay-nft-loan (loan-id uint) (nft-contract <nft-trait>))
  (let
    (
      (loan (unwrap! (get-nft-loan loan-id) err-not-found))
      (principal-amount (get loan-amount loan))
      (blocks-elapsed (- stacks-block-height (get start-block loan)))
      (interest-rate (get interest-rate loan))
      (interest (/ (* (* principal-amount interest-rate) blocks-elapsed) u525600000))
      (total-repayment (+ principal-amount interest))
    )
    (asserts! (is-eq tx-sender (get borrower loan)) err-unauthorized)
    (asserts! (not (get repaid loan)) err-not-found)
    (asserts! (not (get liquidated loan)) err-not-found)
    
    ;; Transfer repayment to lender
    (try! (stx-transfer? total-repayment tx-sender (get lender loan)))
    
    ;; Lender returns NFT to borrower
    (try! (contract-call? nft-contract transfer 
                        (get nft-id loan) 
                        (get lender loan)
                        (get borrower loan)))
    
    ;; Unlock NFT
    (map-set locked-nfts
      { nft-contract: (get nft-contract loan), nft-id: (get nft-id loan) }
      { loan-id: loan-id, locked: false }
    )
    
    ;; Mark as repaid
    (map-set nft-loans
      { loan-id: loan-id }
      (merge loan { repaid: true })
    )
    
    (ok total-repayment)
  )
)

;; Liquidate undercollateralized NFT loan
(define-public (liquidate-nft-loan (loan-id uint))
  (let
    (
      (loan (unwrap! (get-nft-loan loan-id) err-not-found))
      (health (unwrap! (get-loan-health loan-id) err-not-found))
    )
    (asserts! (< health liquidation-threshold) err-insufficient-value)
    (asserts! (not (get repaid loan)) err-not-found)
    (asserts! (not (get liquidated loan)) err-not-found)
    
    ;; NFT already with lender, just mark as liquidated
    ;; Unlock NFT
    (map-set locked-nfts
      { nft-contract: (get nft-contract loan), nft-id: (get nft-id loan) }
      { loan-id: loan-id, locked: false }
    )
    
    ;; Mark as liquidated
    (map-set nft-loans
      { loan-id: loan-id }
      (merge loan { liquidated: true })
    )
    
    (ok true)
  )
)

;; NFT trait
(define-trait nft-trait
  (
    (transfer (uint principal principal) (response bool uint))
    (get-owner (uint) (response (optional principal) uint))
  )
)
