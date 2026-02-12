(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-site-inactive (err u105))
(define-constant err-enrollment-closed (err u106))

(define-data-var trial-nonce uint u0)
(define-data-var site-nonce uint u0)
(define-data-var participant-nonce uint u0)

(define-map trials
  uint
  {
    sponsor: principal,
    trial-name: (string-ascii 50),
    protocol-hash: (buff 32),
    target-enrollment: uint,
    current-enrollment: uint,
    incentive-per-participant: uint,
    active: bool,
    completed: bool
  }
)

(define-map trial-sites
  uint
  {
    trial-id: uint,
    site-operator: principal,
    location-hash: (buff 32),
    max-participants: uint,
    current-participants: uint,
    active: bool,
    total-earned: uint
  }
)

(define-map participants
  uint
  {
    site-id: uint,
    participant-hash: (buff 32),
    enrollment-block: uint,
    completion-status: (string-ascii 20),
    incentive-paid: bool,
    data-submitted: bool
  }
)

(define-map sponsor-trials principal (list 50 uint))
(define-map site-participants uint (list 200 uint))

(define-public (create-trial (trial-name (string-ascii 50)) (protocol-hash (buff 32)) (target-enrollment uint) (incentive-per-participant uint))
  (let
    (
      (trial-id (+ (var-get trial-nonce) u1))
    )
    (asserts! (> target-enrollment u0) err-invalid-amount)
    (asserts! (> incentive-per-participant u0) err-invalid-amount)
    (map-set trials trial-id
      {
        sponsor: tx-sender,
        trial-name: trial-name,
        protocol-hash: protocol-hash,
        target-enrollment: target-enrollment,
        current-enrollment: u0,
        incentive-per-participant: incentive-per-participant,
        active: true,
        completed: false
      }
    )
    (map-set sponsor-trials tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? sponsor-trials tx-sender)) trial-id) u50)))
    (var-set trial-nonce trial-id)
    (ok trial-id)
  )
)

(define-public (register-trial-site (trial-id uint) (location-hash (buff 32)) (max-participants uint))
  (let
    (
      (trial (unwrap! (map-get? trials trial-id) err-not-found))
      (site-id (+ (var-get site-nonce) u1))
    )
    (asserts! (get active trial) err-not-found)
    (asserts! (> max-participants u0) err-invalid-amount)
    (map-set trial-sites site-id
      {
        trial-id: trial-id,
        site-operator: tx-sender,
        location-hash: location-hash,
        max-participants: max-participants,
        current-participants: u0,
        active: true,
        total-earned: u0
      }
    )
    (var-set site-nonce site-id)
    (ok site-id)
  )
)

(define-public (enroll-participant (site-id uint) (participant-hash (buff 32)))
  (let
    (
      (site (unwrap! (map-get? trial-sites site-id) err-not-found))
      (trial (unwrap! (map-get? trials (get trial-id site)) err-not-found))
      (participant-id (+ (var-get participant-nonce) u1))
    )
    (asserts! (is-eq tx-sender (get site-operator site)) err-unauthorized)
    (asserts! (get active site) err-site-inactive)
    (asserts! (get active trial) err-not-found)
    (asserts! (< (get current-participants site) (get max-participants site)) err-enrollment-closed)
    (asserts! (< (get current-enrollment trial) (get target-enrollment trial)) err-enrollment-closed)
    (map-set participants participant-id
      {
        site-id: site-id,
        participant-hash: participant-hash,
        enrollment-block: stacks-block-height,
        completion-status: "enrolled",
        incentive-paid: false,
        data-submitted: false
      }
    )
    (map-set trial-sites site-id (merge site {
      current-participants: (+ (get current-participants site) u1)
    }))
    (map-set trials (get trial-id site) (merge trial {
      current-enrollment: (+ (get current-enrollment trial) u1)
    }))
    (map-set site-participants site-id
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? site-participants site-id)) participant-id) u200)))
    (var-set participant-nonce participant-id)
    (ok participant-id)
  )
)

(define-public (submit-participant-data (participant-id uint))
  (let
    (
      (participant (unwrap! (map-get? participants participant-id) err-not-found))
      (site (unwrap! (map-get? trial-sites (get site-id participant)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get site-operator site)) err-unauthorized)
    (map-set participants participant-id (merge participant {
      data-submitted: true,
      completion-status: "completed"
    }))
    (ok true)
  )
)

(define-public (pay-participant-incentive (participant-id uint))
  (let
    (
      (participant (unwrap! (map-get? participants participant-id) err-not-found))
      (site (unwrap! (map-get? trial-sites (get site-id participant)) err-not-found))
      (trial (unwrap! (map-get? trials (get trial-id site)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get sponsor trial)) err-unauthorized)
    (asserts! (get data-submitted participant) err-not-found)
    (asserts! (not (get incentive-paid participant)) err-already-exists)
    (try! (stx-transfer? (get incentive-per-participant trial) tx-sender (get site-operator site)))
    (map-set participants participant-id (merge participant {incentive-paid: true}))
    (map-set trial-sites (get site-id participant) (merge site {
      total-earned: (+ (get total-earned site) (get incentive-per-participant trial))
    }))
    (ok true)
  )
)

(define-public (complete-trial (trial-id uint))
  (let
    (
      (trial (unwrap! (map-get? trials trial-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get sponsor trial)) err-unauthorized)
    (map-set trials trial-id (merge trial {
      completed: true,
      active: false
    }))
    (ok true)
  )
)

(define-read-only (get-trial (trial-id uint))
  (ok (map-get? trials trial-id))
)

(define-read-only (get-trial-site (site-id uint))
  (ok (map-get? trial-sites site-id))
)

(define-read-only (get-participant (participant-id uint))
  (ok (map-get? participants participant-id))
)

(define-read-only (get-sponsor-trials (sponsor principal))
  (ok (map-get? sponsor-trials sponsor))
)

(define-read-only (get-site-participants (site-id uint))
  (ok (map-get? site-participants site-id))
)
