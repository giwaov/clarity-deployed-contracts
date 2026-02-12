;; fiducia.clar
;;
;; ============================================
;; title: fiducia
;; version: 1
;; summary: A weighted trust and reputation smart contract.
;; description: Allows users to give trust, build reputation, and create a web of credibility.
;; ============================================

;; constants
;;
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-SELF-TRUST (err u101))
(define-constant ERR-INVALID-LEVEL (err u102))
(define-constant ERR-ALREADY-TRUSTED (err u103))
(define-constant ERR-NOT-FOUND (err u104))
(define-constant ERR-LIST-FULL (err u105))

(define-constant BASE-REPUTATION u10)

;; ============================================
;; data maps
;;

;; Map to store reputation details for each user
(define-map user-reputation
  principal
  {
    reputation-score: uint,
    trust-received-count: uint,
    trust-given-count: uint,
    trust-given: (list 50 principal),    ;; Who this user trusts
    trust-received: (list 50 principal)  ;; Who trusts this user
  }
)

;; Map to store trust relationships between users
(define-map trust-relationships
  { trustor: principal, trustee: principal }
  {
    level: uint,
    note: (string-utf8 500),
    weight: uint ;; The weight contributed to the reputation score
  }
)

;; ============================================
;; private functions
;;

;; Helper to get existing reputation score or default to BASE-REPUTATION
(define-private (get-user-rep-internal (user principal))
  (default-to 
    BASE-REPUTATION 
    (get reputation-score (map-get? user-reputation user))
  )
)

;; Helper to get full user data or default structure
(define-private (get-user-data-internal (user principal))
  (default-to
    {
      reputation-score: BASE-REPUTATION,
      trust-received-count: u0,
      trust-given-count: u0,
      trust-given: (list),
      trust-received: (list)
    }
    (map-get? user-reputation user)
  )
)

;; ============================================
;; public functions
;;

;; Give trust to someone
(define-public (give-trust (recipient principal) (level uint) (note (string-utf8 500)))
  (let
    (
      (trustor tx-sender)
      (trustor-rep (get-user-rep-internal trustor))
      (recipient-data (get-user-data-internal recipient))
      (trustor-data (get-user-data-internal trustor))
      (weight (* trustor-rep level))
      
      ;; Prepare lists first to ensure we don't hit limits mid-execution
      (recipient-trust-list (get trust-received recipient-data))
      (trustor-given-list (get trust-given trustor-data))
      
      ;; Append new principals. Check for max length.
      (new-recipient-list (unwrap! (as-max-len? (append recipient-trust-list trustor) u50) ERR-LIST-FULL))
      (new-trustor-list (unwrap! (as-max-len? (append trustor-given-list recipient) u50) ERR-LIST-FULL))
    )
    ;; checks
    (asserts! (not (is-eq trustor recipient)) ERR-SELF-TRUST)
    (asserts! (and (>= level u1) (<= level u5)) ERR-INVALID-LEVEL)
    (asserts! (is-none (map-get? trust-relationships {trustor: trustor, trustee: recipient})) ERR-ALREADY-TRUSTED)

    ;; Update Trust Relationship
    (map-set trust-relationships
      {trustor: trustor, trustee: recipient}
      {
        level: level,
        note: note,
        weight: weight
      }
    )

    ;; Update Recipient Reputation
    (map-set user-reputation recipient
      (merge recipient-data {
        reputation-score: (+ (get reputation-score recipient-data) weight),
        trust-received-count: (+ (get trust-received-count recipient-data) u1),
        trust-received: new-recipient-list
      })
    )

    ;; Update Trustor Data
    (map-set user-reputation trustor
      (merge trustor-data {
        trust-given-count: (+ (get trust-given-count trustor-data) u1),
        trust-given: new-trustor-list
      })
    )

    (print {
      event: "give-trust",
      trustor: trustor,
      recipient: recipient,
      level: level,
      weight: weight
    })
    (ok true)
  )
)

;; Update existing trust
(define-public (update-trust (recipient principal) (new-level uint) (new-note (string-utf8 500)))
  (let
    (
      (trustor tx-sender)
      (trustor-rep (get-user-rep-internal trustor))
      (current-relationship (unwrap! (map-get? trust-relationships {trustor: trustor, trustee: recipient}) ERR-NOT-FOUND))
      (recipient-data (get-user-data-internal recipient))
      (old-weight (get weight current-relationship))
      (new-weight (* trustor-rep new-level))
    )
    (asserts! (and (>= new-level u1) (<= new-level u5)) ERR-INVALID-LEVEL)

    ;; Update Relationship
    (map-set trust-relationships
      {trustor: trustor, trustee: recipient}
      {
        level: new-level,
        note: new-note,
        weight: new-weight
      }
    )

    ;; Update Recipient Score (remove old weight, add new weight)
    (map-set user-reputation recipient
      (merge recipient-data {
        reputation-score: (+ (- (get reputation-score recipient-data) old-weight) new-weight)
      })
    )

    (print {
      event: "update-trust",
      trustor: trustor,
      recipient: recipient,
      old-level: (get level current-relationship),
      new-level: new-level
    })
    (ok true)
  )
)

;; Revoke trust
(define-public (revoke-trust (recipient principal))
  (let
    (
      (trustor tx-sender)
      (current-relationship (unwrap! (map-get? trust-relationships {trustor: trustor, trustee: recipient}) ERR-NOT-FOUND))
      (recipient-data (get-user-data-internal recipient))
      (old-weight (get weight current-relationship))
    )
    
    ;; Remove Relationship
    (map-delete trust-relationships {trustor: trustor, trustee: recipient})

    ;; Update Recipient Score
    (map-set user-reputation recipient
      (merge recipient-data {
        reputation-score: (- (get reputation-score recipient-data) old-weight),
        trust-received-count: (- (get trust-received-count recipient-data) u1)
      })
    )

    ;; Note: We leave history in the lists for now as 'past trust'
    
    (print {
      event: "revoke-trust",
      trustor: trustor,
      recipient: recipient
    })
    (ok true)
  )
)


;; ============================================
;; read only functions
;;

(define-read-only (get-reputation-score (user principal))
  (ok (get-user-rep-internal user))
)

(define-read-only (get-trust-given (user principal))
  (ok (get trust-given (get-user-data-internal user)))
)

(define-read-only (get-trust-received (user principal))
  (ok (get trust-received (get-user-data-internal user)))
)

(define-read-only (get-trust-between (trustor principal) (trustee principal))
  (ok (map-get? trust-relationships {trustor: trustor, trustee: trustee}))
)
