;; Book Lending Contract with sBTC Deposits
;; Users can borrow books by depositing sBTC, which is returned when the book is returned

;; Define error codes
(define-constant ERR_BOOK_NOT_FOUND (err u101))
(define-constant ERR_BOOK_NOT_AVAILABLE (err u102))
(define-constant ERR_BOOK_ALREADY_RETURNED (err u103))
(define-constant ERR_NOT_BORROWER (err u104))
(define-constant ERR_TRANSFER_FAILED (err u106))
(define-constant ERR_INVALID_DEPOSIT_AMOUNT (err u108))
(define-constant ERR_NOT_BOOK_OWNER (err u109))
(define-constant ERR_INVALID_STRING (err u110))

;; Data structure for books
(define-map books
    uint ;; book-id
    {
        title: (string-utf8 200),
        author: (string-utf8 100),
        cover-page: (string-utf8 200),
        owner: principal,
        is-available: bool,
        total-borrows: uint,
        deposit-amount: uint,
    }
)

;; Data structure for active borrows
(define-map borrows
    uint ;; book-id
    {
        borrower: principal,
        borrowed-at: uint,
        deposit-amount: uint,
    }
)

;; Counter for book IDs
(define-data-var book-id-counter uint u0)

;; ===============================
;; ADMIN FUNCTIONS
;; ===============================

;; Add a new book to the library with custom deposit amount
(define-public (add-book
        (title (string-utf8 200))
        (author (string-utf8 100))
        (cover-page (string-utf8 200))
        (deposit-amount uint)
    )
    (begin
        ;; Validate inputs
        (asserts! (> (len title) u0) ERR_INVALID_STRING)
        (asserts! (> (len author) u0) ERR_INVALID_STRING)
        (asserts! (> (len cover-page) u0) ERR_INVALID_STRING)
        (asserts! (> deposit-amount u0) ERR_INVALID_DEPOSIT_AMOUNT)

        (let ((book-id (+ (var-get book-id-counter) u1)))
            ;; Add book to the map
            (map-set books book-id {
                title: title,
                author: author,
                cover-page: cover-page,
                owner: contract-caller,
                is-available: true,
                total-borrows: u0,
                deposit-amount: deposit-amount,
            })

            ;; Increment counter
            (var-set book-id-counter book-id)

            ;; Emit event
            (print {
                event: "book-added",
                book-id: book-id,
                title: title,
                author: author,
                cover-page: cover-page,
                owner: contract-caller,
                deposit-amount: deposit-amount,
            })

            (ok book-id)
        )
    )
)

;; Update deposit amount for a book (only book owner can do this)
(define-public (update-deposit-amount
        (book-id uint)
        (new-deposit-amount uint)
    )
    (let ((book (unwrap! (map-get? books book-id) ERR_BOOK_NOT_FOUND)))
        ;; Only the book owner can update the deposit amount
        (asserts! (is-eq contract-caller (get owner book)) ERR_NOT_BOOK_OWNER)

        ;; Book must be available (not currently borrowed)
        (asserts! (get is-available book) ERR_BOOK_NOT_AVAILABLE)

        ;; Ensure new deposit amount is greater than 0
        (asserts! (> new-deposit-amount u0) ERR_INVALID_DEPOSIT_AMOUNT)

        ;; Update the book's deposit amount
        (map-set books book-id
            (merge book { deposit-amount: new-deposit-amount })
        )

        ;; Emit event
        (print {
            event: "deposit-amount-updated",
            book-id: book-id,
            old-deposit: (get deposit-amount book),
            new-deposit: new-deposit-amount,
        })

        (ok true)
    )
)

;; ===============================
;; USER FUNCTIONS
;; ===============================

;; Borrow a book by depositing sBTC
(define-public (borrow-book (book-id uint))
    (let ((book (unwrap! (map-get? books book-id) ERR_BOOK_NOT_FOUND)))
        ;; Check if book is available
        (asserts! (get is-available book) ERR_BOOK_NOT_AVAILABLE)

        ;; Transfer deposit from borrower to contract with restrict-assets
        (try! (restrict-assets? contract-caller ((with-ft 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
            "sbtc-token" (get deposit-amount book)
        ))
            (unwrap!
                (contract-call?
                    'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
                    transfer (get deposit-amount book) contract-caller
                    current-contract none
                )
                ERR_TRANSFER_FAILED
            )
        ))

        ;; Update book status
        (map-set books book-id
            (merge book {
                is-available: false,
                total-borrows: (+ (get total-borrows book) u1),
            })
        )

        ;; Record the borrow
        (map-set borrows book-id {
            borrower: contract-caller,
            borrowed-at: burn-block-height,
            deposit-amount: (get deposit-amount book),
        })

        ;; Emit event
        (print {
            event: "book-borrowed",
            book-id: book-id,
            borrower: contract-caller,
            deposit: (get deposit-amount book),
            borrowed-at: burn-block-height,
        })

        (ok true)
    )
)

;; Return a book and get deposit back
(define-public (return-book (book-id uint))
    (let (
            (book (unwrap! (map-get? books book-id) ERR_BOOK_NOT_FOUND))
            (borrow (unwrap! (map-get? borrows book-id) ERR_BOOK_ALREADY_RETURNED))
        )
        ;; Verify caller is the borrower
        (asserts! (is-eq contract-caller (get borrower borrow)) ERR_NOT_BORROWER)

        ;; Return deposit to borrower from contract
        (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
            transfer (get deposit-amount borrow) current-contract
            (get borrower borrow) none
        ))

        ;; Update book status
        (map-set books book-id (merge book { is-available: true }))

        ;; Remove borrow record
        (map-delete borrows book-id)

        ;; Emit event
        (print {
            event: "book-returned",
            book-id: book-id,
            borrower: contract-caller,
            returned-at: burn-block-height,
        })

        (ok true)
    )
)

;; ===============================
;; READ-ONLY FUNCTIONS
;; ===============================

;; Get book details
(define-read-only (get-book (book-id uint))
    (map-get? books book-id)
)

;; Get borrow details for a book
(define-read-only (get-borrow (book-id uint))
    (map-get? borrows book-id)
)

;; Get total number of books
(define-read-only (get-book-count)
    (ok (var-get book-id-counter))
)

;; Check if a book is available
(define-read-only (is-book-available (book-id uint))
    (match (map-get? books book-id)
        book (ok (get is-available book))
        (err ERR_BOOK_NOT_FOUND)
    )
)

;; Get deposit amount for a specific book
(define-read-only (get-book-deposit-amount (book-id uint))
    (match (map-get? books book-id)
        book (ok (get deposit-amount book))
        (err ERR_BOOK_NOT_FOUND)
    )
)

;; Get contract balance
(define-read-only (get-contract-balance)
    (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        get-balance current-contract
    )
)
