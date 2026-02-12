---
title: "Trait poet-pre-faktory"
draft: true
---
```
;; SP2QXPFF4M72QYZWXE7S5321XJDJ2DD32DGEMN5QA.poet-pre-faktory
;; PoetAI Pre-Launch - Seat sales with vesting
;; 20 seats, 10 min users, 20K sats per seat

(use-trait faktory-token 'SP3XXMS38VTAWTVPE5682XSBFXPTH7XCPEBTX8AN2.faktory-trait-v1.sip-010-trait)

(define-constant SEATS u20)
(define-constant MIN-USERS u10)
(define-constant MAX-SEATS-PER-USER u7)
(define-constant PRICE-PER-SEAT u20000)
(define-constant TOKENS-PER-SEAT u200000000000000)
(define-constant DEX-AMOUNT u250000)
(define-constant MULTI-SIG-AMOUNT u10000)
(define-constant FEE-AMOUNT u140000)
(define-constant FT-INITIALIZED-BALANCE u4000000000000000)

(define-constant TOKEN-DAO 'SP2QXPFF4M72QYZWXE7S5321XJDJ2DD32DGEMN5QA.poet-faktory)
(define-constant DEX-DAO 'SP2QXPFF4M72QYZWXE7S5321XJDJ2DD32DGEMN5QA.poet-faktory-dex)
(define-constant FAKTORY1 'SMH8FRN30ERW1SX26NJTJCKTDR3H27NRJ6W75WQE)
(define-constant FAKTORY2 'SM362G0X1YNB2M3FWWFAASV9WB3XHQ8RWP512SSX3)

(define-constant VESTING-SCHEDULE (list
  {height: u100, percent: u10, id: u0}
  {height: u250, percent: u3, id: u1}
  {height: u400, percent: u3, id: u2}
  {height: u550, percent: u3, id: u3}
  {height: u700, percent: u3, id: u4}
  {height: u850, percent: u4, id: u5}
  {height: u1000, percent: u4, id: u6}
  {height: u1200, percent: u4, id: u7}
  {height: u1400, percent: u4, id: u8}
  {height: u1600, percent: u4, id: u9}
  {height: u1750, percent: u4, id: u10}
  {height: u1900, percent: u4, id: u11}
  {height: u2000, percent: u5, id: u12}
  {height: u2100, percent: u5, id: u13}
  {height: u2500, percent: u5, id: u14}
  {height: u2900, percent: u5, id: u15}
  {height: u3300, percent: u6, id: u16}
  {height: u3600, percent: u6, id: u17}
  {height: u3900, percent: u6, id: u18}
  {height: u4100, percent: u6, id: u19}
  {height: u4200, percent: u6, id: u20}))

(define-data-var ft-balance uint u0)
(define-data-var stx-balance uint u0)
(define-data-var total-seats-taken uint u0)
(define-data-var total-users uint u0)
(define-data-var distribution-height uint u0)
(define-data-var deployment-height uint burn-block-height)
(define-data-var accelerated-vesting bool false)
(define-data-var market-open bool false)
(define-data-var governance-active bool false)
(define-data-var seat-holders (list 20 {owner: principal, seats: uint}) (list))
(define-data-var accumulated-fees uint u0)
(define-data-var last-airdrop-height (optional uint) (some u0))
(define-data-var final-airdrop-mode bool false)
(define-data-var acc-distributed uint u0)

(define-map seats-owned principal uint)
(define-map claimed-amounts principal uint)

(define-constant ERR-NO-SEATS-LEFT (err u301))
(define-constant ERR-NOT-SEAT-OWNER (err u302))
(define-constant ERR-NOTHING-TO-CLAIM (err u304))
(define-constant ERR-NOT-AUTHORIZED (err u305))
(define-constant ERR-WRONG-TOKEN (err u307))
(define-constant ERR-CONTRACT-INSUFFICIENT-FUNDS (err u311))
(define-constant ERR-INVALID-SEAT-COUNT (err u313))
(define-constant ERR-DISTRIBUTION-ALREADY-SET (err u320))
(define-constant ERR-DISTRIBUTION-NOT-INITIALIZED (err u321))
(define-constant ERR-NO-FEES (err u323))
(define-constant ERR-COOLDOWN (err u324))
(define-constant COOLDOWN-PERIOD u2100)

(define-private (update-seat-holder (owner principal) (seat-count uint))
  (let ((current-holders (var-get seat-holders)))
    (var-set seat-holders (unwrap-panic (as-max-len? (append current-holders {owner: owner, seats: seat-count}) u20)))))

(define-read-only (get-max-seats-allowed)
  (let ((users-now (var-get total-users))
        (seats-left (- SEATS (var-get total-seats-taken))))
    (if (>= users-now MIN-USERS) (if (> seats-left MAX-SEATS-PER-USER) MAX-SEATS-PER-USER seats-left)
        (let ((users-needed (- MIN-USERS users-now))
              (max-possible (+ (- seats-left users-needed) u1)))
          (if (>= max-possible MAX-SEATS-PER-USER) MAX-SEATS-PER-USER max-possible)))))

(define-public (buy-up-to (seat-count uint))
  (let ((current-seats (var-get total-seats-taken))
        (user-seats (default-to u0 (map-get? seats-owned tx-sender)))
        (max-allowed (get-max-seats-allowed))
        (actual-seats (if (> seat-count max-allowed) max-allowed seat-count)))
    (asserts! (is-eq (var-get distribution-height) u0) ERR-DISTRIBUTION-ALREADY-SET)
    (asserts! (> actual-seats u0) ERR-INVALID-SEAT-COUNT)
    (asserts! (<= (+ user-seats actual-seats) MAX-SEATS-PER-USER) ERR-INVALID-SEAT-COUNT)
    (asserts! (< current-seats SEATS) ERR-NO-SEATS-LEFT)
    (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer (* PRICE-PER-SEAT actual-seats) tx-sender (as-contract tx-sender) none))
    (if (is-eq user-seats u0) (var-set total-users (+ (var-get total-users) u1)) true)
    (map-set seats-owned tx-sender (+ user-seats actual-seats))
    (var-set total-seats-taken (+ current-seats actual-seats))
    (var-set stx-balance (+ (var-get stx-balance) (* PRICE-PER-SEAT actual-seats)))
    (update-seat-holder tx-sender (+ user-seats actual-seats))
    (if (and (>= (var-get total-users) MIN-USERS) (>= (var-get total-seats-taken) SEATS))
        (try! (initialize-distribution)) true)
    (ok true)))

(define-private (initialize-distribution)
  (begin
    (var-set market-open true)
    (var-set governance-active true)
    (try! (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer DEX-AMOUNT tx-sender DEX-DAO none)))
    (try! (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer MULTI-SIG-AMOUNT tx-sender FAKTORY1 none)))
    (try! (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer FEE-AMOUNT tx-sender FAKTORY2 none)))
    (var-set distribution-height burn-block-height)
    (var-set last-airdrop-height (some burn-block-height))
    (var-set ft-balance FT-INITIALIZED-BALANCE)
    (var-set stx-balance u0)
    (ok true)))

(define-private (get-claimable-amount (owner principal))
  (if (> (var-get distribution-height) u0)
      (let ((claimed (default-to u0 (map-get? claimed-amounts owner)))
            (seats-owner (default-to u0 (map-get? seats-owned owner)))
            (vested (fold check-claimable VESTING-SCHEDULE u0)))
        (- (* vested seats-owner) claimed))
      u0))

(define-private (check-claimable (entry {height: uint, percent: uint, id: uint}) (total uint))
  (let ((start (var-get distribution-height)))
    (if (<= (+ start (get height entry)) burn-block-height)
        (+ total (/ (* TOKENS-PER-SEAT (get percent entry)) u100))
        (if (and (var-get accelerated-vesting) (<= (get id entry) u13))
            (+ total (/ (* TOKENS-PER-SEAT (get percent entry)) u100))
            total))))

(define-public (claim (ft <faktory-token>))
  (let ((claimable (get-claimable-amount tx-sender)))
    (asserts! (> (var-get distribution-height) u0) ERR-DISTRIBUTION-NOT-INITIALIZED)
    (asserts! (is-eq (contract-of ft) TOKEN-DAO) ERR-WRONG-TOKEN)
    (asserts! (> claimable u0) ERR-NOTHING-TO-CLAIM)
    (asserts! (>= (var-get ft-balance) claimable) ERR-CONTRACT-INSUFFICIENT-FUNDS)
    (try! (as-contract (contract-call? ft transfer claimable tx-sender tx-sender none)))
    (map-set claimed-amounts tx-sender (+ (default-to u0 (map-get? claimed-amounts tx-sender)) claimable))
    (var-set ft-balance (- (var-get ft-balance) claimable))
    (ok claimable)))

(define-public (toggle-bonded)
  (begin
    (asserts! (is-eq contract-caller DEX-DAO) ERR-NOT-AUTHORIZED)
    (var-set accelerated-vesting true)
    (var-set final-airdrop-mode true)
    (ok true)))

(define-public (create-fees-receipt (amount uint))
  (begin
    (asserts! (is-eq contract-caller DEX-DAO) ERR-NOT-AUTHORIZED)
    (var-set accumulated-fees (+ (var-get accumulated-fees) amount))
    (ok true)))

(define-read-only (is-market-open) (ok (var-get market-open)))
(define-read-only (is-governance-active) (ok (var-get governance-active)))
(define-read-only (get-contract-status)
  (ok {distribution-period: (> (var-get distribution-height) u0), total-users: (var-get total-users),
       total-seats-taken: (var-get total-seats-taken), market-open: (var-get market-open)}))
(define-read-only (get-user-info (user principal))
  (ok {seats-owned: (default-to u0 (map-get? seats-owned user)),
       claimed: (default-to u0 (map-get? claimed-amounts user)),
       claimable: (get-claimable-amount user)}))
```
