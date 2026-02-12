;; Simple Voting
(define-map proposals uint {title: (string-ascii 100), yes-votes: uint, no-votes: uint, active: bool})
(define-map votes {proposal-id: uint, voter: principal} bool)
(define-data-var proposal-count uint u0)

(define-public (create-proposal (title (string-ascii 100)))
  (let ((id (+ (var-get proposal-count) u1)))
    (begin
      (map-set proposals id {title: title, yes-votes: u0, no-votes: u0, active: true})
      (var-set proposal-count id)
      (ok id))))

(define-public (vote-yes (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) (err u1))))
    (asserts! (get active proposal) (err u2))
    (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: tx-sender})) (err u3))
    (map-set votes {proposal-id: proposal-id, voter: tx-sender} true)
    (map-set proposals proposal-id (merge proposal {yes-votes: (+ (get yes-votes proposal) u1)}))
    (ok true)))

(define-public (vote-no (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) (err u1))))
    (asserts! (get active proposal) (err u2))
    (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: tx-sender})) (err u3))
    (map-set votes {proposal-id: proposal-id, voter: tx-sender} true)
    (map-set proposals proposal-id (merge proposal {no-votes: (+ (get no-votes proposal) u1)}))
    (ok true)))

(define-public (close-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) (err u1))))
    (map-set proposals proposal-id (merge proposal {active: false}))
    (ok true)))

(define-read-only (get-proposal (proposal-id uint))
  (ok (map-get? proposals proposal-id)))

(define-read-only (get-proposal-count)
  (ok (var-get proposal-count)))
