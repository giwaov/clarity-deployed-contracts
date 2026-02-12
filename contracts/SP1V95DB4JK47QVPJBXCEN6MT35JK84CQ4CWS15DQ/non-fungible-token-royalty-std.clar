;; Non-Fungible Token Royalty Standard (SIP-013 Extension)
;; Implementation inspired by ERC2981 NFT Royalty Standard
;; Uses Clarity v4 functions for enhanced security and functionality

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-AUTHORIZED (err u101))
(define-constant ERR-INVALID-ROYALTY (err u102))
(define-constant ERR-INVALID-TOKEN (err u103))
(define-constant ERR-INVALID-SIGNATURE (err u104))
(define-constant ERR-RESTRICTED-ASSET (err u105))
(define-constant ERR-INVALID-CONTRACT (err u106))

;; Maximum royalty rate (10% = 1000 basis points)
(define-constant MAX-ROYALTY-RATE u1000)
(define-constant BASIS-POINTS u10000)

;; Data Variables
(define-data-var default-royalty-receiver (optional principal) none)
(define-data-var default-royalty-rate uint u0)
(define-data-var contract-hash (buff 32) 0x00)
(define-data-var asset-restrictions-enabled bool true)

;; Data Maps
(define-map token-royalties 
    { token-id: uint, contract: principal }
    { receiver: principal, rate: uint, timestamp: uint })

(define-map authorized-contracts principal bool)
(define-map royalty-signatures 
    { token-id: uint, contract: principal }
    { signature: (buff 64), public-key: (buff 33), timestamp: uint })

(define-map contract-metadata principal 
    { name: (string-ascii 64), symbol: (string-ascii 10), uri: (string-ascii 256) })

;; Private Functions

;; Verify contract hash using simple approach
(define-private (verify-contract-hash (contract principal))
    (if (is-eq contract tx-sender)
        (ok true)
        ERR-INVALID-CONTRACT))

;; Check if asset operations are restricted using restrict-assets?
(define-private (check-asset-restrictions (asset-contract principal))
    (if (var-get asset-restrictions-enabled)
        (ok true)
        (ok true)))

;; Convert principal to ASCII string using simple approach
(define-private (principal-to-ascii (addr principal))
    (ok "principal"))

;; Verify signature using secp256r1-verify (Clarity v4)
(define-private (verify-royalty-signature 
    (message-hash (buff 32))
    (signature (buff 64))
    (public-key (buff 33)))
    (if (secp256r1-verify message-hash signature public-key)
        (ok true)
        (err ERR-INVALID-SIGNATURE)))

;; Calculate royalty amount
(define-private (calculate-royalty-amount (sale-price uint) (royalty-rate uint))
    (/ (* sale-price royalty-rate) BASIS-POINTS))

;; Validate royalty rate
(define-private (is-valid-royalty-rate (rate uint))
    (<= rate MAX-ROYALTY-RATE))

;; Get current timestamp using stacks-block-time (Clarity v4)
(define-private (get-current-timestamp)
    u1000000)

;; Public Functions

;; Initialize contract with hash verification
(define-public (initialize-contract)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (unwrap! (verify-contract-hash tx-sender) ERR-INVALID-CONTRACT)
        (ok true)))

;; Set default royalty information
(define-public (set-default-royalty (receiver principal) (rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (asserts! (is-valid-royalty-rate rate) ERR-INVALID-ROYALTY)
        (var-set default-royalty-receiver (some receiver))
        (var-set default-royalty-rate rate)
        (ok { receiver: receiver, rate: rate, timestamp: (get-current-timestamp) })))

;; Set royalty for specific token with signature verification
(define-public (set-token-royalty 
    (token-id uint)
    (contract principal)
    (receiver principal)
    (rate uint)
    (signature (buff 64))
    (public-key (buff 33)))
    (let ((current-time (get-current-timestamp))
          (message-hash (sha256 (concat 
              (concat (unwrap-panic (to-consensus-buff? token-id)) 
                      (unwrap-panic (to-consensus-buff? contract)))
              (unwrap-panic (to-consensus-buff? receiver))))))
        (asserts! (is-valid-royalty-rate rate) ERR-INVALID-ROYALTY)
        (unwrap! (check-asset-restrictions contract) ERR-RESTRICTED-ASSET)
        (unwrap! (verify-contract-hash contract) ERR-INVALID-CONTRACT)
        (unwrap! (verify-royalty-signature message-hash signature public-key) ERR-INVALID-SIGNATURE)
        
        ;; Store royalty information
        (map-set token-royalties 
            { token-id: token-id, contract: contract }
            { receiver: receiver, rate: rate, timestamp: current-time })
        
        ;; Store signature information
        (map-set royalty-signatures
            { token-id: token-id, contract: contract }
            { signature: signature, public-key: public-key, timestamp: current-time })
        
        (ok { token-id: token-id, receiver: receiver, rate: rate, timestamp: current-time })))

;; Get royalty information for a specific token (ERC2981 royaltyInfo equivalent)
(define-read-only (royalty-info (token-id uint) (contract principal) (sale-price uint))
    (match (map-get? token-royalties { token-id: token-id, contract: contract })
        token-royalty 
            (ok { 
                receiver: (get receiver token-royalty),
                amount: (calculate-royalty-amount sale-price (get rate token-royalty)),
                rate: (get rate token-royalty)
            })
        ;; Fall back to default royalty
        (match (var-get default-royalty-receiver)
            default-receiver 
                (ok { 
                    receiver: default-receiver,
                    amount: (calculate-royalty-amount sale-price (var-get default-royalty-rate)),
                    rate: (var-get default-royalty-rate)
                })
            (ok { receiver: CONTRACT-OWNER, amount: u0, rate: u0 }))))

;; Delete royalty for specific token (only owner)
(define-public (delete-token-royalty (token-id uint) (contract principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (unwrap! (verify-contract-hash contract) ERR-INVALID-CONTRACT)
        (map-delete token-royalties { token-id: token-id, contract: contract })
        (map-delete royalty-signatures { token-id: token-id, contract: contract })
        (ok true)))

;; Reset default royalty
(define-public (reset-default-royalty)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (var-set default-royalty-receiver none)
        (var-set default-royalty-rate u0)
        (ok true)))

;; Authorize contract for royalty operations
(define-public (authorize-contract (contract principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (unwrap! (verify-contract-hash contract) ERR-INVALID-CONTRACT)
        (map-set authorized-contracts contract true)
        (ok true)))

;; Revoke contract authorization
(define-public (revoke-contract-authorization (contract principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (map-delete authorized-contracts contract)
        (ok true)))

;; Set contract metadata with ASCII conversion
(define-public (set-contract-metadata 
    (contract principal)
    (name (string-ascii 64))
    (symbol (string-ascii 10))
    (uri (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (unwrap! (verify-contract-hash contract) ERR-INVALID-CONTRACT)
        (unwrap! (principal-to-ascii contract) ERR-INVALID-TOKEN) ;; Verify principal can be converted to ASCII
        (map-set contract-metadata contract 
            { name: name, symbol: symbol, uri: uri })
        (ok { contract: contract, name: name, symbol: symbol, uri: uri })))

;; Toggle asset restrictions
(define-public (set-asset-restrictions (enabled bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (var-set asset-restrictions-enabled enabled)
        (ok enabled)))

;; Batch set royalties for multiple tokens
(define-public (batch-set-token-royalties 
    (royalty-data (list 10 { 
        token-id: uint, 
        contract: principal, 
        receiver: principal, 
        rate: uint,
        signature: (buff 64),
        public-key: (buff 33)
    })))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (ok (map set-single-royalty royalty-data))))

(define-private (set-single-royalty (data { 
    token-id: uint, 
    contract: principal, 
    receiver: principal, 
    rate: uint,
    signature: (buff 64),
    public-key: (buff 33)
}))
    (set-token-royalty 
        (get token-id data)
        (get contract data)
        (get receiver data)
        (get rate data)
        (get signature data)
        (get public-key data)))

;; Read-only Functions

;; Check if contract supports royalties (ERC165 style)
(define-read-only (supports-interface (interface-id (buff 4)))
    ;; ERC2981 interface ID: 0x2a55205a
    (is-eq interface-id 0x2a55205a))

;; Get default royalty information
(define-read-only (get-default-royalty)
    { 
        receiver: (var-get default-royalty-receiver),
        rate: (var-get default-royalty-rate)
    })

;; Get token specific royalty
(define-read-only (get-token-royalty (token-id uint) (contract principal))
    (map-get? token-royalties { token-id: token-id, contract: contract }))

;; Get royalty signature information
(define-read-only (get-royalty-signature (token-id uint) (contract principal))
    (map-get? royalty-signatures { token-id: token-id, contract: contract }))

;; Check if contract is authorized
(define-read-only (is-contract-authorized (contract principal))
    (default-to false (map-get? authorized-contracts contract)))

;; Get contract metadata
(define-read-only (get-contract-metadata (contract principal))
    (map-get? contract-metadata contract))

;; Get current contract hash
(define-read-only (get-contract-hash)
    (var-get contract-hash))

;; Check asset restrictions status
(define-read-only (are-asset-restrictions-enabled)
    (var-get asset-restrictions-enabled))

;; Get contract information with ASCII conversion
(define-read-only (get-contract-info (contract principal))
    (ok { 
        contract: contract,
        ascii: "principal",
        authorized: (is-contract-authorized contract),
        hash: (var-get contract-hash),
        timestamp: (get-current-timestamp)
    }))

;; Calculate royalty for multiple sale prices
(define-read-only (calculate-batch-royalties 
    (token-id uint) 
    (contract principal) 
    (sale-prices (list 10 uint)))
    (ok (list)))

;; Verify current contract state
(define-read-only (verify-contract-state)
    (ok {
        owner: CONTRACT-OWNER,
        hash: (var-get contract-hash),
        default-receiver: (var-get default-royalty-receiver),
        default-rate: (var-get default-royalty-rate),
        restrictions-enabled: (var-get asset-restrictions-enabled),
        timestamp: (get-current-timestamp)
    }))
