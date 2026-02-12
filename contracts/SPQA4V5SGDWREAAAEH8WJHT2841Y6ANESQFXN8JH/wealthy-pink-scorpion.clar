;; Define variables to store vote counts
(define-data-var candidate-a uint u0)
(define-data-var candidate-b uint u0)

;; Public function to vote for Candidate A
(define-public (vote-for-a)
  (begin
    (var-set candidate-a (+ (var-get candidate-a) u1))
    (ok "Voted for A")
  )
)

;; Public function to vote for Candidate B
(define-public (vote-for-b)
  (begin
    (var-set candidate-b (+ (var-get candidate-b) u1))
    (ok "Voted for B")
  )
)

;; Read-only function to see current results
(define-read-only (get-results)
  { 
    candidate-a: (var-get candidate-a), 
    candidate-b: (var-get candidate-b) 
  }
)
