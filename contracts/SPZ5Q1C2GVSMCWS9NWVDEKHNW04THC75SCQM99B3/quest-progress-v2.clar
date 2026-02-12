;; title: quest-progress
;; summary: Records quest completions, mints badges, and awards XP
;; version: 1

(use-trait quest-registry-trait .quest-registry-trait-v2.quest-registry-trait)

;; constants
(define-constant err-not-owner (err u100))
(define-constant err-quest-not-found (err u101))
(define-constant err-quest-inactive (err u102))
(define-constant err-already-completed (err u103))
(define-constant err-mint-unavailable (err u106))

;; data vars
(define-data-var contract-admin principal tx-sender)
(define-data-var total-completions uint u0)

;; data maps
;; { player, quest-id } -> { completed: bool }
(define-map completions
  { player: principal, quest-id: uint }
  { completed: bool })
;; { player } -> { count: uint }
(define-map completion-counts { player: principal } { count: uint })

;; private helpers
(define-private (is-owner (who principal))
  (is-eq who (var-get contract-admin)))

(define-private (assert-owner (who principal))
  (is-owner who))

;; get the contract principal for configuration comparisons
(define-private (completed? (player principal) (quest-id uint))
  (is-some (map-get? completions { player: player, quest-id: quest-id })))

(define-private (increment-player-count (player principal))
  (let (
        (current (default-to u0 (get count (map-get? completion-counts { player: player }))))
        (next (+ current u1)))
    (map-set completion-counts { player: player } { count: next })
    next))

;; public functions

;; admin: set a new contract admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (assert-owner tx-sender) err-not-owner)
    (var-set contract-admin new-admin)
    (print { event: "set-admin", admin: new-admin })
    (ok true)))

;; public: complete a quest, mint a badge, and award XP
(define-public (complete-quest (quest-id uint))
  (let ((quest (unwrap! (contract-call? .quest-registry-v2 get-quest quest-id) err-quest-not-found)))
    (asserts! (get active quest) err-quest-inactive)
    (asserts! (not (completed? tx-sender quest-id)) err-already-completed)
    ;; ensure badge-nft is mintable (not paused / supply available)
    (asserts! (unwrap! (contract-call? .badge-nft-v2 can-mint) err-mint-unavailable) err-mint-unavailable)
    (let ((badge-uri (get badge-uri quest))
          (xp-reward (get xp-reward quest)))
      (match (contract-call? .badge-nft-v2 mint tx-sender badge-uri)
        minted-id
          (match (contract-call? .xp-ledger-v2 award-xp tx-sender xp-reward)
            xp-balance
              (begin
                (map-set completions { player: tx-sender, quest-id: quest-id } { completed: true })
                (increment-player-count tx-sender)
                (var-set total-completions (+ (var-get total-completions) u1))
                (print { event: "complete-quest", quest: quest-id, player: tx-sender, token-id: minted-id, xp: xp-reward })
                (ok { quest-id: quest-id, token-id: minted-id, xp-balance: xp-balance }))
            xp-err (err xp-err))
        mint-err (err mint-err)))))

;; read only functions

(define-read-only (has-completed (player principal) (quest-id uint))
  (ok (completed? player quest-id)))

(define-read-only (get-total-completions)
  (ok (var-get total-completions)))

(define-read-only (get-completion-count (player principal))
  (ok (default-to u0 (get count (map-get? completion-counts { player: player } )))))
