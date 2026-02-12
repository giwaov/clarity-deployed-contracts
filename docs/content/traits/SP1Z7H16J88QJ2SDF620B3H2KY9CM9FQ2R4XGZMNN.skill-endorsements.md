---
title: "Trait skill-endorsements"
draft: true
---
```
;; Skill Endorsements
(define-map skills {user: principal, skill: (string-ascii 30)} {endorsement-count: uint})
(define-public (endorse-skill (user principal) (skill (string-ascii 30)))
  (let ((current (default-to u0 (get endorsement-count (map-get? skills {user: user, skill: skill})))))
    (map-set skills {user: user, skill: skill} {endorsement-count: (+ current u1)})
    (ok true)))
(define-read-only (get-skill-endorsements (user principal) (skill (string-ascii 30)))
  (map-get? skills {user: user, skill: skill}))

```
