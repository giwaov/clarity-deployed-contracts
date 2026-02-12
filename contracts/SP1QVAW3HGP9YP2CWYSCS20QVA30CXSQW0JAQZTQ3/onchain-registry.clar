;; title: onchain-registry
;; version:
;; summary:
;; description:

;; traits
;;
;; traits
;; Lottery Pool Smart Contract

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_LOTTERY_INACTIVE (err u102))
(define-constant ERR_INSUFFICIENT_BALANCE (err u103))
(define-constant ERR_INVALID_TICKET_PRICE (err u104))
(define-constant ERR_NO_WINNERS (err u105))
(define-constant ERR_NO_TICKETS (err u106))
(define-constant ERR_WITHDRAWAL_PERIOD_ENDED (err u107))
(define-constant ERR_LOTTERY_NOT_ENDED (err u108))
(define-constant ERR_WINNERS_ALREADY_SELECTED (err u109))
(define-constant ERR_INVALID_DURATION (err u110))
(define-constant ERR_INVALID_WITHDRAWAL_PERIOD (err u111))
(define-constant ERR_INVALID_WINNER_ID (err u112))

;; Data Variables
(define-data-var is-lottery-active bool false)
(define-data-var current-ticket-price uint u1000000) ;; 1 STX
(define-data-var current-lottery-pot uint u0)
(define-data-var total-tickets-sold uint u0)
(define-data-var number-of-winners uint u1)
(define-data-var lottery-end-block-height uint u0)
(define-data-var withdrawal-end-block-height uint u0)
(define-data-var organizer-fee-percentage uint u5) ;; 5% fee
(define-data-var prize-per-winner uint u0)
(define-data-var winners-selected bool false)

;; Maps
(define-map ticket-ownership {ticket-id: uint} {owner: principal})
(define-map user-ticket-count principal uint)
(define-map winners {winner-id: uint} {address: principal, claimed: bool})

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT_OWNER))

(define-private (validate-lottery-is-active)
  (if (var-get is-lottery-active)
    (ok true)
    ERR_LOTTERY_INACTIVE))

(define-private (validate-sufficient-balance (required-balance uint))
  (if (>= (stx-get-balance tx-sender) required-balance)
    (ok true)
    ERR_INSUFFICIENT_BALANCE))

(define-private (select-random-winner (random-seed uint) (ticket-id uint))
  (mod (+ random-seed ticket-id) (var-get total-tickets-sold)))

(define-private (calculate-organizer-fee (total-amount uint))
  (/ (* total-amount (var-get organizer-fee-percentage)) u100))

;; Public Functions
(define-public (start-new-lottery (duration-in-blocks uint) (withdrawal-period uint) (ticket-price uint) (winner-count uint) (fee-percentage uint))
  (begin
    (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
    (asserts! (> ticket-price u0) ERR_INVALID_TICKET_PRICE)
    (asserts! (> winner-count u0) ERR_NO_WINNERS)
    (asserts! (<= fee-percentage u20) ERR_NOT_AUTHORIZED) ;; Max 20% fee
    (asserts! (not (var-get is-lottery-active)) ERR_NOT_AUTHORIZED)
    (asserts! (> duration-in-blocks u0) ERR_INVALID_DURATION)
    (asserts! (> withdrawal-period u0) ERR_INVALID_WITHDRAWAL_PERIOD)
    (var-set is-lottery-active true)
    (var-set current-ticket-price ticket-price)
    (var-set current-lottery-pot u0)
    (var-set total-tickets-sold u0)
    (var-set number-of-winners winner-count)
    (var-set lottery-end-block-height (+ stacks-block-height duration-in-blocks))
    (var-set withdrawal-end-block-height (+ stacks-block-height withdrawal-period))
    (var-set organizer-fee-percentage fee-percentage)
    (var-set winners-selected false)
    (ok true)))



(define-public (select-winners (random-seed uint))
  (let ((winner-count (var-get number-of-winners))
        (total-ticket-count (var-get total-tickets-sold)))
    (begin
      (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
      (asserts! (not (var-get is-lottery-active)) ERR_LOTTERY_INACTIVE)
      (asserts! (not (var-get winners-selected)) ERR_WINNERS_ALREADY_SELECTED)
      (asserts! (> total-ticket-count u0) ERR_NO_WINNERS)
      (var-set winners-selected true)
      (let ((selected-winners (fold select-winner-and-save
                                    (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9)
                                    {random-seed: random-seed, current-winner-id: u0, remaining-winners: winner-count})))
        (ok (get current-winner-id selected-winners))))))

(define-private (select-winner-and-save (index uint) (context {random-seed: uint, current-winner-id: uint, remaining-winners: uint}))
  (if (> (get remaining-winners context) u0)
    (let ((winning-ticket-id (select-random-winner (get random-seed context) index))
          (winner-address (get owner (unwrap-panic (map-get? ticket-ownership {ticket-id: (+ winning-ticket-id u1)})))))
      (begin
        (map-set winners {winner-id: (get current-winner-id context)} {address: winner-address, claimed: false})
        {random-seed: (+ (get random-seed context) u1),
         current-winner-id: (+ (get current-winner-id context) u1),
         remaining-winners: (- (get remaining-winners context) u1)}))
    context))


;; Read-Only Functions
(define-read-only (get-current-ticket-price)
  (ok (var-get current-ticket-price)))

(define-read-only (get-current-lottery-pot)
  (ok (var-get current-lottery-pot)))

(define-read-only (get-user-ticket-count (user-address principal))
  (ok (default-to u0 (map-get? user-ticket-count user-address))))

(define-read-only (get-total-tickets-sold)
  (ok (var-get total-tickets-sold)))

(define-read-only (check-if-lottery-is-active)
  (ok (var-get is-lottery-active)))

(define-read-only (get-lottery-end-block-height)
  (ok (var-get lottery-end-block-height)))

(define-read-only (get-withdrawal-end-block-height)
  (ok (var-get withdrawal-end-block-height)))

(define-read-only (get-organizer-fee-percentage)
  (ok (var-get organizer-fee-percentage)))

(define-read-only (get-winner-info (winner-id uint))
  (ok (map-get? winners {winner-id: winner-id})))

(define-read-only (are-winners-selected)
  (ok (var-get winners-selected)))
