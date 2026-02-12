;; title: TokenManager
;; version: 1.0.0
;; summary: Manages supported tokens for PiggyBank system
;; description: Allows adding and removing supported tokens (STX and fungible tokens)

(define-constant ERR-UNAUTHORIZED (err u3001))
(define-constant ERR-TOKEN-EXISTS (err u3002))
(define-constant ERR-TOKEN-NOT-FOUND (err u3003))

;; Data vars
(define-data-var owner principal tx-sender)

;; Data maps
(define-map supported-tokens { token: principal } bool)

;; Public functions

;; Add a supported token (only owner)
(define-public (add-supported-token (token principal))
    (begin
        (asserts! (is-eq tx-sender (var-get owner)) ERR-UNAUTHORIZED)
        (let ((exists (default-to false (map-get? supported-tokens { token: token }))))
            (asserts! (not exists) ERR-TOKEN-EXISTS)
            (map-set supported-tokens { token: token } true)
            (ok true)
        )
    )
)

;; Remove a supported token (only owner)
(define-public (remove-supported-token (token principal))
    (begin
        (asserts! (is-eq tx-sender (var-get owner)) ERR-UNAUTHORIZED)
        (let ((exists (default-to false (map-get? supported-tokens { token: token }))))
            (asserts! exists ERR-TOKEN-NOT-FOUND)
            (map-delete supported-tokens { token: token })
            (ok true)
        )
    )
)

;; Transfer ownership (only owner)
(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get owner)) ERR-UNAUTHORIZED)
        (var-set owner new-owner)
        (ok true)
    )
)

;; Read-only functions

;; Check if a token is supported
(define-read-only (is-token-supported (token principal))
    (ok (default-to false (map-get? supported-tokens { token: token })))
)

;; Get contract owner
(define-read-only (get-owner)
    (ok (var-get owner))
)

