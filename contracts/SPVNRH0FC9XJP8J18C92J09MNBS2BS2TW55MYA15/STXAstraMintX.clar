;; title: STXAstraMintX
;; version:
;; summary:
;; description:

;;STX-AstraMint Token Contract
;; Enhanced fungible token implementation with advanced features and security

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-INVALID-RECIPIENT (err u103))
(define-constant ERR-INVALID-SPENDER (err u104))
(define-constant ERR-OVERFLOW (err u105))
(define-constant ERR-PAUSED (err u106))
(define-constant ERR-ALREADY-INITIALIZED (err u107))
(define-constant ERR-NOT-INITIALIZED (err u108))
(define-constant ERR-BLACKLISTED (err u109))
(define-constant ERR-MAX-SUPPLY-REACHED (err u110))
(define-constant ERR-ZERO-ADDRESS (err u111))
(define-constant ERR-SELF-TRANSFER (err u112))
(define-constant ERR-EXPIRED-ALLOWANCE (err u113))



(define-constant MAX-SUPPLY u1000000000000000) ;; 1 trillion tokens
(define-constant PRECISION u1000000) ;; 6 decimal places

;; Define token
(define-fungible-token stellar)


;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var token-name (string-ascii 32) "Stellar Token")
(define-data-var token-symbol (string-ascii 10) "STLR")
(define-data-var token-decimals uint u6)
(define-data-var total-supply uint u0)
(define-data-var paused bool false)
(define-data-var initialized bool false)
(define-data-var last-event-id uint u0)



;;;;;;;; Data Maps;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-map allowances 
    { owner: principal, spender: principal }
    { amount: uint, expiry: uint })

;;
(define-map locked-tokens
    { address: principal }
    { amount: uint, unlock-height: uint })

;;
(define-map governance-tokens
    { holder: principal }
    { voting-power: uint, last-vote-height: uint })

;;
(define-map restricted-addresses 
    { address: principal } 
    { blocked-height: uint })

;;
(define-map minter-roles 
    { address: principal } 
    { can-mint: bool, mint-allowance: uint })


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Private Functions ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-private (is-contract-owner)
    (is-eq tx-sender (var-get contract-owner)))

(define-private (is-valid-recipient (recipient principal))
    (and
        (not (is-eq recipient tx-sender))
        (not (is-restricted recipient))
        (not (is-eq recipient (var-get contract-owner)))))

(define-private (is-restricted (address principal))
    (match (map-get? restricted-addresses { address: address })
        restriction-data true
        false))

(define-private (check-initialized)
    (if (var-get initialized)
        (ok true)
        ERR-NOT-INITIALIZED))

(define-private (check-not-paused)
    (if (not (var-get paused))
        (ok true)
        ERR-PAUSED))

(define-private (safe-add (a uint) (b uint))
    (let ((sum (+ a b)))
        (if (>= sum a)
            (ok sum)
            ERR-OVERFLOW)))

(define-private (emit-transfer-event (from principal) (to principal) (amount uint))
    (begin
        (var-set last-event-id (+ (var-get last-event-id) u1))
        (print { type: "transfer", id: (var-get last-event-id), from: from, to: to, amount: amount })))

(define-private (emit-mint-event (to principal) (amount uint))
    (begin
        (var-set last-event-id (+ (var-get last-event-id) u1))
        (print { type: "mint", id: (var-get last-event-id), to: to, amount: amount })))

(define-private (emit-burn-event (from principal) (amount uint))
    (begin
        (var-set last-event-id (+ (var-get last-event-id) u1))
        (print { type: "burn", id: (var-get last-event-id), from: from, amount: amount })))





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; Read-Only Functions ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-read-only (get-name)
    (ok (var-get token-name)))

(define-read-only (get-symbol)
    (ok (var-get token-symbol)))

(define-read-only (get-decimals)
    (ok (var-get token-decimals)))

(define-read-only (get-total-supply)
    (ok (var-get total-supply)))

(define-read-only (get-balance (account principal))
    (ok (ft-get-balance stellar account)))

(define-read-only (get-allowance (owner principal) (spender principal))
    (match (map-get? allowances { owner: owner, spender: spender })
        allowance-data (let ((current-height stacks-block-time))
            (if (>= current-height (get expiry allowance-data))
                (ok u0)
                (ok (get amount allowance-data))))
        (ok u0)))

(define-read-only (is-locked (address principal))
    (match (map-get? locked-tokens { address: address })
        lock-data (> (get unlock-height lock-data) stacks-block-time)
        false))



;;;;; PUBLIC FUNCTIONS ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Administrative Functions
(define-public (initialize (name (string-ascii 32)) (symbol (string-ascii 10)) (decimals uint))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (not (var-get initialized)) ERR-ALREADY-INITIALIZED)

        ;; Validate name
        (asserts! (>= (len name) u1) ERR-INVALID-AMOUNT)  ;; Ensure name is not empty
        (asserts! (<= (len name) u32) ERR-INVALID-AMOUNT)  ;; Extra safety check for length

        ;; Validate symbol
        (asserts! (>= (len symbol) u1) ERR-INVALID-AMOUNT)  ;; Ensure symbol is not empty
        (asserts! (<= (len symbol) u10) ERR-INVALID-AMOUNT)  ;; Extra safety check for length

        ;; Validate decimals (common values are 6, 8, or 18)
        (asserts! (<= decimals u18) ERR-INVALID-AMOUNT)  ;; Ensure decimals is reasonable
        (asserts! (>= decimals u0) ERR-INVALID-AMOUNT)   ;; Ensure decimals is non-negative

        ;; After validation, set the values
        (var-set token-name name)
        (var-set token-symbol symbol)
        (var-set token-decimals decimals)
        (var-set initialized true)
        (ok true)))


(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (not (is-eq new-owner (var-get contract-owner))) ERR-INVALID-RECIPIENT)
        (var-set contract-owner new-owner)
        (ok true)))

(define-public (pause)
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (var-set paused true)
        (ok true)))

(define-public (unpause)
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (var-set paused false)
        (ok true)))

;; Token Operations
(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (is-valid-recipient recipient) ERR-INVALID-RECIPIENT)
        (try! (check-initialized))
        (try! (check-not-paused))

        (let ((new-supply (try! (safe-add (var-get total-supply) amount))))
            (asserts! (<= new-supply MAX-SUPPLY) ERR-MAX-SUPPLY-REACHED)

            (try! (ft-mint? stellar amount recipient))
            (var-set total-supply new-supply)

            (map-set governance-tokens
                { holder: recipient }
                { 
                    voting-power: (unwrap! (safe-add 
                        (default-to u0 (get voting-power (map-get? governance-tokens { holder: recipient }))) 
                        amount) ERR-OVERFLOW),
                    last-vote-height: stacks-block-time
                })
            (ok true))))
