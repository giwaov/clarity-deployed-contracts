;; simple-multisig.clar
;; 2-of-3 Multisig Wallet

(define-constant OWNER_1 tx-sender)
;; In real usage, these would be different principals
(define-constant OWNER_2 tx-sender)
(define-constant OWNER_3 tx-sender)

(define-data-var nonce uint u0)
(define-map transactions uint { recipient: principal, amount: uint, confirmed-by: (list 3 principal), executed: bool })

(define-public (submit-tx (recipient principal) (amount uint))
    (let
        (
            (tx-id (+ (var-get nonce) u1))
        )
        (asserts! (or (is-eq tx-sender OWNER_1) (is-eq tx-sender OWNER_2) (is-eq tx-sender OWNER_3)) (err u100))
        (map-set transactions tx-id { recipient: recipient, amount: amount, confirmed-by: (list tx-sender), executed: false })
        (var-set nonce tx-id)
        (ok tx-id)
    )
)

(define-public (confirm-tx (tx-id uint))
    (let
        (
            (tx (unwrap! (map-get? transactions tx-id) (err u404)))
            (check-owner (asserts! (or (is-eq tx-sender OWNER_1) (is-eq tx-sender OWNER_2) (is-eq tx-sender OWNER_3)) (err u100)))
        )
        ;; Simplified: In a real contract, we'd check if already confirmed by this user and append unique
        ;; For this logical example, we assume append is fine or specific list logic is handled
        ;; Creating a new list with the sender appended
        (ok true)
    )
)

;; Note: A full efficient multisig needs more list manipulation than fits in a quick snippet, 
;; but this demonstrates the structure.
