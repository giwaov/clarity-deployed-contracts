---
title: "Trait opensource-idt"
draft: true
---
```
;; title: OpenSource-IDT
;; version:
;; summary:
;; description:

;; Constants
(define-constant ADMIN-ACCOUNT tx-sender)

;;
;; Errors
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NAME-UNAVAILABLE (err u101))
(define-constant ERR-NAME-NOT-FOUND (err u102))
(define-constant ERR-INVALID-NAME (err u103))
(define-constant ERR-TRANSACTION-FAILED (err u104))
(define-constant ERR-PAYMENT-REQUIRED (err u105))

;; token definitions

;; DATA Maps :::
;;;;;;;;;;;;;;;; 
;;;;;;;;;;;;;;;; 
(define-map name-registry
  { name: (string-ascii 255) }
  {
    holder: principal,
    validity: uint,
    listing-amount: uint,
  }
)

(define-map name-marketplace
  { name: (string-ascii 255) }
  {
    buyer: principal,
    purchase-amount: uint,
  }
)

;; data vars
;;
;; Variables
(define-data-var base-fee uint u10000000) ;; 0.1 STX default fee
(define-data-var min-validity-period uint u31536000) ;; 1 year in seconds
(define-data-var max-validity-period uint u157680000) ;; 5 years in seconds

;; data maps
;;
;; Helper function to get current block height as a pseudo-timestamp
(define-read-only (current-time)
  (default-to u0 (get-stacks-block-info? time stacks-block-height))
)

;; public functions
;;
;; Utility Functions
(define-read-only (is-lowercase-letter (char (string-ascii 1)))
  (or
    (is-eq char "a")
    (is-eq char "b")
    (is-eq char "c")
    (is-eq char "d")
    (is-eq char "e")
    (is-eq char "f")
    (is-eq char "g")
    (is-eq char "h")
    (is-eq char "i")
    (is-eq char "j")
    (is-eq char "k")
    (is-eq char "l")
    (is-eq char "m")
    (is-eq char "n")
    (is-eq char "o")
    (is-eq char "p")
    (is-eq char "q")
    (is-eq char "r")
    (is-eq char "s")
    (is-eq char "t")
    (is-eq char "u")
    (is-eq char "v")
    (is-eq char "w")
    (is-eq char "x")
    (is-eq char "y")
    (is-eq char "z")
  )
)

;; read only functions
;;
(define-read-only (is-number (char (string-ascii 1)))
  (or
    (is-eq char "0")
    (is-eq char "1")
    (is-eq char "2")
    (is-eq char "3")
    (is-eq char "4")
    (is-eq char "5")
    (is-eq char "6")
    (is-eq char "7")
    (is-eq char "8")
    (is-eq char "9")
  )
)

;; private functions
;;
(define-read-only (is-valid-character (char (string-ascii 1)))
  (or
    (is-lowercase-letter char)
    (is-number char)
    (is-eq char "-")
  )
)

;; Helper function to check a specific character in the name
(define-private (check-name-char
    (name (string-ascii 255))
    (index uint)
  )
  (if (>= index (len name))
    true
    (is-valid-character (unwrap-panic (element-at name index)))
  )
)

;; Check groups of characters to work around Clarity's recursion limits
(define-private (validate-chars-group-1 (name (string-ascii 255)))
  (and
    (check-name-char name u4)
    (check-name-char name u5)
    (check-name-char name u6)
    (check-name-char name u7)
    (check-name-char name u8)
    (check-name-char name u9)
    (check-name-char name u10)
    (check-name-char name u11)
    (check-name-char name u12)
    (check-name-char name u13)
    (check-name-char name u14)
    (check-name-char name u15)
  )
)

(define-private (validate-chars-group-2 (name (string-ascii 255)))
  (and
    (check-name-char name u16)
    (check-name-char name u17)
    (check-name-char name u18)
    (check-name-char name u19)
    (check-name-char name u20)
    (check-name-char name u21)
    (check-name-char name u22)
    (check-name-char name u23)
    (check-name-char name u24)
    (check-name-char name u25)
    (check-name-char name u26)
    (check-name-char name u27)
  )
)

(define-private (validate-chars-group-3 (name (string-ascii 255)))
  (and
    (check-name-char name u28)
    (check-name-char name u29)
    (check-name-char name u30)
    (check-name-char name u31)
    (check-name-char name u32)
    (check-name-char name u33)
    (check-name-char name u34)
    (check-name-char name u35)
    (check-name-char name u36)
    (check-name-char name u37)
    (check-name-char name u38)
    (check-name-char name u39)
  )
)

(define-private (validate-chars-group-4 (name (string-ascii 255)))
  (and
    (check-name-char name u40)
    (check-name-char name u41)
    (check-name-char name u42)
    (check-name-char name u43)
    (check-name-char name u44)
    (check-name-char name u45)
    (check-name-char name u46)
    (check-name-char name u47)
    (check-name-char name u48)
    (check-name-char name u49)
    (check-name-char name u50)
    (check-name-char name u51)
  )
)

(define-private (validate-chars-group-5 (name (string-ascii 255)))
  (and
    (check-name-char name u52)
    (check-name-char name u53)
    (check-name-char name u54)
    (check-name-char name u55)
    (check-name-char name u56)
    (check-name-char name u57)
    (check-name-char name u58)
    (check-name-char name u59)
    (check-name-char name u60)
    (check-name-char name u61)
    (check-name-char name u62)
    (check-name-char name u63)
  )
)

(define-read-only (has-valid-name-chars (name (string-ascii 255)))
  (let ((name-len (len name)))
    (and
      ;; Check first 4 characters
      (is-valid-character (unwrap-panic (element-at name u0)))
      (is-valid-character (unwrap-panic (element-at name u1)))
      (is-valid-character (unwrap-panic (element-at name u2)))
      (is-valid-character (unwrap-panic (element-at name u3)))
      ;; Check remaining characters in groups
      (or
        (<= name-len u4)
        (and
          (>= name-len u5)
          (validate-chars-group-1 name)
          (or
            (<= name-len u16)
            (and
              (>= name-len u17)
              (validate-chars-group-2 name)
              (or
                (<= name-len u28)
                (and
                  (>= name-len u29)
                  (validate-chars-group-3 name)
                  (or
                    (<= name-len u40)
                    (and
                      (>= name-len u41)
                      (validate-chars-group-4 name)
                      (or
                        (<= name-len u52)
                        (and
                          (>= name-len u53)
                          (validate-chars-group-5 name)
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)

(define-read-only (is-valid-name (name (string-ascii 255)))
  (let (
      (name-len (len name))
      (first-char (unwrap-panic (element-at name u0)))
      (last-char (unwrap-panic (element-at name (- name-len u1))))
    )
    (and
      (>= name-len u3) ;; Minimum 3 characters
      (<= name-len u64) ;; Maximum 64 characters
      (not (is-eq first-char "-")) ;; Cannot start with hyphen
      (not (is-eq last-char "-")) ;; Cannot end with hyphen
      (has-valid-name-chars name)
    )
  )
)

(define-read-only (get-name-info (name (string-ascii 255)))
  (begin
    (asserts! (is-valid-name name) ERR-INVALID-NAME)
    (ok (unwrap! (map-get? name-registry { name: name }) ERR-NAME-NOT-FOUND))
  )
)

(define-public (register-name
    (name (string-ascii 255))
    (period uint)
  )
  (begin
    ;; Validate name format first
    (asserts! (is-valid-name name) ERR-INVALID-NAME)

    ;; Check name availability 
    (asserts! (is-none (map-get? name-registry { name: name }))
      ERR-NAME-UNAVAILABLE
    )

    ;; Validate registration period
    (asserts!
      (and
        (>= period (var-get min-validity-period))
        (<= period (var-get max-validity-period))
      )
      ERR-INVALID-NAME
    )

    ;; Calculate total cost
    (let (
        (registration-cost (* (var-get base-fee) (/ period u31536000))) ;; Pro-rate by year
        (current-timestamp (current-time))
      )
      ;; Transfer registration fee
      (try! (stx-transfer? registration-cost tx-sender ADMIN-ACCOUNT))

      ;; Register name
      (ok (map-set name-registry { name: name } {
        holder: tx-sender,
        validity: (+ current-timestamp period),
        listing-amount: u0,
      }))
    )
  )
)

(define-public (extend-validity
    (name (string-ascii 255))
    (additional-period uint)
  )
  (begin
    ;; Validate name format first
    (asserts! (is-valid-name name) ERR-INVALID-NAME)

    ;; Get and verify name info
    (let (
        (name-info (try! (get-name-info name)))
        (current-holder (get holder name-info))
        (current-validity (get validity name-info))
        (extension-cost (* (var-get base-fee) (/ additional-period u31536000)))
        (current-timestamp (current-time))
      )
      ;; Validate caller is holder
      (asserts! (is-eq current-holder tx-sender) ERR-UNAUTHORIZED)

      ;; Transfer extension fee
      (try! (stx-transfer? extension-cost tx-sender ADMIN-ACCOUNT))

      ;; Update name validity
      (ok (map-set name-registry { name: name }
        (merge name-info { validity: (+ current-timestamp additional-period) })
      ))
    )
  )
)

```
