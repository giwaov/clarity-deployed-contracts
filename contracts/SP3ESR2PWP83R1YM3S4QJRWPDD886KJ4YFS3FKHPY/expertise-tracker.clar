;; Skill Tags - Tag users with skills
(define-map user-skills {user: principal, skill: (string-ascii 30)} {level: uint})

(define-public (add-skill (skill (string-ascii 30)) (level uint))
  (begin
    (map-set user-skills {user: tx-sender, skill: skill} {level: level})
    (ok true)))

(define-read-only (get-skill (user principal) (skill (string-ascii 30)))
  (map-get? user-skills {user: user, skill: skill}))
