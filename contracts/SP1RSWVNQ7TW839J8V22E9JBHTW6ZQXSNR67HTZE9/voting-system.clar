;; Voting System Contract
;; On-chain voting/poll system for community decisions
;; Users vote on polls by paying fees; tracks results in real-time
;; Each vote generates transaction fees

;; Error codes
(define-constant ERR-POLL-NOT-FOUND (err u1001))
(define-constant ERR-POLL-CLOSED (err u1002))
(define-constant ERR-INVALID-OPTION (err u1003))
(define-constant ERR-INSUFFICIENT-FEE (err u1004))
(define-constant ERR-ALREADY-VOTED (err u1005))
(define-constant ERR-NOT-ADMIN (err u1006))

;; Vote fee (in micro-STX)
(define-constant VOTE-FEE u10000)  ;; 0.01 STX per vote

;; Maximum options per poll
(define-constant MAX-OPTIONS u10)

;; Contract admin (set to deployer)
(define-data-var admin principal tx-sender)

;; Poll counter
(define-data-var poll-counter uint u0)

;; Current active poll ID (none if no active poll)
(define-data-var active-poll-id (optional uint) none)

;; Poll data: poll-id -> {title, options, is-open, total-votes, creator}
(define-map polls uint {
    title: (string-ascii 200),
    options: (list 10 (string-ascii 100)),
    is-open: bool,
    total-votes: uint,
    creator: principal
})

;; Vote tracking: (poll-id, voter) -> {option-index, timestamp}
(define-map votes (tuple (poll-id uint) (voter principal)) {
    option-index: uint,
    timestamp: uint
})

;; Option vote counts: (poll-id, option-index) -> vote-count
(define-map option-votes (tuple (poll-id uint) (option-index uint)) uint)

;; Voter list for poll: (poll-id, index) -> voter
(define-map poll-voters (tuple (poll-id uint) (index uint)) principal)

;; Voter count per poll: poll-id -> count
(define-map poll-voter-count uint uint)

;; Helper to add voter to poll list
(define-private (add-voter-to-poll (poll-id uint) (voter principal))
    (let ((current-count (default-to u0 (map-get? poll-voter-count poll-id))))
        (map-set poll-voters (tuple (poll-id poll-id) (index current-count)) voter)
        (map-set poll-voter-count poll-id (+ current-count u1))
    )
)

;; Public function: Create a new poll (admin only)
(define-public (create-poll (title (string-ascii 200)) (options (list 10 (string-ascii 100))))
    (let ((sender tx-sender))
        ;; Validate that sender is admin
        (asserts! (is-eq sender (var-get admin)) ERR-NOT-ADMIN)
        
        ;; Validate options
        (let ((option-count (len options)))
            (asserts! (> option-count u1) ERR-INVALID-OPTION)  ;; At least 2 options
            (asserts! (<= option-count MAX-OPTIONS) ERR-INVALID-OPTION)
            
            ;; Get new poll ID
            (let ((new-poll-id (var-get poll-counter)))
                ;; Increment poll counter
                (var-set poll-counter (+ new-poll-id u1))
                
                ;; Create poll
                (map-set polls new-poll-id {
                    title: title,
                    options: options,
                    is-open: true,
                    total-votes: u0,
                    creator: sender
                })
                
                ;; Set as active poll
                (var-set active-poll-id (some new-poll-id))
                
                ;; Initialize vote counts for each option
                (map-set poll-voter-count new-poll-id u0)
                
                (ok {
                    poll-id: new-poll-id,
                    title: title,
                    options: options
                })
            )
        )
    )
)

;; Public function: Vote on a poll
(define-public (vote (poll-id uint) (option-index uint) (fee-amount uint))
    (let ((sender tx-sender)
          (vote-time (var-get poll-counter)))
        
        ;; Validate fee
        (asserts! (>= fee-amount VOTE-FEE) ERR-INSUFFICIENT-FEE)
        
        ;; Get poll data (unwrap-panic is safe after checking poll exists)
        (let ((poll-opt (map-get? polls poll-id)))
            (asserts! (is-some poll-opt) ERR-POLL-NOT-FOUND)
            (let ((poll (unwrap-panic poll-opt)))
                ;; Validate poll is open
                (asserts! (get is-open poll) ERR-POLL-CLOSED)
                
                ;; Validate option index
                (let ((option-count (len (get options poll))))
                    (asserts! (< option-index option-count) ERR-INVALID-OPTION)
                    
                    ;; Check if user already voted
                    (asserts! (is-none (map-get? votes (tuple (poll-id poll-id) (voter sender)))) ERR-ALREADY-VOTED)
                    
                    ;; Record vote
                    (map-set votes (tuple (poll-id poll-id) (voter sender)) {
                        option-index: option-index,
                        timestamp: vote-time
                    })
                    
                    ;; Update option vote count
                    (let ((current-count (default-to u0 (map-get? option-votes (tuple (poll-id poll-id) (option-index option-index))))))
                        (map-set option-votes (tuple (poll-id poll-id) (option-index option-index)) (+ current-count u1))
                    )
                    
                    ;; Update total votes
                    (map-set polls poll-id {
                        title: (get title poll),
                        options: (get options poll),
                        is-open: (get is-open poll),
                        total-votes: (+ (get total-votes poll) u1),
                        creator: (get creator poll)
                    })
                    
                    ;; Add voter to list
                    (add-voter-to-poll poll-id sender)
                    
                    ;; STX is sent automatically with the transaction
                    (ok {
                        poll-id: poll-id,
                        voter: sender,
                        option-index: option-index,
                        total-votes: (+ (get total-votes poll) u1)
                    })
                )
            )
        )
    )
)

;; Public function: Close a poll (admin only)
(define-public (close-poll (poll-id uint))
    (let ((sender tx-sender))
        ;; Validate that sender is admin
        (asserts! (is-eq sender (var-get admin)) ERR-NOT-ADMIN)
        
        ;; Get poll data
        (let ((poll-opt (map-get? polls poll-id)))
            (asserts! (is-some poll-opt) ERR-POLL-NOT-FOUND)
            (let ((poll (unwrap-panic poll-opt)))
                ;; Close poll
                (map-set polls poll-id {
                    title: (get title poll),
                    options: (get options poll),
                    is-open: false,
                    total-votes: (get total-votes poll),
                    creator: (get creator poll)
                })
                
                ;; Clear active poll if this was the active one
                (match (var-get active-poll-id) active-id
                    (if (is-eq active-id poll-id)
                        (var-set active-poll-id none)
                        true
                    )
                    true
                )
                
                (ok {
                    poll-id: poll-id,
                    total-votes: (get total-votes poll),
                    closed: true
                })
            )
        )
    )
)

;; ============================================
;; Read-only functions for contract queries
;; ============================================

;; Read-only: Get poll data
(define-read-only (get-poll (poll-id uint))
    (map-get? polls poll-id)
)

;; Read-only: Get vote count for specific option
(define-read-only (get-option-votes (poll-id uint) (option-index uint))
    (default-to u0 (map-get? option-votes (tuple (poll-id poll-id) (option-index option-index))))
)

;; Read-only: Get user's vote for a poll
(define-read-only (get-user-vote (poll-id uint) (voter principal))
    (map-get? votes (tuple (poll-id poll-id) (voter voter)))
)

;; Read-only: Get total polls count
(define-read-only (get-poll-count)
    (var-get poll-counter)
)

;; Read-only: Get active poll ID
(define-read-only (get-active-poll-id)
    (var-get active-poll-id)
)

;; Read-only: Get poll results with all option counts
(define-read-only (get-poll-results (poll-id uint))
    (match (map-get? polls poll-id) poll-data
        (let ((poll poll-data)
              (options (get options poll))
              (option-count (len options)))
            (some {
                poll-id: poll-id,
                title: (get title poll),
                options: options,
                is-open: (get is-open poll),
                total-votes: (get total-votes poll),
                option-count: option-count
            })
        )
        none
    )
)

;; Read-only: Get voter count for a poll
(define-read-only (get-poll-voter-count (poll-id uint))
    (default-to u0 (map-get? poll-voter-count poll-id))
)

;; Read-only: Get voter by index for a poll
(define-read-only (get-poll-voter (poll-id uint) (index uint))
    (map-get? poll-voters (tuple (poll-id poll-id) (index index)))
)
