---
title: "Trait endorsements"
draft: true
---
```
;; Endorsements
(define-map endorsements {endorser: principal, endorsed: principal, skill: (string-ascii 50)} {endorsed: bool})
(define-public (endorse (endorsed principal) (skill (string-ascii 50)))
  (begin (map-set endorsements {endorser: tx-sender, endorsed: endorsed, skill: skill} {endorsed: true}) (ok true)))
(define-read-only (is-endorsed (endorser principal) (endorsed principal) (skill (string-ascii 50)))
  (default-to false (get endorsed (map-get? endorsements {endorser: endorser, endorsed: endorsed, skill: skill}))))

```
