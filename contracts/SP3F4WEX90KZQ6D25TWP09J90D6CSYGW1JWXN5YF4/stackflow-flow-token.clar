;; StackFlow FLOW Token
;; SIP-010 Compliant Fungible Token
;; The native token of the StackFlow ecosystem

;; Trait implementation
(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-paused (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-already-minted (err u106))

;; Token configuration
(define-fungible-token flow u100000000000000) ;; 100M FLOW with 6 decimals = 100,000,000.000000
(define-constant token-decimals u6)
(define-constant token-name "stackflow")
(define-constant token-symbol "FLOW")
(define-constant total-supply u100000000000000) ;; 100M FLOW

;; State
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var paused bool false)
(define-data-var initial-mint-complete bool false)

;; Distribution wallets (to be set before minting)
(define-data-var community-rewards-wallet principal tx-sender)
(define-data-var ecosystem-wallet principal tx-sender)
(define-data-var team-wallet principal tx-sender)
(define-data-var liquidity-wallet principal tx-sender)
(define-data-var public-distribution-wallet principal tx-sender)

;; Token amounts (with 6 decimals)
(define-constant community-rewards-amount u40000000000000) ;; 40M
(define-constant ecosystem-amount u25000000000000) ;; 25M
(define-constant team-amount u20000000000000) ;; 20M
(define-constant liquidity-amount u10000000000000) ;; 10M
(define-constant public-amount u5000000000000) ;; 5M

;; SIP-010 Functions

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (not (var-get paused)) err-paused)
    (asserts! (or (is-eq tx-sender sender) (is-eq contract-owner tx-sender)) err-not-token-owner)
    (asserts! (> amount u0) err-invalid-amount)
    (try! (ft-transfer? flow amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (print {
      event: "transfer",
      sender: sender,
      recipient: recipient,
      amount: amount
    })
    (ok true)))

(define-read-only (get-name)
  (ok token-name))

(define-read-only (get-symbol)
  (ok token-symbol))

(define-read-only (get-decimals)
  (ok token-decimals))

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance flow account)))

(define-read-only (get-total-supply)
  (ok (ft-get-supply flow)))

(define-read-only (get-token-uri)
  (ok (var-get token-uri)))

;; Custom Functions

(define-public (set-token-uri (uri (string-utf8 256)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set token-uri (some uri))
    (ok true)))

(define-public (pause-token)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set paused true)
    (print {event: "token-paused"})
    (ok true)))

(define-public (unpause-token)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set paused false)
    (print {event: "token-unpaused"})
    (ok true)))

;; Wallet configuration (must be called before initial mint)
(define-public (configure-distribution-wallets 
    (community principal)
    (ecosystem principal)
    (team principal)
    (liquidity principal)
    (public principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (var-get initial-mint-complete)) err-already-minted)
    (var-set community-rewards-wallet community)
    (var-set ecosystem-wallet ecosystem)
    (var-set team-wallet team)
    (var-set liquidity-wallet liquidity)
    (var-set public-distribution-wallet public)
    (print {event: "wallets-configured"})
    (ok true)))

;; Initial token distribution
(define-public (mint-initial-distribution)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (var-get initial-mint-complete)) err-already-minted)
    
    ;; Mint to distribution wallets
    (try! (ft-mint? flow community-rewards-amount (var-get community-rewards-wallet)))
    (try! (ft-mint? flow ecosystem-amount (var-get ecosystem-wallet)))
    (try! (ft-mint? flow team-amount (var-get team-wallet)))
    (try! (ft-mint? flow liquidity-amount (var-get liquidity-wallet)))
    (try! (ft-mint? flow public-amount (var-get public-distribution-wallet)))
    
    (var-set initial-mint-complete true)
    
    (print {
      event: "initial-mint-complete",
      total-minted: total-supply,
      community: community-rewards-amount,
      ecosystem: ecosystem-amount,
      team: team-amount,
      liquidity: liquidity-amount,
      public: public-amount
    })
    
    (ok true)))

;; Burn function (for future deflationary mechanisms)
(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (not (var-get paused)) err-paused)
    (asserts! (or (is-eq tx-sender owner) (is-eq tx-sender contract-owner)) err-not-token-owner)
    (asserts! (> amount u0) err-invalid-amount)
    (try! (ft-burn? flow amount owner))
    (print {
      event: "burn",
      owner: owner,
      amount: amount
    })
    (ok true)))

;; Read-only utilities
(define-read-only (get-contract-info)
  (ok {
    name: token-name,
    symbol: token-symbol,
    decimals: token-decimals,
    total-supply: total-supply,
    current-supply: (ft-get-supply flow),
    paused: (var-get paused),
    initial-mint-complete: (var-get initial-mint-complete)
  }))

(define-read-only (is-paused)
  (ok (var-get paused)))

;; Helper for formatting amounts (convert to human-readable)
(define-read-only (format-amount (amount uint))
  (ok (/ amount u1000000))) ;; Divide by 10^6 to get whole tokens
