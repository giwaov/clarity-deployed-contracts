;; signwall.clar
;; 
;; ============================================
;; title: SignWall
;; summary: An on-chain guestbook with event logging.
;; ============================================

;; --- Constants & Error Codes ---
(define-constant ERR_ALREADY_SIGNED (err u100))
(define-constant ERR_NOT_SIGNED_YET (err u101))
(define-constant ERR_INVALID_INDEX (err u102))
(define-constant ERR_UNDERFLOW (err u103))
(define-constant ERR_EMPTY_MESSAGE (err u104))

;; --- Data Structures ---
;; Use a map to store signatures indexed by principal
(define-map signatures principal {
  name: (string-ascii 50),
  message: (string-utf8 500),
  block-height: uint,
  signature-id: uint
})

;; Track order of signatures
(define-map signature-order uint principal)

(define-data-var signature-count uint u0)
(define-data-var general-counter uint u0)

;; --- Public Functions ---

;; 1. Sign the Wall
(define-public (sign (name (string-ascii 50)) (message (string-utf8 500)))
  (let
    (
      (current-count (var-get signature-count))
      (new-signature {
        name: name,
        message: message,
        block-height: block-height,
        signature-id: current-count
      })
    )
    (asserts! (is-none (map-get? signatures tx-sender)) ERR_ALREADY_SIGNED)
    (asserts! (> (len name) u0) ERR_EMPTY_MESSAGE)

    (begin
      (map-set signatures tx-sender new-signature)
      (map-set signature-order current-count tx-sender)
      (var-set signature-count (+ current-count u1))
      
      ;; EVENT: New Signature Added
      (print {
        event: "new-signature",
        signer: tx-sender,
        name: name,
        message: message,
        signature-id: current-count,
        total-signatures: (+ current-count u1),
        height: block-height
      })
      
      (ok true)
    )
  )
)

;; 2. Update existing signature
(define-public (update-signature (name (string-ascii 50)) (message (string-utf8 500)))
  (let
    (
      (existing (unwrap! (map-get? signatures tx-sender) ERR_NOT_SIGNED_YET))
      (updated-signature {
        name: name,
        message: message,
        block-height: block-height,
        signature-id: (get signature-id existing)
      })
    )
    (begin
      (map-set signatures tx-sender updated-signature)
      
      ;; EVENT: Signature Updated
      (print {
        event: "updated-signature",
        signer: tx-sender,
        new-name: name,
        new-message: message,
        updated-at: block-height
      })

      (ok true)
    )
  )
)

;; --- General Counter Logic with Events ---

(define-public (increment)
  (let ((new-val (+ (var-get general-counter) u1)))
    (begin
      (var-set general-counter new-val)
      
      ;; EVENT: Counter Incremented
      (print {
        event: "counter-increment",
        caller: tx-sender,
        new-value: new-val
      })
      
      (ok new-val)
    )
  )
)

(define-public (decrement)
  (let ((current-val (var-get general-counter)))
    (begin
      (asserts! (> current-val u0) ERR_UNDERFLOW)
      (let ((new-val (- current-val u1)))
        (var-set general-counter new-val)
        
        ;; EVENT: Counter Decremented
        (print {
          event: "counter-decrement",
          caller: tx-sender,
          new-value: new-val
        })
        
        (ok new-val)
      )
    )
  )
)

;; --- Read Only Functions ---

(define-read-only (get-signature (user principal))
  (map-get? signatures user)
)

(define-read-only (get-signature-by-index (index uint))
  (match (map-get? signature-order index)
    signer (map-get? signatures signer)
    none
  )
)

(define-read-only (get-signature-count) 
  (var-get signature-count)
)

(define-read-only (has-signed (user principal)) 
  (is-some (map-get? signatures user))
)

(define-read-only (get-general-counter) 
  (var-get general-counter)
)