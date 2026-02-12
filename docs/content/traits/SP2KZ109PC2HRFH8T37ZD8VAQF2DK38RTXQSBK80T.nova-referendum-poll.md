---
title: "Trait nova-referendum-poll"
draft: true
---
```

;; nova-referendum-poll.clar
;; Simple poll mechanism
;; CLARITY VERSION: 2

(define-map polls
    uint
    {
        question: (string-ascii 64),
        yes: uint,
        no: uint,
        ended: bool
    }
)
(define-data-var poll-nonce uint u0)

(define-public (create-poll (question (string-ascii 64)))
    (let ((id (var-get poll-nonce)))
        (map-set polls id {question: question, yes: u0, no: u0, ended: false})
        (var-set poll-nonce (+ id u1))
        (ok id)
    )
)

(define-public (vote (poll-id uint) (vote-yes bool))
    (let ((poll (unwrap! (map-get? polls poll-id) (err u404))))
        (asserts! (not (get ended poll)) (err u100))
        (map-set polls poll-id
            (if vote-yes
                (merge poll {yes: (+ (get yes poll) u1)})
                (merge poll {no: (+ (get no poll) u1)})
            )
        )
        (ok true)
    )
)

```
