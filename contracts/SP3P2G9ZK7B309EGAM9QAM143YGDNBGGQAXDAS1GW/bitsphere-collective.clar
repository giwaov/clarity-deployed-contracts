;; BitSphere Collective - Decentralized Fund Management Protocol

;; Title: BitSphere Collective
;; 
;; Summary:
;; A sophisticated decentralized autonomous fund management protocol built on Stacks, 
;; enabling Bitcoin-secured collective investment decisions through democratic governance 
;; and transparent fund allocation mechanisms.
;;
;; Description:
;; BitSphere Collective revolutionizes decentralized fund management by leveraging 
;; Bitcoin's security through Stacks' smart contract capabilities. This protocol 
;; empowers communities to pool resources, propose strategic investments, and execute 
;; collective decisions through a robust voting mechanism. Each participant's influence 
;; scales with their commitment, ensuring aligned incentives while maintaining 
;; democratic principles. With built-in security measures, time-locked deposits, and 
;; transparent execution of approved proposals, BitSphere creates a trustless 
;; environment where collective wisdom drives capital allocation in the Bitcoin ecosystem.

;; PROTOCOL CONSTANTS

(define-constant CONTRACT_OWNER tx-sender)

;; Error Constants
(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_NOT_INITIALIZED (err u101))
(define-constant ERR_ALREADY_INITIALIZED (err u102))
(define-constant ERR_INSUFFICIENT_BALANCE (err u103))
(define-constant ERR_INVALID_AMOUNT (err u104))
(define-constant ERR_UNAUTHORIZED (err u105))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u106))
(define-constant ERR_PROPOSAL_EXPIRED (err u107))
(define-constant ERR_ALREADY_VOTED (err u108))
(define-constant ERR_BELOW_MINIMUM (err u109))
(define-constant ERR_LOCKED_PERIOD (err u110))
(define-constant ERR_TRANSFER_FAILED (err u111))
(define-constant ERR_INVALID_DURATION (err u112))
(define-constant ERR_ZERO_AMOUNT (err u113))
(define-constant ERR_INVALID_TARGET (err u114))
(define-constant ERR_INVALID_DESCRIPTION (err u115))
(define-constant ERR_INVALID_PROPOSAL_ID (err u116))

;; Protocol Parameters
(define-constant MINIMUM_PROPOSAL_DURATION u144)    ;; ~1 day (10min blocks)
(define-constant MAXIMUM_PROPOSAL_DURATION u20160)  ;; ~14 days
(define-constant MINIMUM_DEPOSIT_THRESHOLD u1000000) ;; 1 STX in microSTX
(define-constant DEFAULT_LOCK_PERIOD u1440)         ;; ~10 days in blocks
(define-constant MINIMUM_QUORUM_PERCENTAGE u10)     ;; 10% of total supply must vote

;; PROTOCOL STATE VARIABLES

(define-data-var total-supply uint u0)
(define-data-var minimum-deposit uint MINIMUM_DEPOSIT_THRESHOLD)
(define-data-var lock-period uint DEFAULT_LOCK_PERIOD)
(define-data-var protocol-initialized bool false)
(define-data-var proposal-counter uint u0)

;; DATA STRUCTURES

;; Member balance tracking
(define-map member-balances principal uint)

;; Member deposit information with time-lock mechanics
(define-map member-deposits
    principal
    {
        deposit-amount: uint,
        unlock-height: uint,
        entry-block: uint
    }
)

;; Governance proposal structure
(define-map governance-proposals
    uint
    {
        proposer: principal,
        description: (string-ascii 256),
        funding-amount: uint,
        beneficiary: principal,
        expiry-height: uint,
        executed: bool,
        votes-for: uint,
        votes-against: uint
    }
)

;; Vote tracking to prevent double-voting
(define-map member-votes {proposal-id: uint, voter: principal} bool)

;; PRIVATE UTILITY FUNCTIONS

(define-private (is-protocol-owner)
    (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (ensure-initialized)
    (ok (asserts! (var-get protocol-initialized) ERR_NOT_INITIALIZED))
)

(define-private (validate-proposal-id (proposal-id uint))
    (ok (asserts! (and (> proposal-id u0) (<= proposal-id (var-get proposal-counter))) ERR_INVALID_PROPOSAL_ID))
)

(define-private (get-member-voting-power (member principal))
    (default-to u0 (map-get? member-balances member))
)

(define-private (mint-membership-tokens (recipient principal) (amount uint))
    (let (
        (current-balance (default-to u0 (map-get? member-balances recipient)))
    )
        (map-set member-balances recipient (+ current-balance amount))
        (var-set total-supply (+ (var-get total-supply) amount))
        (ok true)
    )
)

(define-private (burn-membership-tokens (holder principal) (amount uint))
    (let (
        (current-balance (default-to u0 (map-get? member-balances holder)))
    )
        (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
        (map-set member-balances holder (- current-balance amount))
        (var-set total-supply (- (var-get total-supply) amount))
        (ok true)
    )
)

;; PROTOCOL INITIALIZATION

(define-public (initialize-protocol)
    (begin
        (asserts! (is-protocol-owner) ERR_OWNER_ONLY)
        (asserts! (not (var-get protocol-initialized)) ERR_ALREADY_INITIALIZED)
        (ok (var-set protocol-initialized true))
    )
)

;; MEMBER DEPOSIT & WITHDRAWAL FUNCTIONS

(define-public (join-collective (deposit-amount uint))
    (begin
        (try! (ensure-initialized))
        (asserts! (>= deposit-amount (var-get minimum-deposit)) ERR_BELOW_MINIMUM)
        (asserts! (> deposit-amount u0) ERR_ZERO_AMOUNT)

        ;; Secure STX transfer to protocol
        (try! (stx-transfer? deposit-amount tx-sender current-contract))
        
        ;; Record or update member deposit with time-lock
        (let (
            (existing-deposit (default-to {deposit-amount: u0, unlock-height: u0, entry-block: u0} 
                (map-get? member-deposits tx-sender)))
        )
            (map-set member-deposits tx-sender {
                deposit-amount: (+ (get deposit-amount existing-deposit) deposit-amount),
                unlock-height: (+ stacks-block-height (var-get lock-period)),
                entry-block: (if (is-eq (get entry-block existing-deposit) u0) 
                    stacks-block-height 
                    (get entry-block existing-deposit))
            })
        )
        
        ;; Issue membership tokens proportional to deposit
        (print {event: "member-joined", member: tx-sender, amount: deposit-amount, block: stacks-block-height})
        (mint-membership-tokens tx-sender deposit-amount)
    )
)

(define-public (exit-collective (withdrawal-amount uint))
    (begin
        (try! (ensure-initialized))
        (asserts! (> withdrawal-amount u0) ERR_ZERO_AMOUNT)

        (let (
            (deposit-info (unwrap! (map-get? member-deposits tx-sender) ERR_UNAUTHORIZED))
            (member-balance (default-to u0 (map-get? member-balances tx-sender)))
        )
            (asserts! (>= stacks-block-height (get unlock-height deposit-info)) ERR_LOCKED_PERIOD)
            (asserts! (>= member-balance withdrawal-amount) ERR_INSUFFICIENT_BALANCE)
            (asserts! (>= (get deposit-amount deposit-info) withdrawal-amount) ERR_INSUFFICIENT_BALANCE)
            
            ;; Update state BEFORE external call (reentrancy protection)
            ;; Burn membership tokens
            (try! (burn-membership-tokens tx-sender withdrawal-amount))
            
            ;; Update deposit record
            (map-set member-deposits tx-sender 
                (merge deposit-info {deposit-amount: (- (get deposit-amount deposit-info) withdrawal-amount)}))
            
            ;; Transfer STX back to member
            (let ((member tx-sender))
                (try! (as-contract? ((with-all-assets-unsafe)) (try! (stx-transfer? withdrawal-amount tx-sender member)))))
            (print {event: "member-exited", member: tx-sender, amount: withdrawal-amount, block: stacks-block-height})
            (ok true)
        )
    )
)

;; GOVERNANCE PROPOSAL SYSTEM

(define-public (submit-proposal
    (description (string-ascii 256))
    (funding-amount uint)
    (beneficiary principal)
    (voting-duration uint)
)
    (begin
        (try! (ensure-initialized))

        ;; Comprehensive input validation
        (asserts! (> (len description) u0) ERR_INVALID_DESCRIPTION)
        (asserts! (> funding-amount u0) ERR_ZERO_AMOUNT)
        (asserts! (not (is-eq beneficiary current-contract)) ERR_INVALID_TARGET)
        (asserts! (and (>= voting-duration MINIMUM_PROPOSAL_DURATION) 
                      (<= voting-duration MAXIMUM_PROPOSAL_DURATION)) ERR_INVALID_DURATION)
        
        (let (
            (proposer-balance (default-to u0 (map-get? member-balances tx-sender)))
            (new-proposal-id (+ (var-get proposal-counter) u1))
        )
            (asserts! (> proposer-balance u0) ERR_UNAUTHORIZED)
            
            ;; Create governance proposal
            (map-set governance-proposals new-proposal-id {
                proposer: tx-sender,
                description: description,
                funding-amount: funding-amount,
                beneficiary: beneficiary,
                expiry-height: (+ stacks-block-height voting-duration),
                executed: false,
                votes-for: u0,
                votes-against: u0
            })
            
            (var-set proposal-counter new-proposal-id)
            (print {event: "proposal-submitted", proposal-id: new-proposal-id, proposer: tx-sender, amount: funding-amount})
            (ok new-proposal-id)
        )
    )
)

(define-public (cast-vote (proposal-id uint) (support bool))
    (begin
        (try! (ensure-initialized))
        (try! (validate-proposal-id proposal-id))

        (let (
            (proposal (unwrap! (map-get? governance-proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
            (voting-power (get-member-voting-power tx-sender))
        )
            (asserts! (> voting-power u0) ERR_UNAUTHORIZED)
            (asserts! (< stacks-block-height (get expiry-height proposal)) ERR_PROPOSAL_EXPIRED)
            (asserts! (is-none (map-get? member-votes {proposal-id: proposal-id, voter: tx-sender})) ERR_ALREADY_VOTED)
            
            ;; Record member vote
            (map-set member-votes {proposal-id: proposal-id, voter: tx-sender} support)
            
            ;; Update proposal vote tallies
            (map-set governance-proposals proposal-id 
                (merge proposal 
                    {
                        votes-for: (if support 
                            (+ (get votes-for proposal) voting-power)
                            (get votes-for proposal)),
                        votes-against: (if support
                            (get votes-against proposal)
                            (+ (get votes-against proposal) voting-power))
                    }
                )
            )
            
            (print {event: "vote-cast", proposal-id: proposal-id, voter: tx-sender, support: support, power: voting-power})
            (ok true)
        )
    )
)

(define-public (execute-approved-proposal (proposal-id uint))
    (begin
        (try! (ensure-initialized))
        (try! (validate-proposal-id proposal-id))

        (let (
            (proposal (unwrap! (map-get? governance-proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
            (available-funds (stx-get-balance current-contract))
        )
            (asserts! (not (get executed proposal)) ERR_UNAUTHORIZED)
            ;; FIXED: Ensure voting period has ENDED (not expired before execution)
            (asserts! (>= stacks-block-height (get expiry-height proposal)) ERR_PROPOSAL_EXPIRED)
            ;; Require simple majority
            (asserts! (> (get votes-for proposal) (get votes-against proposal)) ERR_UNAUTHORIZED)
            ;; Check minimum quorum participation
            (let ((total-votes (+ (get votes-for proposal) (get votes-against proposal))))
                (asserts! (>= (* total-votes u100) (* (var-get total-supply) MINIMUM_QUORUM_PERCENTAGE)) ERR_UNAUTHORIZED)
            )
            (asserts! (>= available-funds (get funding-amount proposal)) ERR_INSUFFICIENT_BALANCE)
            
            ;; Mark proposal as executed BEFORE transfer (reentrancy protection)
            (map-set governance-proposals proposal-id (merge proposal {executed: true}))
            
            ;; Execute approved funding transfer
            (try! (as-contract? ((with-all-assets-unsafe)) (try! (stx-transfer? (get funding-amount proposal) tx-sender (get beneficiary proposal)))))
            
            (print {event: "proposal-executed", proposal-id: proposal-id, amount: (get funding-amount proposal), beneficiary: (get beneficiary proposal)})
            (ok true)
        )
    )
)

;; ADMIN FUNCTIONS

(define-public (update-minimum-deposit (new-minimum uint))
    (begin
        (asserts! (is-protocol-owner) ERR_OWNER_ONLY)
        (asserts! (> new-minimum u0) ERR_ZERO_AMOUNT)
        (var-set minimum-deposit new-minimum)
        (print {event: "minimum-deposit-updated", new-value: new-minimum})
        (ok true)
    )
)

(define-public (update-lock-period (new-period uint))
    (begin
        (asserts! (is-protocol-owner) ERR_OWNER_ONLY)
        (asserts! (> new-period u0) ERR_ZERO_AMOUNT)
        (var-set lock-period new-period)
        (print {event: "lock-period-updated", new-value: new-period})
        (ok true)
    )
)

;; READ-ONLY QUERY FUNCTIONS

(define-read-only (get-member-balance (member principal))
    (ok (default-to u0 (map-get? member-balances member)))
)

(define-read-only (get-total-member-tokens)
    (ok (var-get total-supply))
)

(define-read-only (get-proposal-details (proposal-id uint))
    (ok (map-get? governance-proposals proposal-id))
)

(define-read-only (get-member-deposit-info (member principal))
    (ok (map-get? member-deposits member))
)

(define-read-only (get-member-vote (proposal-id uint) (voter principal))
    (ok (map-get? member-votes {proposal-id: proposal-id, voter: voter}))
)

(define-read-only (get-protocol-status)
    (ok {
        initialized: (var-get protocol-initialized),
        total-proposals: (var-get proposal-counter),
        total-supply: (var-get total-supply),
        contract-balance: (stx-get-balance current-contract)
    })
)