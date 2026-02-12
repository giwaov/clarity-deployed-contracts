;; Permissioned Guestbook Contract

;; Map to store messages from specific users
(define-map guestbook principal (string-ascii 100))

;; Map to track who is "Approved" to sign the book
(define-map approved-signers principal bool)

;; Constant: The person who deployed the contract is the Admin
(define-constant ADMIN tx-sender)

;; Public: Admin can approve a new signer
(define-public (approve-signer (user principal))
  (begin
    (asserts! (is-eq tx-sender ADMIN) (err u401)) ;; Only Admin allowed
    (ok (map-set approved-signers user true))
  )
)

;; Public: Approved users can sign the guestbook
(define-public (sign-book (message (string-ascii 100)))
  (begin
    ;; Check if the user is approved
    (asserts! (default-to false (map-get? approved-signers tx-sender)) (err u403))
    (map-set guestbook tx-sender message)
    (ok "Signed successfully!")
  )
)

;; Read-only: Read a user's entry
(define-read-only (read-entry (user principal))
  (map-get? guestbook user)
)
