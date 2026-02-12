(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))
(define-constant err-already-claimed (err u122))

(define-data-var incentive-nonce uint u0)

(define-map incentive-programs
  uint
  {
    sponsor: principal,
    total-budget: uint,
    remaining-budget: uint,
    reward-per-kw: uint,
    min-installation-kw: uint,
    max-reward-per-install: uint,
    location-requirement: (string-ascii 50),
    active: bool,
    created-block: uint
  }
)

(define-map solar-installations
  {program-id: uint, install-id: uint}
  {
    installer: principal,
    capacity-kw: uint,
    location-hash: (buff 32),
    installation-cost: uint,
    reward-amount: uint,
    verified: bool,
    claimed: bool,
    install-block: uint
  }
)

(define-map verifications
  {program-id: uint, install-id: uint}
  {
    verifier: principal,
    verified-capacity: uint,
    verification-block: uint,
    notes: (string-ascii 100)
  }
)

(define-map install-counter uint uint)
(define-map sponsor-programs principal (list 20 uint))

(define-public (create-incentive-program (budget uint) (reward-per-kw uint) (min-kw uint) 
                                          (max-reward uint) (location (string-ascii 50)))
  (let
    (
      (program-id (+ (var-get incentive-nonce) u1))
    )
    (asserts! (> budget u0) err-invalid-amount)
    (map-set incentive-programs program-id {
      sponsor: tx-sender,
      total-budget: budget,
      remaining-budget: budget,
      reward-per-kw: reward-per-kw,
      min-installation-kw: min-kw,
      max-reward-per-install: max-reward,
      location-requirement: location,
      active: true,
      created-block: stacks-block-height
    })
    (map-set install-counter program-id u0)
    (map-set sponsor-programs tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? sponsor-programs tx-sender)) program-id) u20)))
    (var-set incentive-nonce program-id)
    (ok program-id)
  )
)

(define-public (register-installation (program-id uint) (capacity uint) (location (buff 32)) (cost uint))
  (let
    (
      (program (unwrap! (map-get? incentive-programs program-id) err-not-found))
      (install-id (+ (default-to u0 (map-get? install-counter program-id)) u1))
      (base-reward (/ (* capacity (get reward-per-kw program)) u1))
      (max-reward (get max-reward-per-install program))
      (calculated-reward (if (<= base-reward max-reward) base-reward max-reward))
    )
    (asserts! (get active program) err-not-found)
    (asserts! (>= capacity (get min-installation-kw program)) err-invalid-amount)
    (asserts! (<= calculated-reward (get remaining-budget program)) err-invalid-amount)
    (map-set solar-installations {program-id: program-id, install-id: install-id} {
      installer: tx-sender,
      capacity-kw: capacity,
      location-hash: location,
      installation-cost: cost,
      reward-amount: calculated-reward,
      verified: false,
      claimed: false,
      install-block: stacks-block-height
    })
    (map-set install-counter program-id install-id)
    (ok install-id)
  )
)

(define-public (verify-installation (program-id uint) (install-id uint) (verified-capacity uint) 
                                     (notes (string-ascii 100)))
  (let
    (
      (program (unwrap! (map-get? incentive-programs program-id) err-not-found))
      (installation (unwrap! (map-get? solar-installations {program-id: program-id, install-id: install-id}) err-not-found))
    )
    (asserts! (is-eq tx-sender (get sponsor program)) err-unauthorized)
    (map-set verifications {program-id: program-id, install-id: install-id} {
      verifier: tx-sender,
      verified-capacity: verified-capacity,
      verification-block: stacks-block-height,
      notes: notes
    })
    (map-set solar-installations {program-id: program-id, install-id: install-id}
      (merge installation {verified: true}))
    (ok true)
  )
)

(define-public (claim-reward (program-id uint) (install-id uint))
  (let
    (
      (program (unwrap! (map-get? incentive-programs program-id) err-not-found))
      (installation (unwrap! (map-get? solar-installations {program-id: program-id, install-id: install-id}) err-not-found))
      (reward (get reward-amount installation))
    )
    (asserts! (is-eq tx-sender (get installer installation)) err-unauthorized)
    (asserts! (get verified installation) err-not-found)
    (asserts! (not (get claimed installation)) err-already-claimed)
    (try! (stx-transfer? reward (get sponsor program) tx-sender))
    (map-set solar-installations {program-id: program-id, install-id: install-id}
      (merge installation {claimed: true}))
    (map-set incentive-programs program-id
      (merge program {remaining-budget: (- (get remaining-budget program) reward)}))
    (ok reward)
  )
)

(define-read-only (get-program (program-id uint))
  (ok (map-get? incentive-programs program-id))
)

(define-read-only (get-installation (program-id uint) (install-id uint))
  (ok (map-get? solar-installations {program-id: program-id, install-id: install-id}))
)

(define-read-only (get-verification (program-id uint) (install-id uint))
  (ok (map-get? verifications {program-id: program-id, install-id: install-id}))
)

(define-read-only (get-sponsor-programs (sponsor principal))
  (ok (map-get? sponsor-programs sponsor))
)

(define-read-only (calculate-potential-reward (program-id uint) (capacity uint))
  (let
    (
      (program (unwrap-panic (map-get? incentive-programs program-id)))
      (base-reward (/ (* capacity (get reward-per-kw program)) u1))
      (max-reward (get max-reward-per-install program))
      (calculated (if (<= base-reward max-reward) base-reward max-reward))
    )
    (ok calculated)
  )
)
