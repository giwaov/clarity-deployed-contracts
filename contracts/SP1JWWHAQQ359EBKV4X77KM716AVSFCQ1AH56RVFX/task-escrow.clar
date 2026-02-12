;; Task Escrow Contract
;; Manages STX payments in escrow for tasks

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-ESCROW-NOT-FOUND (err u201))
(define-constant ERR-ALREADY-RELEASED (err u202))
(define-constant ERR-INSUFFICIENT-FUNDS (err u203))
(define-constant ERR-INVALID-AMOUNT (err u204))
(define-constant ERR-DISPUTE-WINDOW-EXPIRED (err u205))
(define-constant ERR-DISPUTE-ALREADY-OPENED (err u206))
(define-constant ERR-INVALID-PERCENTAGE (err u207))
(define-constant ERR-TRANSFER-FAILED (err u208))

;; Platform fee: 2.5% of task reward
(define-constant PLATFORM-FEE-PERCENT u250) ;; 2.5% = 250/10000

;; Minimum and maximum task rewards (in microSTX)
(define-constant MIN-TASK-REWARD u100000) ;; 0.1 STX
(define-constant MAX-TASK-REWARD u100000000000) ;; 100,000 STX

;; Dispute window: 72 hours in blocks (assuming ~10 min blocks)
(define-constant DISPUTE-WINDOW-BLOCKS u432) ;; 72 hours * 6 blocks/hour

;; Data Variables
(define-data-var platform-fees-collected uint u0)
(define-data-var task-counter uint u0)

;; Data Maps
(define-map escrows
    { task-id: uint }
    {
        creator: principal,
        worker: (optional principal),
        amount: uint,
        deposited-at: uint,
        released: bool,
        dispute-opened: bool,
        dispute-opened-at: (optional uint),
        dispute-resolved: bool
    }
)

;; Authorization map for allowed contract callers
(define-map authorized-contracts principal bool)

;; Initialize authorization
(map-set authorized-contracts CONTRACT-OWNER true)

;; Read-only functions

(define-read-only (get-escrow (task-id uint))
    (ok (map-get? escrows { task-id: task-id }))
)

(define-read-only (get-platform-fees)
    (ok (var-get platform-fees-collected))
)

(define-read-only (calculate-platform-fee (amount uint))
    (ok (/ (* amount PLATFORM-FEE-PERCENT) u10000))
)

(define-read-only (calculate-total-deposit (amount uint))
    (let (
        (platform-fee (/ (* amount PLATFORM-FEE-PERCENT) u10000))
    )
    (ok (+ amount platform-fee)))
)

(define-read-only (is-dispute-window-open (task-id uint))
    (match (map-get? escrows { task-id: task-id })
        escrow-data
        (if (get dispute-opened escrow-data)
            (ok true)
            (ok (< (- block-height (get deposited-at escrow-data)) DISPUTE-WINDOW-BLOCKS))
        )
        (ok false)
    )
)

(define-read-only (is-authorized-contract (contract principal))
    (ok (default-to false (map-get? authorized-contracts contract)))
)

;; Private functions

(define-private (validate-amount (amount uint))
    (and (>= amount MIN-TASK-REWARD) (<= amount MAX-TASK-REWARD))
)

;; Public functions

(define-public (authorize-contract (contract principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (ok (map-set authorized-contracts contract true))
    )
)

(define-public (revoke-contract (contract principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (ok (map-delete authorized-contracts contract))
    )
)

(define-public (deposit-escrow (task-id uint) (amount uint) (creator principal))
    (let (
        (platform-fee (/ (* amount PLATFORM-FEE-PERCENT) u10000))
        (total-amount (+ amount platform-fee))
    )
        ;; Only authorized contracts can call this
        (asserts! (default-to false (map-get? authorized-contracts contract-caller)) ERR-NOT-AUTHORIZED)
        
        ;; Validate amount
        (asserts! (validate-amount amount) ERR-INVALID-AMOUNT)
        
        ;; Transfer STX from creator to this contract
        (try! (stx-transfer? total-amount creator (as-contract tx-sender)))
        
        ;; Update platform fees
        (var-set platform-fees-collected (+ (var-get platform-fees-collected) platform-fee))
        
        ;; Create escrow record
        (ok (map-set escrows 
            { task-id: task-id }
            {
                creator: creator,
                worker: none,
                amount: amount,
                deposited-at: block-height,
                released: false,
                dispute-opened: false,
                dispute-opened-at: none,
                dispute-resolved: false
            }
        ))
    )
)

(define-public (set-worker (task-id uint) (worker principal))
    (begin
        ;; Only authorized contracts can call this
        (asserts! (default-to false (map-get? authorized-contracts contract-caller)) ERR-NOT-AUTHORIZED)
        
        (let (
            (escrow-data (unwrap! (map-get? escrows { task-id: task-id }) ERR-ESCROW-NOT-FOUND))
        )
        
        ;; Ensure not already released
        (asserts! (not (get released escrow-data)) ERR-ALREADY-RELEASED)
        
        ;; Update worker
        (ok (map-set escrows 
            { task-id: task-id }
            (merge escrow-data { worker: (some worker) })
        )))
    )
)

(define-public (release-funds (task-id uint))
    (begin
        ;; Only authorized contracts can call this
        (asserts! (default-to false (map-get? authorized-contracts contract-caller)) ERR-NOT-AUTHORIZED)
        
        (let (
            (escrow-data (unwrap! (map-get? escrows { task-id: task-id }) ERR-ESCROW-NOT-FOUND))
            (worker (unwrap! (get worker escrow-data) ERR-NOT-AUTHORIZED))
            (amount (get amount escrow-data))
        )
        
        ;; Ensure not already released
        (asserts! (not (get released escrow-data)) ERR-ALREADY-RELEASED)
        
        ;; Transfer funds to worker
        (try! (as-contract (stx-transfer? amount tx-sender worker)))
        
        ;; Mark as released
        (ok (map-set escrows 
            { task-id: task-id }
            (merge escrow-data { released: true })
        )))
    )
)

(define-public (refund-creator (task-id uint))
    (begin
        ;; Only authorized contracts can call this
        (asserts! (default-to false (map-get? authorized-contracts contract-caller)) ERR-NOT-AUTHORIZED)
        
        (let (
            (escrow-data (unwrap! (map-get? escrows { task-id: task-id }) ERR-ESCROW-NOT-FOUND))
            (creator (get creator escrow-data))
            (amount (get amount escrow-data))
        )
        
        ;; Ensure not already released
        (asserts! (not (get released escrow-data)) ERR-ALREADY-RELEASED)
        
        ;; Transfer funds back to creator
        (try! (as-contract (stx-transfer? amount tx-sender creator)))
        
        ;; Mark as released
        (ok (map-set escrows 
            { task-id: task-id }
            (merge escrow-data { released: true })
        )))
    )
)

(define-public (open-dispute (task-id uint))
    (begin
        ;; Only authorized contracts can call this
        (asserts! (default-to false (map-get? authorized-contracts contract-caller)) ERR-NOT-AUTHORIZED)
        
        (let (
            (escrow-data (unwrap! (map-get? escrows { task-id: task-id }) ERR-ESCROW-NOT-FOUND))
        )
        
        ;; Ensure not already released
        (asserts! (not (get released escrow-data)) ERR-ALREADY-RELEASED)
        
        ;; Ensure dispute not already opened
        (asserts! (not (get dispute-opened escrow-data)) ERR-DISPUTE-ALREADY-OPENED)
        
        ;; Check if within dispute window
        (asserts! (< (- block-height (get deposited-at escrow-data)) DISPUTE-WINDOW-BLOCKS) ERR-DISPUTE-WINDOW-EXPIRED)
        
        ;; Mark dispute as opened
        (ok (map-set escrows 
            { task-id: task-id }
            (merge escrow-data { 
                dispute-opened: true,
                dispute-opened-at: (some block-height)
            })
        )))
    )
)

(define-public (resolve-dispute (task-id uint) (worker-percentage uint))
    (begin
        ;; Only authorized contracts (or owner for MVP) can call this
        (asserts! (or 
            (is-eq tx-sender CONTRACT-OWNER)
            (default-to false (map-get? authorized-contracts contract-caller))
        ) ERR-NOT-AUTHORIZED)
        
        ;; Validate percentage (0-100)
        (asserts! (<= worker-percentage u100) ERR-INVALID-PERCENTAGE)
        
        (let (
            (escrow-data (unwrap! (map-get? escrows { task-id: task-id }) ERR-ESCROW-NOT-FOUND))
            (worker (unwrap! (get worker escrow-data) ERR-NOT-AUTHORIZED))
            (creator (get creator escrow-data))
            (amount (get amount escrow-data))
            (worker-amount (/ (* amount worker-percentage) u100))
            (creator-amount (- amount worker-amount))
        )
        
        ;; Ensure not already released
        (asserts! (not (get released escrow-data)) ERR-ALREADY-RELEASED)
        
        ;; Ensure dispute is opened
        (asserts! (get dispute-opened escrow-data) ERR-NOT-AUTHORIZED)
        
        ;; Transfer funds according to split
        (if (> worker-amount u0)
            (try! (as-contract (stx-transfer? worker-amount tx-sender worker)))
            true
        )
        
        (if (> creator-amount u0)
            (try! (as-contract (stx-transfer? creator-amount tx-sender creator)))
            true
        )
        
        ;; Mark as released and resolved
        (ok (map-set escrows 
            { task-id: task-id }
            (merge escrow-data { 
                released: true,
                dispute-resolved: true
            })
        )))
    )
)

(define-public (withdraw-platform-fees (recipient principal))
    (begin
        ;; Only contract owner can withdraw fees
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        (let (
            (fees (var-get platform-fees-collected))
        )
        
        (asserts! (> fees u0) ERR-INSUFFICIENT-FUNDS)
        
        ;; Transfer fees
        (try! (as-contract (stx-transfer? fees tx-sender recipient)))
        
        ;; Reset collected fees
        (var-set platform-fees-collected u0)
        (ok fees))
    )
)
