(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-OTP-NOT-FOUND (err u101))
(define-constant ERR-OTP-EXPIRED (err u102))
(define-constant ERR-OTP-INVALID (err u103))
(define-constant ERR-ALREADY-VERIFIED (err u104))

(define-constant OTP-VALIDITY-PERIOD u10)

(define-map otps
  { phone-number: (string-ascii 20), request-id: uint }
  {
    otp-hash: (buff 32),
    created-at: uint,
    expires-at: uint,
    verified: bool,
    requester: principal
  }
)

(define-data-var request-nonce uint u0)

(define-public (generate-otp-request (phone-number (string-ascii 20)) (otp-hash (buff 32)))
  (let (
    (request-id (var-get request-nonce))
    (expiry (+ stacks-block-height OTP-VALIDITY-PERIOD))
  )
    (map-set otps
      { phone-number: phone-number, request-id: request-id }
      {
        otp-hash: otp-hash,
        created-at: stacks-block-height,
        expires-at: expiry,
        verified: false,
        requester: tx-sender
      }
    )
    (var-set request-nonce (+ request-id u1))
    (ok request-id)
  )
)

(define-public (verify-otp (phone-number (string-ascii 20)) (request-id uint) (otp-hash (buff 32)))
  (let (
    (otp-record (unwrap! (map-get? otps { phone-number: phone-number, request-id: request-id }) ERR-OTP-NOT-FOUND))
  )
    (asserts! (not (get verified otp-record)) ERR-ALREADY-VERIFIED)
    (asserts! (<= stacks-block-height (get expires-at otp-record)) ERR-OTP-EXPIRED)
    (asserts! (is-eq otp-hash (get otp-hash otp-record)) ERR-OTP-INVALID)
    (map-set otps
      { phone-number: phone-number, request-id: request-id }
      (merge otp-record { verified: true })
    )
    (ok true)
  )
)

(define-read-only (get-otp-status (phone-number (string-ascii 20)) (request-id uint))
  (map-get? otps { phone-number: phone-number, request-id: request-id })
)

(define-read-only (is-verified (phone-number (string-ascii 20)) (request-id uint))
  (match (map-get? otps { phone-number: phone-number, request-id: request-id })
    otp-record (ok (get verified otp-record))
    (err ERR-OTP-NOT-FOUND)
  )
)

(define-public (revoke-otp (phone-number (string-ascii 20)) (request-id uint))
  (let (
    (otp-record (unwrap! (map-get? otps { phone-number: phone-number, request-id: request-id }) ERR-OTP-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get requester otp-record)) ERR-NOT-AUTHORIZED)
    (ok (map-delete otps { phone-number: phone-number, request-id: request-id }))
  )
)

(define-read-only (get-request-nonce)
  (ok (var-get request-nonce))
)
