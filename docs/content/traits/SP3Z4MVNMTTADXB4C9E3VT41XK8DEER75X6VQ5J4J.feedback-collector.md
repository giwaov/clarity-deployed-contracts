---
title: "Trait feedback-collector"
draft: true
---
```
;; Testimonial Board - Collect testimonials
(define-map testimonials uint {author: principal, subject: principal, text: (string-ascii 300)})
(define-data-var testimonial-id uint u0)

(define-public (submit-testimonial (subject principal) (text (string-ascii 300)))
  (let ((id (var-get testimonial-id)))
    (map-set testimonials id {author: tx-sender, subject: subject, text: text})
    (var-set testimonial-id (+ id u1))
    (ok id)))

(define-read-only (get-testimonial (id uint))
  (map-get? testimonials id))

```
