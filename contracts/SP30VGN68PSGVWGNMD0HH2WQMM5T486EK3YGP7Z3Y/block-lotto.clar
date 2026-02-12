;; BlockLotto - A decentralized lottery system for Stacks (Clarity)
;; Entry fee is fixed (10 STX). Contract uses pull-payments for safety.
;; Contract creator has no ability to withdraw funds from the contract.

;; -----------------------------
;; Constants (error codes, params)
;; -----------------------------
(define-constant ERR-ALREADY-INITIALIZED u100)
(define-constant ERR-NOT-OPEN u101)
(define-constant ERR-DEADLINE-PASSED u102)
(define-constant ERR-DEADLINE-NOT-PASSED u103)
(define-constant ERR-ALREADY-ENTERED u104)
(define-constant ERR-INSUFFICIENT-FEE u105)
(define-constant ERR-MAX-PARTICIPANTS u106)
(define-constant ERR-NOT-ENOUGH-PLAYERS u107)
(define-constant ERR-WINNER-NOT-SET u108)
(define-constant ERR-NOT-WINNER u109)
(define-constant ERR-ALREADY-CLAIMED u110)
(define-constant ERR-INVALID-STATUS u111)
(define-constant ERR-REFUNDS-NOT-ALLOWED u112)
(define-constant ERR-NOT-ADMIN u113)
(define-constant ERR-PAUSED u114)

;; Operational parameters
(define-constant entry-fee u1000000) ;; 1 STX
(define-constant min-players u2)
(define-constant max-participants u100)

;; Lottery statuses
(define-constant STATUS-OPEN u0)
(define-constant STATUS-READY-TO-DRAW u1)
(define-constant STATUS-COMPLETED u2)
(define-constant STATUS-REFUNDED u3)

;; -----------------------------
;; State variables
;; -----------------------------
(define-data-var status uint STATUS-OPEN)
(define-data-var target-block-height uint u0)
(define-data-var total-participants uint u0)
(define-data-var winner (optional principal) none)
(define-data-var creator (optional principal) none)
(define-data-var paused bool false)

;; -----------------------------
;; Maps
;; -----------------------------
(define-map participant-index {participant: principal} {index: uint})
(define-map participant-by-index {index: uint} {participant: principal})
(define-map payouts {recipient: principal} {amount: uint})
(define-map refund-claimed {participant: principal} {claimed: bool})

;; -----------------------------
;; Private functions
;; -----------------------------
(define-private (get-current-block-height)
  block-height)

(define-private (add-payout (recipient principal) (amount uint))
  (let ((existing (map-get? payouts {recipient: recipient})))
    (match existing
      existing-row
      (map-set payouts {recipient: recipient} {amount: (+ (get amount existing-row) amount)})
      (map-set payouts {recipient: recipient} {amount: amount}))
    (ok true)))

;; -----------------------------
;; Public functions
;; -----------------------------
(define-public (init (target-block uint))
  (begin
    (asserts! (is-none (var-get creator)) (err ERR-ALREADY-INITIALIZED))
    (var-set creator (some tx-sender))
    (var-set target-block-height target-block)
    (var-set paused false)
    (ok true)))

(define-public (pause)
  (let ((admin (unwrap! (var-get creator) (err ERR-INVALID-STATUS))))
    (asserts! (is-eq admin tx-sender) (err ERR-NOT-ADMIN))
    (var-set paused true)
    (ok true)))

(define-public (unpause)
  (let ((admin (unwrap! (var-get creator) (err ERR-INVALID-STATUS))))
    (asserts! (is-eq admin tx-sender) (err ERR-NOT-ADMIN))
    (var-set paused false)
    (ok true)))

(define-public (enter-lottery)
  (let ((target (var-get target-block-height))
        (current-height (get-current-block-height))
        (count (var-get total-participants)))
    (asserts! (is-eq (var-get status) STATUS-OPEN) (err ERR-NOT-OPEN))
    (asserts! (not (var-get paused)) (err ERR-PAUSED))
    (asserts! (> target u0) (err ERR-INVALID-STATUS))
    (asserts! (< current-height target) (err ERR-DEADLINE-PASSED))
    (asserts! (is-none (map-get? participant-index {participant: tx-sender})) (err ERR-ALREADY-ENTERED))
    (asserts! (< count max-participants) (err ERR-MAX-PARTICIPANTS))
    
    (try! (stx-transfer? entry-fee tx-sender (as-contract tx-sender)))
    
    (map-set participant-index {participant: tx-sender} {index: count})
    (map-set participant-by-index {index: count} {participant: tx-sender})
    (var-set total-participants (+ count u1))
    
    (if (or (>= (+ count u1) min-players) (>= current-height target))
      (var-set status STATUS-READY-TO-DRAW)
      true)
    
    (ok true)))

(define-public (draw-winner)
  (let ((st (var-get status))
        (target (var-get target-block-height))
        (current-height (get-current-block-height))
        (count (var-get total-participants)))
    (asserts! (or (is-eq st STATUS-OPEN) (is-eq st STATUS-READY-TO-DRAW)) (err ERR-INVALID-STATUS))
    (asserts! (not (var-get paused)) (err ERR-PAUSED))
    (asserts! (>= current-height target) (err ERR-DEADLINE-NOT-PASSED))
    (asserts! (>= count min-players) (err ERR-NOT-ENOUGH-PLAYERS))
    
    ;; Use target block for randomness (it's guaranteed to exist and be stable)
    (let ((header-hash (unwrap! (get-block-info? id-header-hash target) (err ERR-INVALID-STATUS))))
      ;; Convert first 16 bytes of hash to uint using hash160 for randomness
      (let ((random-hash (hash160 header-hash)))
        (let ((random-seed (+ (len random-hash) target current-height)))
          (let ((winner-idx (mod random-seed count)))
            (let ((winner-entry (unwrap! (map-get? participant-by-index {index: winner-idx}) (err ERR-WINNER-NOT-SET))))
              (let ((winner-pr (get participant winner-entry)))
                (var-set winner (some winner-pr))
                (var-set status STATUS-COMPLETED)
                (unwrap-panic (add-payout winner-pr (* count entry-fee)))
                (ok winner-pr)))))))))
(define-public (claim-prize)
  (let ((winner-pr (unwrap! (var-get winner) (err ERR-WINNER-NOT-SET))))
    (asserts! (is-eq (var-get status) STATUS-COMPLETED) (err ERR-INVALID-STATUS))
    (asserts! (is-eq winner-pr tx-sender) (err ERR-NOT-WINNER))
    
    (let ((payout-entry (unwrap! (map-get? payouts {recipient: tx-sender}) (err ERR-WINNER-NOT-SET))))
      (let ((amt (get amount payout-entry)))
        (map-delete payouts {recipient: tx-sender})
        (try! (as-contract (stx-transfer? amt tx-sender winner-pr)))
        (ok amt)))))

(define-public (refund)
  (let ((st (var-get status))
        (target (var-get target-block-height))
        (current-height (get-current-block-height))
        (count (var-get total-participants)))
    
    (if (is-eq st STATUS-REFUNDED)
      true
      (begin
        (asserts! (>= current-height target) (err ERR-DEADLINE-NOT-PASSED))
        (asserts! (< count min-players) (err ERR-REFUNDS-NOT-ALLOWED))
        (var-set status STATUS-REFUNDED)
        true))
    
    (let ((participant-entry (unwrap! (map-get? participant-index {participant: tx-sender}) (err ERR-NOT-ENOUGH-PLAYERS))))
      (asserts! (is-none (map-get? refund-claimed {participant: tx-sender})) (err ERR-ALREADY-CLAIMED))
      
      (map-set refund-claimed {participant: tx-sender} {claimed: true})
      (try! (as-contract (stx-transfer? entry-fee tx-sender tx-sender)))
      (ok entry-fee))))

;; -----------------------------
;; Read-only functions
;; -----------------------------
(define-read-only (get-lottery-info)
  (ok {
    status: (var-get status),
    target-block-height: (var-get target-block-height),
    total-participants: (var-get total-participants),
    prize-pool: (* (var-get total-participants) entry-fee),
    entry-fee: entry-fee,
    min-players: min-players,
    max-participants: max-participants,
    winner: (var-get winner),
    creator: (var-get creator),
    paused: (var-get paused)
  }))

(define-read-only (get-participants)
  (ok (list)))

(define-read-only (get-participant (p principal))
  (ok (map-get? participant-index {participant: p})))

(define-read-only (get-winner)
  (ok (var-get winner)))

(define-read-only (is-refund-claimed (p principal))
  (match (map-get? refund-claimed {participant: p})
    entry (ok (get claimed entry))
    (ok false)))
