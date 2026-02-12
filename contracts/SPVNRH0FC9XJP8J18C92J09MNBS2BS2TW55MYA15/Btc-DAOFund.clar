;; title: Btc-DAOFund
;; version:
;; summary:
;; description:

;; token definitions  
(define-fungible-token sbtc-token)

;; constants
(define-constant err-not-member (err u101))
(define-constant err-proposal-not-found (err u102))
(define-constant err-voting-ended (err u103))
(define-constant err-insufficient-funds (err u104))

;; data vars
(define-data-var proposal-nonce uint u0)

;; data maps
(define-map dao-members principal bool)
(define-map proposals
  uint
  {
    creator: principal,
    amount: uint,
    recipient: principal,
    yes-votes: uint,
    no-votes: uint,
    end-block: uint,
    executed: bool
  }
)
(define-map member-votes { proposal-id: uint, voter: principal } bool)

;; public functions
(define-public (join-dao)
  (begin
    (map-set dao-members tx-sender true)
    (ok true)
  )
)

(define-public (deposit (amount uint))
  (begin
    (asserts! (is-member tx-sender) err-not-member)
    (ft-mint? sbtc-token amount tx-sender)
  )
)

(define-public (create-proposal (amount uint) (recipient principal))
  (let ((proposal-id (+ (var-get proposal-nonce) u1)))
    (asserts! (is-member tx-sender) err-not-member)
    (map-set proposals proposal-id {
      creator: tx-sender,
      amount: amount,
      recipient: recipient,
      yes-votes: u0,
      no-votes: u0,
      end-block: (+ stacks-block-height u144),
      executed: false
    })
    (var-set proposal-nonce proposal-id)
    (ok proposal-id)
  )
)

(define-public (vote (proposal-id uint) (vote-yes bool))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found)))
    (asserts! (is-member tx-sender) err-not-member)
    (asserts! (< stacks-block-height (get end-block proposal)) err-voting-ended)
    (asserts! (is-none (map-get? member-votes { proposal-id: proposal-id, voter: tx-sender })) (err u105))
    
    (map-set member-votes { proposal-id: proposal-id, voter: tx-sender } true)
    
    (if vote-yes
      (map-set proposals proposal-id (merge proposal { yes-votes: (+ (get yes-votes proposal) u1) }))
      (map-set proposals proposal-id (merge proposal { no-votes: (+ (get no-votes proposal) u1) }))
    )
    (ok true)
  )
)

;; read only functions
(define-read-only (is-member (user principal))
  (default-to false (map-get? dao-members user))
)


(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)
