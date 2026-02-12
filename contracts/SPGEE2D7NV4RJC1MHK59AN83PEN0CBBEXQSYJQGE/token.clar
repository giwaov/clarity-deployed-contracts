;; Strade Token (BST) Contract
;; This contract defines the Strade Token (BST), a fungible token compliant with the SIP-010 standard.
;; It includes functions for transferring, minting, and burning tokens, as well as managing token metadata.

;; --- Token Properties ---
(define-fungible-token bst u1000000000000)

;; --- Constants ---
;; Defines immutable values used throughout the contract for error handling and configuration.

(define-constant CONTRACT_OWNER tx-sender) ;; Sets the contract deployer as the owner.
(define-constant ERR_OWNER_ONLY (err u100)) ;; Error for actions restricted to the contract owner.
(define-constant ERR_NOT_AUTHORIZED (err u101)) ;; Error for unauthorized actions.
(define-constant ERR_INVALID_AMOUNT (err u102)) ;; Error for invalid token amounts.
(define-constant ERR_INSUFFICIENT_BALANCE (err u103)) ;; Error when a user has an insufficient token balance.
(define-constant ERR_INVALID_RECIPIENT (err u104)) ;; Error for invalid recipient addresses.
(define-constant ERR_INVALID_URI (err u105)) ;; Error for invalid token URIs.
(define-constant ERR_MAX_SUPPLY_REACHED (err u106)) ;; Error when the maximum token supply is reached.
(define-constant ERR_CONTRACT_PAUSED (err u107)) ;; Error for actions attempted while the contract is paused.
(define-constant MAX_SUPPLY u10000000000000) ;; The maximum total supply of the token.

;; --- Variables ---
;; Defines mutable variables for tracking the token's state and metadata.

(define-data-var token-name (string-utf8 32) u"Strade Token") ;; The name of the token.
(define-data-var token-symbol (string-utf8 10) u"BST") ;; The symbol of the token.
(define-data-var token-decimals uint u6) ;; The number of decimal places for the token.
(define-data-var token-uri (optional (string-utf8 256)) none) ;; The URI for the token's metadata.
(define-data-var contract-paused bool false) ;; A flag to pause or unpause the contract.

;; --- Helper Functions ---

;; Checks if a principal is a valid recipient for token transfers.
(define-private (is-valid-recipient (recipient principal))
  (not (is-eq recipient (as-contract tx-sender))))

;; Checks if the contract is currently paused.
(define-private (is-contract-not-paused)
  (not (var-get contract-paused)))

;; --- SIP-010 Functions ---
;; Standard functions for a fungible token.

;; Transfers tokens from the sender to the recipient.
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-contract-not-paused) ERR_CONTRACT_PAUSED)
        (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (<= amount (ft-get-balance bst sender)) ERR_INSUFFICIENT_BALANCE)
        (asserts! (is-valid-recipient recipient) ERR_INVALID_RECIPIENT)
        (try! (ft-transfer? bst amount sender recipient))
        (print (merge 
            {event: "token_transferred", amount: amount, sender: sender, recipient: recipient}
            (match memo
                some-memo {memo: (some some-memo)}
                {memo: none}
            )
        ))
        (ok true)
    )
)

;; Gets the name of the token.
(define-read-only (get-name)
    (ok (var-get token-name))
)

;; Gets the symbol of the token.
(define-read-only (get-symbol)
    (ok (var-get token-symbol))
)

;; Gets the number of decimals for the token.
(define-read-only (get-decimals)
    (ok (var-get token-decimals))
)

;; Gets the balance of a given principal.
(define-read-only (get-balance (who principal))
    (ok (ft-get-balance bst who))
)

;; Gets the total supply of the token.
(define-read-only (get-total-supply)
    (ok (ft-get-supply bst))
)

;; Gets the token's metadata URI.
(define-read-only (get-token-uri)
    (ok (var-get token-uri))
)

;; --- Public Management Functions ---

;; Mints new tokens and assigns them to a recipient.
;; @param amount: The amount of tokens to mint.
;; @param recipient: The principal to receive the new tokens.
(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-contract-not-paused) ERR_CONTRACT_PAUSED)
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (is-valid-recipient recipient) ERR_INVALID_RECIPIENT)
        (asserts! (<= (+ amount (ft-get-supply bst)) MAX_SUPPLY) ERR_MAX_SUPPLY_REACHED)
        (match (ft-mint? bst amount recipient)
            success (begin
                (print {event: "token_minted", amount: amount, recipient: recipient})
                (ok success))
            error (err error))
    )
)

;; Burns a specified amount of tokens from the sender's balance.
;; @param amount: The amount of tokens to burn.
;; @param sender: The principal whose tokens will be burned.
(define-public (burn (amount uint) (sender principal))
    (begin
        (asserts! (is-contract-not-paused) ERR_CONTRACT_PAUSED)
        (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (<= amount (ft-get-balance bst sender)) ERR_INSUFFICIENT_BALANCE)
        (match (ft-burn? bst amount sender)
            success (begin
                (print {event: "token_burned", amount: amount, sender: sender})
                (ok success))
            error (err error))
    )
)

;; Sets the token's metadata URI.
;; @param new-uri: The new URI for the token metadata.
(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
        (match new-uri
            some-uri 
                (begin
                    (asserts! (<= (len some-uri) u256) ERR_INVALID_URI)
                    (var-set token-uri (some some-uri))
                    (print {event: "token_uri_updated", new_uri: some-uri})
                    (ok true)
                )
            (begin
                (var-set token-uri none)
                (print {event: "token_uri_removed"})
                (ok true)
            )
        )
    )
)

;; Pauses the contract, disabling most functions.
(define-public (pause-contract)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
        (var-set contract-paused true)
        (print {event: "contract_paused"})
        (ok true)
    )
)

;; Unpauses the contract, re-enabling all functions.
(define-public (unpause-contract)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
        (var-set contract-paused false)
        (print {event: "contract_unpaused"})
        (ok true)
    )
)

;; --- Contract Initialization ---
;; Initializes the contract upon deployment, minting the initial supply to the contract owner.
(begin
    (try! (ft-mint? bst u1000000000000 CONTRACT_OWNER))
    (print {event: "contract_deployed", initial_supply: u1000000000000})
)
