(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-project-inactive (err u105))
(define-constant err-funding-closed (err u106))

(define-data-var project-nonce uint u0)
(define-data-var contribution-nonce uint u0)

(define-map research-projects
  uint
  {
    researcher: principal,
    project-name: (string-ascii 50),
    description-hash: (buff 32),
    funding-goal: uint,
    funding-raised: uint,
    peer-review-score: uint,
    peer-review-count: uint,
    active: bool,
    funded: bool,
    results-published: bool
  }
)

(define-map funding-contributions
  uint
  {
    project-id: uint,
    contributor: principal,
    amount: uint,
    contribution-block: uint,
    reward-claimed: bool
  }
)

(define-map peer-reviews
  {project-id: uint, reviewer: principal}
  {
    quality-score: uint,
    methodology-score: uint,
    impact-score: uint,
    review-hash: (buff 32),
    verified-reviewer: bool
  }
)

(define-map research-results
  uint
  {
    result-hash: (buff 32),
    publication-block: uint,
    open-access: bool,
    citation-count: uint
  }
)

(define-map researcher-projects principal (list 50 uint))
(define-map project-contributions uint (list 100 uint))

(define-public (create-research-project (project-name (string-ascii 50)) (description-hash (buff 32)) (funding-goal uint))
  (let
    (
      (project-id (+ (var-get project-nonce) u1))
    )
    (asserts! (> funding-goal u0) err-invalid-amount)
    (map-set research-projects project-id
      {
        researcher: tx-sender,
        project-name: project-name,
        description-hash: description-hash,
        funding-goal: funding-goal,
        funding-raised: u0,
        peer-review-score: u0,
        peer-review-count: u0,
        active: true,
        funded: false,
        results-published: false
      }
    )
    (map-set researcher-projects tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? researcher-projects tx-sender)) project-id) u50)))
    (var-set project-nonce project-id)
    (ok project-id)
  )
)

(define-public (contribute-funding (project-id uint) (amount uint))
  (let
    (
      (project (unwrap! (map-get? research-projects project-id) err-not-found))
      (contribution-id (+ (var-get contribution-nonce) u1))
    )
    (asserts! (get active project) err-project-inactive)
    (asserts! (not (get funded project)) err-funding-closed)
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set funding-contributions contribution-id
      {
        project-id: project-id,
        contributor: tx-sender,
        amount: amount,
        contribution-block: stacks-block-height,
        reward-claimed: false
      }
    )
    (let
      (
        (new-funding (+ (get funding-raised project) amount))
      )
      (map-set research-projects project-id (merge project {
        funding-raised: new-funding,
        funded: (>= new-funding (get funding-goal project))
      }))
    )
    (map-set project-contributions project-id
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? project-contributions project-id)) contribution-id) u100)))
    (var-set contribution-nonce contribution-id)
    (ok contribution-id)
  )
)

(define-public (submit-peer-review (project-id uint) (quality-score uint) (methodology-score uint) (impact-score uint) (review-hash (buff 32)))
  (let
    (
      (project (unwrap! (map-get? research-projects project-id) err-not-found))
    )
    (asserts! (<= quality-score u100) err-invalid-amount)
    (asserts! (<= methodology-score u100) err-invalid-amount)
    (asserts! (<= impact-score u100) err-invalid-amount)
    (asserts! (is-none (map-get? peer-reviews {project-id: project-id, reviewer: tx-sender})) err-already-exists)
    (map-set peer-reviews {project-id: project-id, reviewer: tx-sender}
      {
        quality-score: quality-score,
        methodology-score: methodology-score,
        impact-score: impact-score,
        review-hash: review-hash,
        verified-reviewer: false
      }
    )
    (let
      (
        (avg-score (/ (+ quality-score methodology-score impact-score) u3))
        (new-count (+ (get peer-review-count project) u1))
        (current-total (* (get peer-review-score project) (get peer-review-count project)))
        (new-avg (/ (+ current-total avg-score) new-count))
      )
      (map-set research-projects project-id (merge project {
        peer-review-score: new-avg,
        peer-review-count: new-count
      }))
    )
    (ok true)
  )
)

(define-public (publish-results (project-id uint) (result-hash (buff 32)) (open-access bool))
  (let
    (
      (project (unwrap! (map-get? research-projects project-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get researcher project)) err-unauthorized)
    (asserts! (get funded project) err-funding-closed)
    (map-set research-results project-id
      {
        result-hash: result-hash,
        publication-block: stacks-block-height,
        open-access: open-access,
        citation-count: u0
      }
    )
    (map-set research-projects project-id (merge project {results-published: true}))
    (ok true)
  )
)

(define-public (release-funds (project-id uint))
  (let
    (
      (project (unwrap! (map-get? research-projects project-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get researcher project)) err-unauthorized)
    (asserts! (get funded project) err-funding-closed)
    (try! (as-contract (stx-transfer? (get funding-raised project) tx-sender (get researcher project))))
    (ok true)
  )
)

(define-read-only (get-research-project (project-id uint))
  (ok (map-get? research-projects project-id))
)

(define-read-only (get-funding-contribution (contribution-id uint))
  (ok (map-get? funding-contributions contribution-id))
)

(define-read-only (get-peer-review (project-id uint) (reviewer principal))
  (ok (map-get? peer-reviews {project-id: project-id, reviewer: reviewer}))
)

(define-read-only (get-research-results (project-id uint))
  (ok (map-get? research-results project-id))
)

(define-read-only (get-researcher-projects (researcher principal))
  (ok (map-get? researcher-projects researcher))
)

(define-read-only (get-project-contributions (project-id uint))
  (ok (map-get? project-contributions project-id))
)
