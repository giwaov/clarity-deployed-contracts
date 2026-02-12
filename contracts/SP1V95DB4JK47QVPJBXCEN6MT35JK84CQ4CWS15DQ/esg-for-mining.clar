(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map mining-projects
  uint
  {
    operator: principal,
    location: (string-ascii 256),
    environmental-score: uint,
    social-score: uint,
    governance-score: uint,
    overall-esg-rating: (string-ascii 8),
    last-assessment: uint,
    compliant: bool
  })

(define-map esg-metrics
  {project-id: uint, metric-type: (string-ascii 64)}
  {value: uint, target: uint, timestamp: uint})

(define-map esg-certifications
  {project-id: uint, certification-type: (string-ascii 64)}
  {issuer: principal, issue-date: uint, expiry-date: uint, valid: bool})

(define-data-var next-project-id uint u0)

(define-read-only (get-project (project-id uint))
  (ok (map-get? mining-projects project-id)))

(define-public (register-project (location (string-ascii 256)))
  (let ((project-id (var-get next-project-id)))
    (map-set mining-projects project-id
      {operator: tx-sender, location: location, environmental-score: u0,
       social-score: u0, governance-score: u0, overall-esg-rating: "N/A",
       last-assessment: stacks-block-height, compliant: false})
    (var-set next-project-id (+ project-id u1))
    (ok project-id)))

(define-public (update-esg-scores (project-id uint) (env uint) (social uint) (gov uint) (rating (string-ascii 8)))
  (let ((project (unwrap! (map-get? mining-projects project-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set mining-projects project-id
      {operator: (get operator project), location: (get location project),
       environmental-score: env, social-score: social, governance-score: gov,
       overall-esg-rating: rating, last-assessment: stacks-block-height,
       compliant: (>= (+ env (+ social gov)) u180)}))))

(define-public (log-metric (project-id uint) (metric (string-ascii 64)) (value uint) (target uint))
  (begin
    (asserts! (is-some (map-get? mining-projects project-id)) err-not-found)
    (ok (map-set esg-metrics {project-id: project-id, metric-type: metric}
      {value: value, target: target, timestamp: stacks-block-height}))))

(define-public (issue-certification (project-id uint) (cert-type (string-ascii 64)) (expiry uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set esg-certifications {project-id: project-id, certification-type: cert-type}
      {issuer: tx-sender, issue-date: stacks-block-height, expiry-date: expiry, valid: true}))))
