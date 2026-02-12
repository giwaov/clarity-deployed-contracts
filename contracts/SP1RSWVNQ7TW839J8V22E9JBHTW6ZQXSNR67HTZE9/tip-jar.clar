;; Tip Jar Contract
;; Allows users to send tips in STX to creators/addresses
;; Tracks tips sent and received for ranking and history

(define-constant ERR-INVALID-AMOUNT (err u1001))
(define-constant ERR-INVALID-RECIPIENT (err u1002))
(define-constant ERR-MEMO-TOO-LONG (err u1003))
(define-constant ERR-TIP-NOT-FOUND (err u1004))

(define-constant MAX-MEMO-LENGTH u140)

;; Tip data structure
(define-data-var tip-counter uint u0)

;; Maps to store tips
;; (recipient, tip-id) -> {sender, amount, memo, timestamp}
(define-map tips-received (tuple (recipient principal) (tip-id uint)) {
    sender: principal,
    amount: uint,
    memo: (optional (string-utf8 140)),
    timestamp: uint
})

;; (sender, tip-id) -> {recipient, amount, memo, timestamp}
(define-map tips-sent (tuple (sender principal) (tip-id uint)) {
    recipient: principal,
    amount: uint,
    memo: (optional (string-utf8 140)),
    timestamp: uint
})

;; Tipper statistics: tipper -> {total-sent, count}
(define-map tipper-stats principal {
    total-sent: uint,
    count: uint
})

;; Recipient statistics: recipient -> {total-received, count}
(define-map recipient-stats principal {
    total-received: uint,
    count: uint
})

;; Helper function to update tipper stats
(define-private (update-tipper-stats (tipper principal) (amount uint))
    (let ((current-stats (map-get? tipper-stats tipper)))
        (if (is-none current-stats)
            (map-set tipper-stats tipper {
                total-sent: amount,
                count: u1
            })
            (map-set tipper-stats tipper {
                total-sent: (+ (get total-sent (unwrap-panic current-stats)) amount),
                count: (+ (get count (unwrap-panic current-stats)) u1)
            })
        )
    )
)

;; Helper function to update recipient stats
(define-private (update-recipient-stats (recipient principal) (amount uint))
    (let ((current-stats (map-get? recipient-stats recipient)))
        (if (is-none current-stats)
            (map-set recipient-stats recipient {
                total-received: amount,
                count: u1
            })
            (map-set recipient-stats recipient {
                total-received: (+ (get total-received (unwrap-panic current-stats)) amount),
                count: (+ (get count (unwrap-panic current-stats)) u1)
            })
        )
    )
)

;; Main function to send a tip
;; @param to: The recipient principal address
;; @param amount: Amount in micro-STX (1 STX = 1,000,000 micro-STX)
;; @param memo: Optional memo message (max 140 characters)
(define-public (tip (to principal) (amount uint) (memo (optional (string-utf8 140))))
    (let ((sender tx-sender))
        ;; Validate amount
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        
        ;; Validate recipient (cannot tip yourself)
        (asserts! (not (is-eq sender to)) ERR-INVALID-RECIPIENT)
        
        ;; Validate memo length if provided
        (match memo
            memo-value (asserts! 
                (<= (len memo-value) MAX-MEMO-LENGTH) 
                ERR-MEMO-TOO-LONG
            )
            true
        )
        
        ;; Get current tip counter and increment
        (let ((tip-id (var-get tip-counter)))
            (var-set tip-counter (+ tip-id u1))
            
            ;; Use tip-id as timestamp (sequential identifier)
            (let ((timestamp tip-id))
                ;; Store tip in received map
                (map-set tips-received (tuple (recipient to) (tip-id tip-id)) {
                    sender: sender,
                    amount: amount,
                    memo: memo,
                    timestamp: timestamp
                })
                
                ;; Store tip in sent map
                (map-set tips-sent (tuple (sender sender) (tip-id tip-id)) {
                    recipient: to,
                    amount: amount,
                    memo: memo,
                    timestamp: timestamp
                })
                
                ;; Update statistics
                (update-tipper-stats sender amount)
                (update-recipient-stats to amount)
                
                ;; Transfer STX
                (stx-transfer? amount sender to)
            )
        )
    )
)

;; Get a specific tip received by a user
;; @param user: The recipient principal
;; @param tip-id: The tip ID
;; @returns: Tip data or none if not found
(define-read-only (get-tip-received (user principal) (tip-id uint))
    (map-get? tips-received (tuple (recipient user) (tip-id tip-id)))
)

;; Get a specific tip sent by a user
;; @param sender: The sender principal
;; @param tip-id: The tip ID
;; @returns: Tip data or none if not found
(define-read-only (get-tip-sent (sender principal) (tip-id uint))
    (map-get? tips-sent (tuple (sender sender) (tip-id tip-id)))
)

;; Get statistics for a tipper
;; @param tipper: The tipper principal
;; @returns: Statistics {total-sent, count} or none if no tips sent
(define-read-only (get-tipper-stats (tipper principal))
    (map-get? tipper-stats tipper)
)

;; Get statistics for a recipient
;; @param recipient: The recipient principal
;; @returns: Statistics {total-received, count} or none if no tips received
(define-read-only (get-recipient-stats (recipient principal))
    (map-get? recipient-stats recipient)
)

;; Get total tip counter
;; @returns: Total number of tips sent
(define-read-only (get-tip-counter)
    (var-get tip-counter)
)

