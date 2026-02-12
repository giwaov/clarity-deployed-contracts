;; title: braingame
;; version: 1.0.0
;; summary: A simple on-chain quiz smart contract for Stacks blockchain
;; description: Create quizzes, test knowledge, score answers, and compete on the leaderboard

;; traits
;;

;; token definitions
;;

;; constants
;;

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_QUIZ_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_TAKEN (err u102))
(define-constant ERR_INVALID_ANSWERS (err u103))
(define-constant ERR_INVALID_QUIZ_DATA (err u104))
(define-constant ERR_UNDERFLOW (err u105))

;; Maximum questions per quiz
(define-constant MAX_QUESTIONS u20)

;; ============================================
;; data vars
;;

;; Counter for general testing
(define-data-var counter uint u0)

;; Quiz ID counter
(define-data-var next-quiz-id uint u0)

;; ============================================
;; data maps
;;

;; Quiz storage: quiz-id -> quiz data
(define-map quizzes
  uint
  {
    title: (string-ascii 100),
    creator: principal,
    question-count: uint,
    questions: (list 20 (string-ascii 200)),
    correct-answers: (list 20 uint),
    total-attempts: uint,
    created-at: uint
  }
)

;; Quiz scores: {quiz-id, player} -> score data
(define-map quiz-scores
  {quiz-id: uint, player: principal}
  {
    score: uint,
    percentage: uint,
    submitted-at: uint
  }
)

;; Player statistics: player -> stats
(define-map player-stats
  principal
  {
    quizzes-taken: uint,
    total-score: uint,
    best-score: uint
  }
)

;; ============================================
;; public functions
;;

;; --- Counter Functions (for testing) ---

;; Increment the counter
(define-public (increment)
  (let
    ((new-value (+ (var-get counter) u1)))
    (begin
      (var-set counter new-value)
      (print {
        event: "counter-incremented",
        caller: tx-sender,
        new-value: new-value,
        block-height: stacks-block-height
      })
      (ok new-value)
    )
  )
)

;; Decrement the counter
(define-public (decrement)
  (let 
    ((current-value (var-get counter)))
    (begin
      ;; Prevent underflow
      (asserts! (> current-value u0) ERR_UNDERFLOW)
      (let
        ((new-value (- current-value u1)))
        (begin
          (var-set counter new-value)
          (print {
            event: "counter-decremented",
            caller: tx-sender,
            new-value: new-value,
            block-height: stacks-block-height
          })
          (ok new-value)
        )
      )
    )
  )
)

;; --- Quiz Core Functions ---

;; Create a new quiz
(define-public (create-quiz 
  (title (string-ascii 100))
  (questions (list 20 (string-ascii 200)))
  (correct-answers (list 20 uint))
)
  (let
    (
      (quiz-id (var-get next-quiz-id))
      (question-count (len questions))
      (answer-count (len correct-answers))
    )
    (begin
      ;; Validate inputs
      (asserts! (> question-count u0) ERR_INVALID_QUIZ_DATA)
      (asserts! (<= question-count MAX_QUESTIONS) ERR_INVALID_QUIZ_DATA)
      (asserts! (is-eq question-count answer-count) ERR_INVALID_QUIZ_DATA)
      
      ;; Store quiz data
      (map-set quizzes quiz-id
        {
          title: title,
          creator: tx-sender,
          question-count: question-count,
          questions: questions,
          correct-answers: correct-answers,
          total-attempts: u0,
          created-at: stacks-block-height
        }
      )
      
      ;; Increment quiz ID counter
      (var-set next-quiz-id (+ quiz-id u1))
      
      ;; Emit event
      (print {
        event: "quiz-created",
        quiz-id: quiz-id,
        title: title,
        creator: tx-sender,
        question-count: question-count,
        created-at: stacks-block-height
      })
      
      (ok quiz-id)
    )
  )
)

;; Submit answers to a quiz
(define-public (submit-answers
  (quiz-id uint)
  (answers (list 20 uint))
)
  (let
    (
      (quiz-data (unwrap! (map-get? quizzes quiz-id) ERR_QUIZ_NOT_FOUND))
      (player tx-sender)
      (answer-count (len answers))
      (question-count (get question-count quiz-data))
      (correct-answers (get correct-answers quiz-data))
    )
    (begin
      ;; Check if player already took this quiz
      (asserts! (is-none (map-get? quiz-scores {quiz-id: quiz-id, player: player})) ERR_ALREADY_TAKEN)
      
      ;; Validate answer count matches question count
      (asserts! (is-eq answer-count question-count) ERR_INVALID_ANSWERS)
      
      ;; Calculate score
      (let
        (
          (score (calculate-score answers correct-answers))
          (percentage (/ (* score u100) question-count))
        )
        (begin
          ;; Store score
          (map-set quiz-scores
            {quiz-id: quiz-id, player: player}
            {
              score: score,
              percentage: percentage,
              submitted-at: stacks-block-height
            }
          )
          
          ;; Update quiz attempt count
          (map-set quizzes quiz-id
            (merge quiz-data {total-attempts: (+ (get total-attempts quiz-data) u1)})
          )
          
          ;; Update player stats
          (update-player-stats player score percentage)
          
          ;; Emit event
          (print {
            event: "quiz-submitted",
            quiz-id: quiz-id,
            player: player,
            score: score,
            percentage: percentage,
            submitted-at: stacks-block-height
          })
          
          (ok {score: score, percentage: percentage})
        )
      )
    )
  )
)

;; ============================================
;; read only functions
;;

;; Get counter value
(define-read-only (get-counter)
  (ok (var-get counter))
)

;; Get current block height
(define-read-only (get-current-block)
  (ok stacks-block-height)
)

;; Get total number of quizzes
(define-read-only (get-total-quizzes)
  (ok (var-get next-quiz-id))
)

;; Get quiz information
(define-read-only (get-quiz-info (quiz-id uint))
  (match (map-get? quizzes quiz-id)
    quiz (ok {
      title: (get title quiz),
      creator: (get creator quiz),
      question-count: (get question-count quiz),
      total-attempts: (get total-attempts quiz),
      created-at: (get created-at quiz)
    })
    ERR_QUIZ_NOT_FOUND
  )
)

;; Get quiz questions
(define-read-only (get-quiz-questions (quiz-id uint))
  (match (map-get? quizzes quiz-id)
    quiz (ok (get questions quiz))
    ERR_QUIZ_NOT_FOUND
  )
)

;; Get player's score for a specific quiz
(define-read-only (get-quiz-score (quiz-id uint) (player principal))
  (match (map-get? quiz-scores {quiz-id: quiz-id, player: player})
    score-data (ok score-data)
    (ok {score: u0, percentage: u0, submitted-at: u0})
  )
)

;; Check if player has taken a quiz
(define-read-only (has-taken-quiz (quiz-id uint) (player principal))
  (ok (is-some (map-get? quiz-scores {quiz-id: quiz-id, player: player})))
)

;; Get player statistics
(define-read-only (get-player-stats (player principal))
  (match (map-get? player-stats player)
    stats (ok stats)
    (ok {quizzes-taken: u0, total-score: u0, best-score: u0})
  )
)

;; ============================================
;; private functions
;;

;; Calculate score by comparing answers
(define-private (calculate-score
  (answers (list 20 uint))
  (correct-answers (list 20 uint))
)
  (let
    (
      (comparison (map compare-answer answers correct-answers))
    )
    (fold + comparison u0)
  )
)

;; Compare a single answer (returns 1 if correct, 0 if wrong)
(define-private (compare-answer (answer uint) (correct uint))
  (if (is-eq answer correct) u1 u0)
)

;; Update player statistics
(define-private (update-player-stats (player principal) (score uint) (percentage uint))
  (let
    (
      (current-stats (default-to 
        {quizzes-taken: u0, total-score: u0, best-score: u0}
        (map-get? player-stats player)
      ))
      (new-quizzes-taken (+ (get quizzes-taken current-stats) u1))
      (new-total-score (+ (get total-score current-stats) percentage))
      (new-best-score (if (> percentage (get best-score current-stats))
        percentage
        (get best-score current-stats)
      ))
    )
    (map-set player-stats player
      {
        quizzes-taken: new-quizzes-taken,
        total-score: new-total-score,
        best-score: new-best-score
      }
    )
  )
)
