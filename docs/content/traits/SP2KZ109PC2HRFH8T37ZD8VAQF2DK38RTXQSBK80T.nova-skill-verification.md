---
title: "Trait nova-skill-verification"
draft: true
---
```

;; nova-skill-verification.clar
;; Verify user skills
;; CLARITY VERSION: 2

(define-map user-skills
    {user: principal, skill: (string-ascii 32)}
    uint ;; Level
)

(define-public (endorse-skill (user principal) (skill (string-ascii 32)) (level uint))
    (begin
        ;; Admin check omitted
        (map-set user-skills {user: user, skill: skill} level)
        (ok true)
    )
)

(define-read-only (get-skill-level (user principal) (skill (string-ascii 32)))
    (default-to u0 (map-get? user-skills {user: user, skill: skill}))
)

```
