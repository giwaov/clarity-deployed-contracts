---
title: "Trait survey-alpha"
draft: true
---
```
;; Survey contract for collecting responses
(define-map surveys {id: uint} {creator: principal, question: (string-utf8 256), active: bool})
(define-map responses {survey-id: uint, respondent: principal} (string-utf8 256))
(define-data-var survey-counter uint u0)

(define-read-only (get-survey (id uint))
  (map-get? surveys {id: id})
)

(define-public (create-survey (question (string-utf8 256)))
  (let ((id (var-get survey-counter)))
    (begin
      (map-set surveys {id: id} {
        creator: tx-sender,
        question: question,
        active: true
      })
      (ok (var-set survey-counter (+ id u1)))
    )
  )
)

(define-public (respond (survey-id uint) (response (string-utf8 256)))
  (begin
    (asserts! (is-some (map-get? surveys {id: survey-id})) (err u1))
    (ok (map-set responses {survey-id: survey-id, respondent: tx-sender} response))
  )
)

```
