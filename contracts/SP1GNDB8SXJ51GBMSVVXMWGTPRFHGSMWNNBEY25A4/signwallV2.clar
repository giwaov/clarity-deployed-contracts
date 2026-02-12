;; signwall.clar
;; 
;; ============================================
;; title: SignWall
;; summary: An on-chain guestbook with event logging.
;; ============================================

;; --- Constants & Error Codes ---
(define-constant ERR_INVALID_INDEX (err u100))
(define-constant ERR_EMPTY_MESSAGE (err u101))
(define-constant ERR_UNDERFLOW (err u102))

;; --- Data Structures ---
;; Use a map to store signatures indexed by ID (uint)
(define-map signatures uint {
  signer: principal,
  name: (string-ascii 50),
  message: (string-utf8 500),
  block-height: uint
})

(define-data-var signature-count uint u0)
(define-data-var general-counter uint u0)

;; --- Public Functions ---

;; 1. Sign the Wall
;; Anyone can sign as many times as they want
(define-public (sign (name (string-ascii 50)) (message (string-utf8 500)))
  (let
    (
      (current-count (var-get signature-count))
      (new-signature {
        signer: tx-sender,
        name: name,
        message: message,
        block-height: block-height
      })
    )
    (asserts! (> (len name) u0) ERR_EMPTY_MESSAGE)

    (begin
      (map-set signatures current-count new-signature)
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

(define-read-only (get-signature-by-index (index uint))
  (map-get? signatures index)
)

(define-read-only (get-signature-count) 
  (var-get signature-count)
)

(define-read-only (get-general-counter) 
  (var-get general-counter)
)