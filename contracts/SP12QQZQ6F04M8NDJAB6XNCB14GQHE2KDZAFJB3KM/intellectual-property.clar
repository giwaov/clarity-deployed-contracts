;; title: intellectual-property
;; version:
;; summary:
;; description:

;; title: Quantum-Technology
;; version:
;; Quantum Technology Intellectual Property Marketplace Smart Contract
;; A comprehensive decentralized platform for quantum technology intellectual property
;; commercialization, enabling researchers and companies to monetize quantum innovations
;; through secure licensing agreements, automated royalty distributions, and transparent
;; IP management with built-in compliance and verification mechanisms

;; Error constants for validation and authorization
(define-constant contract-administrator tx-sender)
(define-constant ERR-UNAUTHORIZED-OPERATION (err u100))
(define-constant ERR-QUANTUM-IP-NOT-FOUND (err u101))
(define-constant ERR-DUPLICATE-IP-REGISTRATION (err u102))
(define-constant ERR-INVALID-INPUT-PARAMETERS (err u103))
(define-constant ERR-LICENSE-CONTRACT-EXPIRED (err u104))
(define-constant ERR-INSUFFICIENT-PAYMENT-BALANCE (err u105))
(define-constant ERR-INVALID-TIME-PERIOD (err u106))
(define-constant ERR-LICENSE-CONTRACT-INACTIVE (err u107))

;; Marketplace configuration constants
(define-constant maximum-royalty-percentage u10000)
(define-constant maximum-marketplace-commission u1000)
(define-constant maximum-licensing-duration u525600)
(define-constant maximum-usage-metrics u1000000000)
(define-constant minimum-positive-amount u1)
(define-constant maximum-technology-title-length u100)
(define-constant maximum-technology-summary-length u500)

;; Marketplace operational state variables
(define-data-var quantum-marketplace-operational bool true)
(define-data-var registered-quantum-technologies-counter uint u0)
(define-data-var active-licensing-contracts-counter uint u0)
(define-data-var marketplace-commission-percentage uint u250)

;; Unique identifier generation counters
(define-data-var next-quantum-technology-identifier uint u1)
(define-data-var next-licensing-contract-identifier uint u1)
(define-data-var next-royalty-transaction-identifier uint u1)

;; Core marketplace data storage structures

;; Quantum technology intellectual property registry
(define-map quantum-technology-database
  { quantum-tech-id: uint }
  {
    technology-owner-address: principal,
    technology-commercial-title: (string-ascii 100),
    technology-detailed-summary: (string-ascii 500),
    base-licensing-cost: uint,
    ongoing-royalty-percentage: uint,
    licensing-availability-status: bool,
    technology-registration-block: uint,
  }
)

;; Licensing contract management registry
(define-map licensing-contract-database
  { licensing-contract-id: uint }
  {
    licensed-technology-reference: uint,
    technology-licensee-address: principal,
    technology-licensor-address: principal,
    contract-activation-block: uint,
    contract-termination-block: uint,
    total-licensing-payment: uint,
    negotiated-royalty-percentage: uint,
    contract-operational-status: bool,
    contract-creation-block: uint,
  }
)

;; Royalty payment transaction registry
(define-map royalty-transaction-database
  { royalty-transaction-id: uint }
  {
    source-licensing-contract: uint,
    payment-sender-address: principal,
    payment-receiver-address: principal,
    transaction-total-amount: uint,
    transaction-processing-block: uint,
    related-technology-reference: uint,
  }
)

;; Technology ownership verification registry
(define-map technology-ownership-database
  {
    owner-address: principal,
    technology-reference: uint,
  }
  { ownership-confirmed: bool }
)

;; Technology access authorization registry
(define-map technology-access-database
  {
    authorized-user-address: principal,
    technology-reference: uint,
  }
  {
    linked-licensing-contract: uint,
    access-permission-active: bool,
  }
)

;; Quantum technology registration and management functions

(define-public (register-quantum-technology
    (technology-title (string-ascii 100))
    (technology-summary (string-ascii 500))
    (licensing-fee uint)
    (royalty-rate uint)
  )
  (let ((new-technology-id (var-get next-quantum-technology-identifier)))
    (asserts! (var-get quantum-marketplace-operational)
      ERR-UNAUTHORIZED-OPERATION
    )
    (asserts! (> licensing-fee minimum-positive-amount)
      ERR-INVALID-INPUT-PARAMETERS
    )
    (asserts! (<= royalty-rate maximum-royalty-percentage)
      ERR-INVALID-INPUT-PARAMETERS
    )
    (asserts!
      (and
        (> (len technology-title) u0)
        (<= (len technology-title) maximum-technology-title-length)
      )
      ERR-INVALID-INPUT-PARAMETERS
    )
    (asserts!
      (and
        (> (len technology-summary) u0)
        (<= (len technology-summary) maximum-technology-summary-length)
      )
      ERR-INVALID-INPUT-PARAMETERS
    )

    (map-set quantum-technology-database { quantum-tech-id: new-technology-id } {
      technology-owner-address: tx-sender,
      technology-commercial-title: technology-title,
      technology-detailed-summary: technology-summary,
      base-licensing-cost: licensing-fee,
      ongoing-royalty-percentage: royalty-rate,
      licensing-availability-status: true,
      technology-registration-block: stacks-block-height,
    })

    (map-set technology-ownership-database {
      owner-address: tx-sender,
      technology-reference: new-technology-id,
    } { ownership-confirmed: true }
    )

    (var-set next-quantum-technology-identifier (+ new-technology-id u1))
    (var-set registered-quantum-technologies-counter
      (+ (var-get registered-quantum-technologies-counter) u1)
    )

    (print {
      marketplace-event: "quantum-technology-registered",
      technology-id: new-technology-id,
      owner-address: tx-sender,
      technology-title: technology-title,
      licensing-cost: licensing-fee,
      royalty-rate: royalty-rate,
    })

    (ok new-technology-id)
  )
)

(define-public (modify-technology-licensing-terms
    (technology-id uint)
    (updated-licensing-fee uint)
    (updated-royalty-rate uint)
    (availability-toggle bool)
  )
  (let ((technology-record (unwrap!
      (map-get? quantum-technology-database { quantum-tech-id: technology-id })
      ERR-QUANTUM-IP-NOT-FOUND
    )))
    (asserts! (var-get quantum-marketplace-operational)
      ERR-UNAUTHORIZED-OPERATION
    )
    (asserts! (> technology-id minimum-positive-amount)
      ERR-INVALID-INPUT-PARAMETERS
    )
    (asserts! (< technology-id (var-get next-quantum-technology-identifier))
      ERR-QUANTUM-IP-NOT-FOUND
    )
    (asserts! (is-eq tx-sender (get technology-owner-address technology-record))
      ERR-UNAUTHORIZED-OPERATION
    )
    (asserts! (> updated-licensing-fee minimum-positive-amount)
      ERR-INVALID-INPUT-PARAMETERS
    )
    (asserts! (<= updated-royalty-rate maximum-royalty-percentage)
      ERR-INVALID-INPUT-PARAMETERS
    )

    (map-set quantum-technology-database { quantum-tech-id: technology-id }
      (merge technology-record {
        base-licensing-cost: updated-licensing-fee,
        ongoing-royalty-percentage: updated-royalty-rate,
        licensing-availability-status: availability-toggle,
      })
    )

    (print {
      marketplace-event: "technology-terms-modified",
      technology-id: technology-id,
      modifier-address: tx-sender,
      new-licensing-fee: updated-licensing-fee,
      new-royalty-rate: updated-royalty-rate,
      availability-status: availability-toggle,
    })

    (ok true)
  )
)

(define-public (revoke-licensing-contract (target-contract-id uint))
  (let ((contract-record (unwrap!
      (map-get? licensing-contract-database { licensing-contract-id: target-contract-id })
      ERR-QUANTUM-IP-NOT-FOUND
    )))
    (asserts! (var-get quantum-marketplace-operational)
      ERR-UNAUTHORIZED-OPERATION
    )
    (asserts! (> target-contract-id minimum-positive-amount)
      ERR-INVALID-INPUT-PARAMETERS
    )
    (asserts! (< target-contract-id (var-get next-licensing-contract-identifier))
      ERR-QUANTUM-IP-NOT-FOUND
    )
    (asserts!
      (or
        (is-eq tx-sender (get technology-licensor-address contract-record))
        (is-eq tx-sender (get technology-licensee-address contract-record))
      )
      ERR-UNAUTHORIZED-OPERATION
    )
    (asserts! (get contract-operational-status contract-record)
      ERR-LICENSE-CONTRACT-INACTIVE
    )

    (map-set licensing-contract-database { licensing-contract-id: target-contract-id }
      (merge contract-record { contract-operational-status: false })
    )

    (map-set technology-access-database {
      authorized-user-address: (get technology-licensee-address contract-record),
      technology-reference: (get licensed-technology-reference contract-record),
    } {
      linked-licensing-contract: target-contract-id,
      access-permission-active: false,
    })

    (print {
      marketplace-event: "licensing-contract-revoked",
      revoked-contract-id: target-contract-id,
      revocation-initiator: tx-sender,
    })

    (ok true)
  )
)

;; Information retrieval and query functions

(define-read-only (retrieve-quantum-technology-information (technology-identifier uint))
  (map-get? quantum-technology-database { quantum-tech-id: technology-identifier })
)

(define-read-only (retrieve-licensing-contract-information (contract-identifier uint))
  (map-get? licensing-contract-database { licensing-contract-id: contract-identifier })
)

(define-read-only (retrieve-royalty-transaction-information (transaction-identifier uint))
  (map-get? royalty-transaction-database { royalty-transaction-id: transaction-identifier })
)

(define-read-only (validate-contract-operational-status (contract-identifier uint))
  (match (map-get? licensing-contract-database { licensing-contract-id: contract-identifier })
    contract-data (and
      (get contract-operational-status contract-data)
      (<= stacks-block-height (get contract-termination-block contract-data))
    )
    false
  )
)

(define-read-only (retrieve-user-technology-access-details
    (user-address principal)
    (technology-identifier uint)
  )
  (map-get? technology-access-database {
    authorized-user-address: user-address,
    technology-reference: technology-identifier,
  })
)

(define-read-only (verify-user-technology-access-authorization
    (user-address principal)
    (technology-identifier uint)
  )
  (match (map-get? technology-access-database {
    authorized-user-address: user-address,
    technology-reference: technology-identifier,
  })
    access-data (match (map-get? licensing-contract-database { licensing-contract-id: (get linked-licensing-contract access-data) })
      contract-data (and
        (get contract-operational-status contract-data)
        (<= stacks-block-height (get contract-termination-block contract-data))
      )
      false
    )
    false
  )
)

(define-read-only (retrieve-marketplace-operational-metrics)
  {
    registered-technologies-total: (var-get registered-quantum-technologies-counter),
    active-contracts-total: (var-get active-licensing-contracts-counter),
    marketplace-commission-rate: (var-get marketplace-commission-percentage),
    marketplace-operational-status: (var-get quantum-marketplace-operational),
    current-blockchain-block: stacks-block-height,
  }
)

;; Administrative control and configuration functions

(define-public (configure-marketplace-commission-rate (new-commission-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-administrator) ERR-UNAUTHORIZED-OPERATION)
    (asserts! (<= new-commission-rate maximum-marketplace-commission)
      ERR-INVALID-INPUT-PARAMETERS
    )
    (var-set marketplace-commission-percentage new-commission-rate)
    (print {
      marketplace-event: "commission-rate-configured",
      updated-rate: new-commission-rate,
    })
    (ok true)
  )
)

(define-public (toggle-marketplace-operational-status)
  (begin
    (asserts! (is-eq tx-sender contract-administrator) ERR-UNAUTHORIZED-OPERATION)
    (var-set quantum-marketplace-operational
      (not (var-get quantum-marketplace-operational))
    )
    (print {
      marketplace-event: "operational-status-toggled",
      operational-status: (var-get quantum-marketplace-operational),
    })
    (ok (var-get quantum-marketplace-operational))
  )
)
