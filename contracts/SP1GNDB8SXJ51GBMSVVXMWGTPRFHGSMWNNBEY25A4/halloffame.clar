;; title: halloffame
;; version: 1.0
;; summary: A leaderboard contract with ranking and counter functionality

;; constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-SCORE-NOT-HIGHER (err u101))

;; data vars
(define-data-var counter int 0)
(define-data-var top-ten (list 10 {player: principal, score: uint}) (list))

;; data maps
(define-map player-scores principal uint)

;; public functions

;; --- Counter Functions ---

(define-public (increment)
  (begin
    (var-set counter (+ (var-get counter) 1))
    (ok (var-get counter))
  )
)

(define-public (decrement)
  (begin
    (var-set counter (- (var-get counter) 1))
    (ok (var-get counter))
  )
)

;; --- Leaderboard Functions ---

(define-public (submit-score (score uint))
  (let
    (
      (current-best (default-to u0 (map-get? player-scores tx-sender)))
    )
    (asserts! (> score current-best) ERR-SCORE-NOT-HIGHER)
    (map-set player-scores tx-sender score)
    (update-top-ten tx-sender score)
    (ok true)
  )
)

;; private functions

(define-private (update-top-ten (player principal) (score uint))
  (let
    (
      (current-list (var-get top-ten))
      ;; First remove the player if they are already in the list
      (clean-list (filter-out-sender current-list))
      ;; Insert the new score in the correct position
      (new-list (insert-score-wrapper clean-list player score))
    )
    (var-set top-ten new-list)
  )
)

;; Filter to remove tx-sender from the list
(define-private (filter-out-sender (l (list 10 {player: principal, score: uint})))
  (filter is-not-sender l)
)

(define-private (is-not-sender (entry {player: principal, score: uint}))
  (not (is-eq (get player entry) tx-sender))
)

;; Step function for fold
;; Accumulator: {inserted: bool, result-list: (list 10 ...), new-player: principal, new-score: uint}
(define-private (insert-entry-step 
    (entry {player: principal, score: uint}) 
    (state {inserted: bool, result-list: (list 10 {player: principal, score: uint}), new-player: principal, new-score: uint})
  )
  (let
    (
      (score-to-insert (get new-score state))
      (player-to-insert (get new-player state))
      (current-result (get result-list state))
      (already-inserted (get inserted state))
    )
    (if already-inserted
      ;; If already inserted, just append the current entry (if room)
      (merge state {
        result-list: (unwrap-panic (as-max-len? (append current-result entry) u10))
      })
      ;; If not yet inserted, checking order
      (if (> score-to-insert (get score entry))
        ;; New score is higher than current entry -> insert new score, THEN current entry
        (let
          (
            ;; Try to add new score
            (list-with-new (unwrap-panic (as-max-len? (append current-result {player: player-to-insert, score: score-to-insert}) u10)))
            ;; Try to add the current entry after (might get dropped if list full)
            (final-list-opt (as-max-len? (append list-with-new entry) u10))
          )
          (match final-list-opt
            success-list (merge state {inserted: true, result-list: success-list})
            ;; If we couldn't fit the specified entry it means list is full.
            ;; We have inserted the new higher score, so the current (lower) entry is the one that drops off.
            (merge state {inserted: true, result-list: list-with-new})
          )
        )
        ;; New score is lower or equal -> append current entry
        (merge state {
            result-list: (unwrap-panic (as-max-len? (append current-result entry) u10))
        })
      )
    )
  )
)

(define-private (insert-score-wrapper (l (list 10 {player: principal, score: uint})) (new-player principal) (new-score uint))
    (let
        (
            (fold-res (fold insert-entry-step l {inserted: false, result-list: (list), new-player: new-player, new-score: new-score}))
            (final-list (get result-list fold-res))
            (was-inserted (get inserted fold-res))
        )
        (if (not was-inserted)
            ;; Try to append at the end if not inserted yet
            (unwrap! (as-max-len? (append final-list {player: new-player, score: new-score}) u10) final-list)
            final-list
        )
    )
)

;; read only functions

(define-read-only (get-counter)
  (ok (var-get counter))
)

(define-read-only (get-top-ten)
  (ok (var-get top-ten))
)

(define-read-only (get-player-score (player principal))
  (ok (default-to u0 (map-get? player-scores player)))
)
