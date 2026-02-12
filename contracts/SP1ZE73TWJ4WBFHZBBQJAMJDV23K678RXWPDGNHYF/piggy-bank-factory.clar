;; title: PiggyBankFactory
;; version: 1.0.0
;; summary: Factory contract to register and track PiggyBank contracts
;; description: Allows users to register their PiggyBank contracts. Users deploy PiggyBank contracts separately and register them here.

(define-constant ERR-UNAUTHORIZED (err u2001))
(define-constant ERR-ALREADY-REGISTERED (err u2002))
(define-constant ERR-NOT-REGISTERED (err u2003))

;; Data maps  
(define-map user-piggy-bank-count { user: principal } uint)
(define-map user-piggy-bank { user: principal, index: uint } principal)
(define-map piggy-bank-owners { piggy-bank: principal } principal)
(define-data-var total-piggy-banks uint u0)

;; Public functions

;; Register a PiggyBank contract (must be called by the piggy bank owner)
(define-public (register-piggy-bank (piggy-bank principal))
    (begin
        ;; Check if already registered
        (let ((existing-owner (map-get? piggy-bank-owners { piggy-bank: piggy-bank })))
            (asserts! (is-none existing-owner) ERR-ALREADY-REGISTERED)
        )
        
        ;; Register the piggy bank
        (let ((count (default-to u0 (map-get? user-piggy-bank-count { user: tx-sender }))))
            (map-set user-piggy-bank { user: tx-sender, index: count } piggy-bank)
            (map-set user-piggy-bank-count { user: tx-sender } (+ count u1))
        )
        (map-set piggy-bank-owners { piggy-bank: piggy-bank } tx-sender)
        (var-set total-piggy-banks (+ (var-get total-piggy-banks) u1))
        (ok true)
    )
)

;; Unregister a PiggyBank contract (only owner)
(define-public (unregister-piggy-bank (piggy-bank principal))
    (let ((owner (map-get? piggy-bank-owners { piggy-bank: piggy-bank })))
        (asserts! (is-some owner) ERR-NOT-REGISTERED)
        (asserts! (is-eq tx-sender (unwrap-panic owner)) ERR-UNAUTHORIZED)
        (map-delete piggy-bank-owners { piggy-bank: piggy-bank })
        (var-set total-piggy-banks (- (var-get total-piggy-banks) u1))
        (ok true)
    )
)

;; Read-only functions

;; Get all piggy banks for a user (returns count, use get-user-piggy-bank-by-index to get individual)
(define-read-only (get-user-piggy-bank-count (user principal))
    (ok (default-to u0 (map-get? user-piggy-bank-count { user: user })))
)

;; Get a specific piggy bank by index
(define-read-only (get-user-piggy-bank-by-index (user principal) (index uint))
    (ok (map-get? user-piggy-bank { user: user, index: index }))
)

;; Get the owner of a piggy bank
(define-read-only (get-piggy-bank-owner (piggy-bank principal))
    (ok (map-get? piggy-bank-owners { piggy-bank: piggy-bank }))
)

;; Check if a principal is a registered piggy bank contract
(define-read-only (is-piggy-bank (contract principal))
    (ok (is-some (map-get? piggy-bank-owners { piggy-bank: contract })))
)

;; Get total number of registered piggy banks
(define-read-only (get-total-piggy-banks)
    (ok (var-get total-piggy-banks))
)

