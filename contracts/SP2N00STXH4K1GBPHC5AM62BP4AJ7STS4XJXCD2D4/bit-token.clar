;; BitToken (BTK) - ERC20-like Token Contract
;; A fungible token implementation following SIP-010 standard

;; Token metadata
(define-constant TOKEN-NAME "BitToken")
(define-constant TOKEN-SYMBOL "BTK")
(define-constant TOKEN-DECIMALS u6)
(define-constant TOTAL-SUPPLY u1000000000000) ;; 1 million tokens with 6 decimals

;; Error constants
(define-constant ERR-INSUFFICIENT-BALANCE (err u1))
(define-constant ERR-INSUFFICIENT-ALLOWANCE (err u2))
(define-constant ERR-UNAUTHORIZED (err u3))

;; Data variables
(define-data-var contract-owner principal tx-sender)

;; Data maps
(define-map balances principal uint)
(define-map allowances {owner: principal, spender: principal} uint)

;; Initialize contract with total supply to owner
(map-set balances tx-sender TOTAL-SUPPLY)

;; SIP-010 trait implementation
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-UNAUTHORIZED)
        (try! (ft-transfer? bittoken amount sender recipient))
        (print memo)
        (ok true)
    )
)
(define-public (get-name)
    (ok TOKEN-NAME)
)

(define-public (get-symbol)
    (ok TOKEN-SYMBOL)
)

(define-public (get-decimals)
    (ok TOKEN-DECIMALS)
)
(define-public (get-balance (account principal))
    (ok (default-to u0 (map-get? balances account)))
)

(define-public (get-total-supply)
    (ok TOTAL-SUPPLY)
)
(define-public (approve (spender principal) (amount uint))
    (begin
        (map-set allowances {owner: tx-sender, spender: spender} amount)
        (print {action: "approve", owner: tx-sender, spender: spender, amount: amount})
        (ok true)
    )
)
(define-public (get-allowance (owner principal) (spender principal))
    (ok (default-to u0 (map-get? allowances {owner: owner, spender: spender})))
)
(define-public (transfer-from (amount uint) (owner principal) (recipient principal) (memo (optional (buff 34))))
    (let ((allowance (unwrap! (get-allowance owner tx-sender) ERR-INSUFFICIENT-ALLOWANCE)))
        (asserts! (>= allowance amount) ERR-INSUFFICIENT-ALLOWANCE)
        (try! (ft-transfer? bittoken amount owner recipient))
        (map-set allowances {owner: owner, spender: tx-sender} (- allowance amount))
        (print memo)
        (ok true)
    )
)
(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (try! (ft-mint? bittoken amount recipient))
        (print {action: "mint", recipient: recipient, amount: amount})
        (ok true)
    )
)
(define-public (burn (amount uint))
    (begin
        (try! (ft-burn? bittoken amount tx-sender))
        (print {action: "burn", account: tx-sender, amount: amount})
        (ok true)
    )
)
(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (var-set contract-owner new-owner)
        (print {action: "ownership-transfer", old-owner: tx-sender, new-owner: new-owner})
        (ok true)
    )
)
(define-read-only (get-contract-owner)
    (var-get contract-owner)
)

;; Define the fungible token
(define-fungible-token bittoken TOTAL-SUPPLY)