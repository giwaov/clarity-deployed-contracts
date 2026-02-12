;; ------------------------------------------------------------
;; ONE WORD STORY v2 - Clarity Contract
;; - Unlimited number of words (no small fixed list cap)
;; - Each entry is:
;;     - id        : auto-incrementing uint
;;     - word      : (string-ascii 32)
;;     - sender    : principal
;;     - timestamp : uint
;;     - category  : (string-ascii 32), e.g. "general", "tech"
;; ------------------------------------------------------------
;; Example usage (frontend):
;; 1. Call (add-word "hello" "general")
;; 2. Get total count with (get-word-count)
;; 3. Iterate ids [0..count-1] and call (get-word id)
;; 4. Use timestamps per sender to compute client-side streaks
;; ------------------------------------------------------------

;; Error codes
(define-constant ERR-WORD-NOT-FOUND (err u300))
(define-constant ERR-INVALID-WORD (err u301))
(define-constant ERR-INVALID-CATEGORY (err u302))

;; Default category used when caller does not provide one
;; or provides an empty string.
(define-constant DEFAULT-CATEGORY "general")

;; ------------------------------------------------------------
;; INTERNAL: Get current timestamp
;; For now this is a simple placeholder (u0). It is factored out
;; so it can be easily updated later if block time usage changes.
;; ------------------------------------------------------------
(define-private (get-now)
  u0
)

;; ------------------------------------------------------------
;; INTERNAL: Normalize category
;; - If the provided category is empty (zero-length), use DEFAULT-CATEGORY.
;; - Otherwise return the provided category unchanged.
;; ------------------------------------------------------------
(define-private (normalize-category (maybe-category (string-ascii 32)))
  (if (is-eq (len maybe-category) u0)
      DEFAULT-CATEGORY
      maybe-category
  )
)

;; ------------------------------------------------------------
;; PUBLIC: Add a new word to the story
;; Intended usage:
;; - Called directly by users from the frontend.
;; - Frontend should pass the selected category or an empty string ("")
;;   to fall back to DEFAULT-CATEGORY.
;; Parameters:
;; - word      : the one-word text (string-ascii 32)
;; - category  : optional category name; if empty, DEFAULT-CATEGORY is used
;; Returns:
;; - { id, word, category, timestamp, sender }
;; ------------------------------------------------------------
(define-public (add-word (word (string-ascii 32)) (category (string-ascii 32)))
  (let
    (
      (id (var-get next-word-id))
      (sender tx-sender)
      (time (get-now))
      (final-category (normalize-category category))
    )
    (begin
      ;; ensure the word is not empty
      (asserts! (> (len word) u0) ERR-INVALID-WORD)
      ;; basic validation: category (after normalization) must not be empty
      (asserts! (> (len final-category) u0) ERR-INVALID-CATEGORY)
      ;; store the new word
      (map-set words
        { id: id }
        {
          word: word,
          sender: sender,
          timestamp: time,
          category: final-category
        }
      )
      ;; increment the next-word-id counter
      (var-set next-word-id (+ id u1))
      ;; return basic info about the new entry
      (ok
        {
          id: id,
          word: word,
          category: final-category,
          timestamp: time,
          sender: sender
        }
      )
    )
  )
)

;; ------------------------------------------------------------
;; READ-ONLY: Get a word by its id
;; Intended usage:
;; - Frontend uses this to inspect a specific word, e.g. when iterating
;;   from 0 up to (get-word-count - 1).
;; Behavior:
;; - Returns (ok { word, sender, timestamp, category }) when found.
;; - Returns ERR-WORD-NOT-FOUND when no entry exists for that id.
;; ------------------------------------------------------------
(define-read-only (get-word (id uint))
  (let
    (
      (stored (map-get? words { id: id }))
    )
    (if (is-none stored)
        ERR-WORD-NOT-FOUND
        (ok (unwrap-panic stored))
    )
  )
)

;; ------------------------------------------------------------
;; READ-ONLY: Get the total number of words added so far
;; Intended usage:
;; - Frontend calls this once, then iterates ids [0..count-1]
;;   and calls (get-word id) for each.
;; Notes:
;; - This is equal to the current value of next-word-id,
;;   since ids start at 0 and increment by 1 for each new word.
;; ------------------------------------------------------------
(define-read-only (get-word-count)
  (ok (var-get next-word-id))
)

;; ------------------------------------------------------------
;; READ-ONLY: Get the latest word id (if any)
;; - Returns (ok some-id) when at least one word exists.
;; - Returns ERR-WORD-NOT-FOUND when there are no words yet.
;; ------------------------------------------------------------
(define-read-only (get-latest-id)
  (let
    (
      (count (var-get next-word-id))
    )
    (if (is-eq count u0)
        ERR-WORD-NOT-FOUND
        (ok (- count u1))
    )
  )
)

;; ------------------------------------------------------------
;; READ-ONLY: Get the latest word entry (if any)
;; - Uses get-latest-id to find the most recent id.
;; - Returns ERR-WORD-NOT-FOUND when there are no words yet.
;; ------------------------------------------------------------
(define-read-only (get-latest-word)
  (let
    (
      (latest-id-result (get-latest-id))
    )
    (match latest-id-result
      latest-id (get-word latest-id)
      err ERR-WORD-NOT-FOUND
    )
  )
)







;; ------------------------------------------------------------
;; DATA: Auto-incrementing ID counter for words
;; Starts at 0; each new word uses the current value, then increments.
;; ------------------------------------------------------------
(define-data-var next-word-id uint u0)

;; ------------------------------------------------------------
;; DATA: Storage for all words
;; Keyed by auto-incrementing id.
;; ------------------------------------------------------------
(define-map words
  {
    id: uint
  }
  {
    word: (string-ascii 32),     ;; the word itself
    sender: principal,           ;; who added it
    timestamp: uint,             ;; when it was added
    category: (string-ascii 32)  ;; e.g. "general", "tech"
  }
)


