(define-constant ERR-UNAUTHORIZED u100)
(define-constant ERR-INSUFFICIENT u101)
(define-constant ERR-ALREADY-INITIALIZED u102)
(define-constant ERR-NOT-INITIALIZED u103)

(define-trait sip010-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
  )
)

(define-data-var manager principal tx-sender)
(define-data-var initialized bool false)
(define-data-var managed uint u0)

(define-read-only (is-manager)
  (or
    (is-eq tx-sender (var-get manager))
    (is-eq contract-caller (var-get manager))
  )
)

(define-read-only (get-managed)
  (var-get managed)
)

(define-public (set-manager (new-manager principal))
  (begin
    (asserts! (is-manager) (err ERR-UNAUTHORIZED))
    (asserts! (not (var-get initialized)) (err ERR-ALREADY-INITIALIZED))
    (var-set manager new-manager)
    (var-set initialized true)
    (ok true)
  )
)

(define-public (deposit (amount uint))
  (begin
    (asserts! (var-get initialized) (err ERR-NOT-INITIALIZED))
    (asserts! (is-manager) (err ERR-UNAUTHORIZED))
    (var-set managed (+ (var-get managed) amount))
    (ok true)
  )
)

(define-public (withdraw (amount uint))
  (let ((recipient tx-sender))
    (begin
      (asserts! (var-get initialized) (err ERR-NOT-INITIALIZED))
      (asserts! (is-manager) (err ERR-UNAUTHORIZED))
      (asserts! (>= (var-get managed) amount) (err ERR-INSUFFICIENT))
      (try! (as-contract (stx-transfer? amount tx-sender recipient)))
      (var-set managed (- (var-get managed) amount))
      (ok true)
    )
  )
)

(define-public (withdraw-sip010 (token <sip010-trait>) (amount uint))
  (let ((recipient tx-sender))
    (begin
      (asserts! (var-get initialized) (err ERR-NOT-INITIALIZED))
      (asserts! (is-manager) (err ERR-UNAUTHORIZED))
      (asserts! (>= (var-get managed) amount) (err ERR-INSUFFICIENT))
      (try! (as-contract (contract-call? token transfer amount tx-sender recipient none)))
      (var-set managed (- (var-get managed) amount))
      (ok true)
    )
  )
)

(define-public (harvest)
  (begin
    (asserts! (var-get initialized) (err ERR-NOT-INITIALIZED))
    (asserts! (is-manager) (err ERR-UNAUTHORIZED))
    (ok u0)
  )
)
