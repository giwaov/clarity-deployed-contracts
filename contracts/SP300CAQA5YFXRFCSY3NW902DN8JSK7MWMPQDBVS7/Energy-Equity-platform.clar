;; title: Energy-Equity-platform
;; Renewable Energy Investment DAO Smart Contract
;; 
;; A decentralized autonomous organization enabling fractional investment in renewable 
;; energy infrastructure. Investors can acquire ownership shares in solar, wind, hydro, 
;; and biomass projects, receive proportional revenue distributions from energy production,
;; and participate in community governance decisions regarding asset management and operations.
;;
;; Key Features:
;; - Fractional ownership through tokenized shares
;; - Automated revenue distribution proportional to holdings
;; - Democratic governance with voting rights based on stake
;; - Transparent performance tracking and environmental impact metrics
;; - Geographic tracking of physical assets
;; - Multi-asset portfolio management

;; Administrative and system configuration constants
(define-constant contract-owner tx-sender)
(define-constant minimum-project-value u1000000)
(define-constant voting-power-precision u1000000)
(define-constant proposal-approval-requirement u75)
(define-constant maintenance-review-interval u144)
(define-constant maximum-asset-count u1000000)

;; Error codes for access control and authorization
(define-constant ERR-UNAUTHORIZED-ACCESS (err u401))
(define-constant ERR-INSUFFICIENT-VOTING-POWER (err u405))

;; Error codes for asset and investment operations
(define-constant ERR-ASSET-ALREADY-REGISTERED (err u402))
(define-constant ERR-INVALID-INVESTMENT (err u403))
(define-constant ERR-ASSET-NOT-FOUND (err u404))
(define-constant ERR-INSUFFICIENT-SHARES (err u405))
(define-constant ERR-TRANSFER-FAILED (err u406))
(define-constant ERR-RECORD-NOT-FOUND (err u407))
(define-constant ERR-INVALID-ASSET-NAME (err u408))
(define-constant ERR-UNSUPPORTED-ENERGY-TYPE (err u409))
(define-constant ERR-INVALID-RECIPIENT (err u410))
(define-constant ERR-SELF-TRANSFER-NOT-ALLOWED (err u411))
(define-constant ERR-ZERO-SHARES (err u412))
(define-constant ERR-INVALID-ASSET-STATE (err u416))
(define-constant ERR-INVALID-ASSET-IDENTIFIER (err u418))

;; Error codes for governance and proposals
(define-constant ERR-PROPOSAL-ACTIVE (err u413))
(define-constant ERR-VOTING-PERIOD-ENDED (err u414))
(define-constant ERR-ALREADY-VOTED (err u415))
(define-constant ERR-QUORUM-NOT-MET (err u417))
(define-constant ERR-INVALID-PROPOSAL-TYPE (err u419))
(define-constant ERR-INVALID-DESCRIPTION (err u420))
(define-constant ERR-INVALID-FUNDING-REQUEST (err u421))

;; Trait interface for asset ownership and revenue operations
(define-trait renewable-asset-operations
  (
    (transfer-ownership (uint principal uint) (response bool uint))
    (claim-revenue (uint) (response uint uint))
  )
)

;; Core asset registry containing all renewable energy project metadata
;; Stores project details, share information, revenue data, and operational status
(define-map energy-asset-registry
    { asset-id: uint }
    {
        name: (string-ascii 50),
        energy-type: (string-ascii 20),
        total-shares: uint,
        available-shares: uint,
        share-price: uint,
        accumulated-revenue: uint,
        revenue-per-share: uint,
        status: (string-ascii 10),
        created-at: uint,
        updated-at: uint,
        location: {
            latitude: int,
            longitude: int
        }
    }
)

;; Shareholder portfolio tracking ownership stakes and revenue claims
;; Maps each investor to their holdings across different assets
(define-map shareholder-portfolio
    { asset-id: uint, holder: principal }
    {
        share-count: uint,
        claimed-revenue: uint,
        last-claim-height: uint,
        voting-weight: uint
    }
)

;; Performance metrics for energy production and operational efficiency
;; Tracks energy output, maintenance costs, ROI, and environmental impact
(define-map asset-performance-metrics
    { asset-id: uint }
    {
        energy-generated: uint,
        operating-hours: uint,
        maintenance-costs: uint,
        efficiency-rating: uint,
        carbon-offset: uint,
        capacity: uint,
        roi: uint
    }
)

;; Governance rules defining voting parameters for each asset
;; Configures quorum requirements, voting periods, and approval thresholds
(define-map governance-rules
    { asset-id: uint }
    {
        quorum-percentage: uint,
        voting-period: uint,
        approval-threshold: uint,
        timelock-period: uint
    }
)

;; Proposal registry for community decision-making
;; Tracks all governance proposals with voting status and execution details
(define-map proposal-registry
    { asset-id: uint, proposal-id: uint }
    {
        proposer: principal,
        category: (string-ascii 20),
        description: (string-ascii 500),
        requested-funds: uint,
        votes-for: uint,
        votes-against: uint,
        status: (string-ascii 10),
        submitted-at: uint,
        voting-ends: uint,
        timelock-duration: uint,
        has-quorum: bool
    }
)

;; Global counters for unique identifier generation
(define-data-var next-asset-id uint u0)
(define-data-var next-proposal-id uint u0)
(define-data-var maintenance-counter uint u0)

;; Validates asset name meets minimum requirements
;; Name must be non-empty and within character limits
(define-private (validate-asset-name (name (string-ascii 50)))
    (let ((name-length (len name)))
        (and 
            (> name-length u0)
            (<= name-length u50)
            (not (is-eq name "")))))

;; Checks if energy type is supported by the platform
;; Only solar, wind, hydro, and biomass are currently accepted
(define-private (validate-energy-type (energy-type (string-ascii 20)))
    (or 
        (is-eq energy-type "solar")
        (is-eq energy-type "wind")
        (is-eq energy-type "hydro")
        (is-eq energy-type "biomass")))

;; Validates recipient for share transfers
;; Prevents transfers to self and contract address
;; (define-private (validate-recipient (recipient principal))
;;     (and
;;         (not (is-eq recipient tx-sender))
;;         (not (is-eq recipient (as-contract tx-sender)))))

;; Calculates proportional voting power based on share ownership
;; Returns voting weight as percentage with precision scaling
(define-private (calculate-voting-weight (shares uint) (total-supply uint))
    (/ (* shares voting-power-precision) total-supply))

;; Verifies asset exists and identifier is within valid range
;; Checks both bounds and registry presence
(define-private (asset-exists (asset-id uint))
    (and
        (> asset-id u0)
        (<= asset-id (var-get next-asset-id))
        (<= asset-id maximum-asset-count)
        (is-some (map-get? energy-asset-registry { asset-id: asset-id }))))

;; Validates proposal category format
;; Ensures category string is properly sized
(define-private (validate-proposal-category (category (string-ascii 20)))
    (let ((length (len category)))
        (and 
            (> length u0)
            (<= length u20))))

;; Validates proposal description content
;; Confirms description meets length requirements
(define-private (validate-description (description (string-ascii 500)))
    (let ((length (len description)))
        (and 
            (> length u0)
            (<= length u500))))

;; Registers a new renewable energy project in the platform
;; Initializes asset with shares, pricing, governance rules, and location data
;; Only creates the asset structure without requiring initial funding
;; Returns the newly assigned asset identifier
(define-public (register-energy-project 
    (name (string-ascii 50))
    (energy-type (string-ascii 20))
    (share-supply uint)
    (share-price uint)
    (lat int)
    (lon int))
    (let ((asset-id (+ (var-get next-asset-id) u1)))
        (asserts! (validate-asset-name name) ERR-INVALID-ASSET-NAME)
        (asserts! (validate-energy-type energy-type) ERR-UNSUPPORTED-ENERGY-TYPE)
        (asserts! (> share-supply u0) ERR-INVALID-INVESTMENT)
        (asserts! (> share-price u0) ERR-INVALID-INVESTMENT)
        (asserts! (>= (* share-price share-supply) minimum-project-value) ERR-INVALID-INVESTMENT)

        (begin
            (map-set energy-asset-registry
                { asset-id: asset-id }
                {
                    name: name,
                    energy-type: energy-type,
                    total-shares: share-supply,
                    available-shares: share-supply,
                    share-price: share-price,
                    accumulated-revenue: u0,
                    revenue-per-share: u0,
                    status: "proposed",
                    created-at: stacks-block-height,
                    updated-at: stacks-block-height,
                    location: {
                        latitude: lat,
                        longitude: lon
                    }
                })
            (map-set asset-performance-metrics
                { asset-id: asset-id }
                {
                    energy-generated: u0,
                    operating-hours: u0,
                    maintenance-costs: u0,
                    efficiency-rating: u100,
                    carbon-offset: u0,
                    capacity: u0,
                    roi: u0
                })
            (map-set governance-rules
                { asset-id: asset-id }
                {
                    quorum-percentage: u50,
                    voting-period: u144,
                    approval-threshold: u75,
                    timelock-period: u72
                })
            (var-set next-asset-id asset-id)
            (ok asset-id))))



;; Submits a governance proposal for community voting
;; Creates a new proposal with category, description, and funding request
;; Requires minimum voting power to prevent spam proposals
;; Returns the newly created proposal identifier
(define-public (create-proposal 
    (asset-id uint)
    (category (string-ascii 20))
    (description (string-ascii 500))
    (funding-request uint))
    (begin
        (asserts! (asset-exists asset-id) ERR-INVALID-ASSET-IDENTIFIER)
        (asserts! (validate-proposal-category category) ERR-INVALID-PROPOSAL-TYPE)
        (asserts! (validate-description description) ERR-INVALID-DESCRIPTION)
        (asserts! (or (is-eq funding-request u0) (> funding-request u0)) ERR-INVALID-FUNDING-REQUEST)

        (let ((proposal-id (+ (var-get next-proposal-id) u1))
              (rules (unwrap! (map-get? governance-rules { asset-id: asset-id })
                                ERR-ASSET-NOT-FOUND))
              (portfolio (unwrap! (map-get? shareholder-portfolio 
                                        { asset-id: asset-id, holder: tx-sender })
                                      ERR-UNAUTHORIZED-ACCESS)))
            (begin
                (asserts! (>= (get voting-weight portfolio) 
                             (/ voting-power-precision u20))
                         ERR-INSUFFICIENT-VOTING-POWER)

                (map-set proposal-registry
                    { asset-id: asset-id, proposal-id: proposal-id }
                    {
                        proposer: tx-sender,
                        category: category,
                        description: description,
                        requested-funds: funding-request,
                        votes-for: u0,
                        votes-against: u0,
                        status: "active",
                        submitted-at: stacks-block-height,
                        voting-ends: (+ stacks-block-height (get voting-period rules)),
                        timelock-duration: (get timelock-period rules),
                        has-quorum: false
                    })
                (var-set next-proposal-id proposal-id)
                (ok proposal-id)))))

;; Retrieves complete information about a specific energy asset
;; Returns all asset metadata including shares, revenue, and location
;; Returns none if asset doesn't exist
(define-read-only (get-asset-details (asset-id uint))
    (if (asset-exists asset-id)
        (map-get? energy-asset-registry { asset-id: asset-id })
        none))

;; Retrieves shareholder portfolio for a specific asset
;; Returns share holdings, claimed revenue, and voting power
;; Returns none if holder has no position
(define-read-only (get-shareholder-position (asset-id uint) (holder principal))
    (if (asset-exists asset-id)
        (map-get? shareholder-portfolio { asset-id: asset-id, holder: holder })
        none))

;; Retrieves performance data for an energy asset
;; Returns production metrics, efficiency, and environmental impact
;; Returns none if asset doesn't exist
(define-read-only (get-performance-data (asset-id uint))
    (if (asset-exists asset-id)
        (map-get? asset-performance-metrics { asset-id: asset-id })
        none))

;; Retrieves governance configuration for an asset
;; Returns voting rules, quorum requirements, and approval thresholds
;; Returns none if asset doesn't exist
(define-read-only (get-governance-config (asset-id uint))
    (if (asset-exists asset-id)
        (map-get? governance-rules { asset-id: asset-id })
        none))

;; Retrieves details of a specific governance proposal
;; Returns proposal information including votes, status, and deadlines
;; Returns none if proposal doesn't exist
(define-read-only (get-proposal-details 
    (asset-id uint)
    (proposal-id uint))
    (if (asset-exists asset-id)
        (map-get? proposal-registry { asset-id: asset-id, proposal-id: proposal-id })
        none))
