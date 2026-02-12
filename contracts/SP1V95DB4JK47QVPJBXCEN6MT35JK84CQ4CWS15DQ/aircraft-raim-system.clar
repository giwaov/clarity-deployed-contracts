(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map raim-monitors
  (string-ascii 32)
  {
    aircraft-id: (string-ascii 32),
    satellites-tracked: uint,
    integrity-status: (string-ascii 32),
    horizontal-protection-level: uint,
    vertical-protection-level: uint,
    fault-detected: bool,
    last-check: uint
  })

(define-map satellite-health-raim
  {monitor-id: (string-ascii 32), satellite-id: (string-ascii 32)}
  {signal-quality: uint, excluded: bool})

(define-read-only (get-raim-status (monitor-id (string-ascii 32)))
  (ok (map-get? raim-monitors monitor-id)))

(define-public (initialize-raim (monitor-id (string-ascii 32)) (aircraft (string-ascii 32)))
  (begin
    (ok (map-set raim-monitors monitor-id
      {aircraft-id: aircraft, satellites-tracked: u0, integrity-status: "checking",
       horizontal-protection-level: u0, vertical-protection-level: u0,
       fault-detected: false, last-check: stacks-block-height}))))

(define-public (update-raim (monitor-id (string-ascii 32)) (sats uint) (status (string-ascii 32)) (hpl uint) (vpl uint) (fault bool))
  (let ((raim (unwrap! (map-get? raim-monitors monitor-id) err-not-found)))
    (ok (map-set raim-monitors monitor-id
      {aircraft-id: (get aircraft-id raim), satellites-tracked: sats, integrity-status: status,
       horizontal-protection-level: hpl, vertical-protection-level: vpl,
       fault-detected: fault, last-check: stacks-block-height}))))

(define-public (exclude-satellite (monitor-id (string-ascii 32)) (sat-id (string-ascii 32)))
  (begin
    (ok (map-set satellite-health-raim {monitor-id: monitor-id, satellite-id: sat-id}
      {signal-quality: u0, excluded: true}))))
