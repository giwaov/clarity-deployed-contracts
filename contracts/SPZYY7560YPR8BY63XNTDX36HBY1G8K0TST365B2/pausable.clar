;; pausable.clar
;; Advanced pausing system with levels and overrides

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-PAUSER (err u101))
(define-constant ERR-CONTRACT-PAUSED (err u102))
(define-constant ERR-FUNCTION-PAUSED (err u103))
(define-constant ERR-USER-PAUSED (err u104))

;; Data Variables
(define-data-var globally-paused bool false)

;; Maps
(define-map pausers principal bool)
(define-map function-paused (string-ascii 64) bool)
(define-map user-paused principal bool)

;; Authorization
(define-read-only (is-pauser (addr principal))
  (or (is-eq addr CONTRACT-OWNER) (default-to false (map-get? pausers addr)))
)

;; Public Functions
(define-public (add-pauser (new-pauser principal))
  (begin
    (asserts! (not (is-eq new-pauser tx-sender)) (err u107))
    (ok (map-set pausers new-pauser true))
  )
)

(define-public (pause)
  (begin
    (var-set globally-paused true)
    (ok true)
  )
)

(define-public (unpause)
  (begin
    (var-set globally-paused false)
    (ok true)
  )
)

(define-public (pause-function (name (string-ascii 64)))
  (begin
    (asserts! (> (len name) u0) (err u105))
    (ok (map-set function-paused name true))
  )
)

(define-public (pause-user (user principal))
  (begin
    (asserts! (not (is-eq user CONTRACT-OWNER)) (err u106))
    (ok (map-set user-paused user true))
  )
)

;; Modifiers (Checks)
(define-read-only (check-is-not-paused (func-name (string-ascii 64)))
  (begin
    (asserts! (not (var-get globally-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (not (default-to false (map-get? function-paused func-name))) ERR-FUNCTION-PAUSED)
    (asserts! (not (default-to false (map-get? user-paused tx-sender))) ERR-USER-PAUSED)
    (ok true)
  )
)
