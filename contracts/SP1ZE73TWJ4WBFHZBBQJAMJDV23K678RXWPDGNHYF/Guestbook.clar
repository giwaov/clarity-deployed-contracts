
;; title: Guestbook
;; version: 1.0.0
;; summary: A simple on-chain guestbook
;; description: Allows users to leave messages and tracks recent signers.

;; traits
;;

;; token definitions
;;

;; constants
(define-constant ERR-NOT-FOUND (err u404))

;; data vars
(define-data-var next-id uint u0)
(define-data-var recent-signers (list 20 principal) (list))

;; data maps
(define-map messages uint { sender: principal, content: (string-utf8 500) })

;; public functions

(define-public (write-message (content (string-utf8 500)))
    (let
        (
            (id (var-get next-id))
            (caller tx-sender)
        )
        ;; Store the message
        (map-set messages id { sender: caller, content: content })
        
        ;; Increment ID
        (var-set next-id (+ id u1))
        
        ;; Update recent signers list
        ;; We use unwrap-panic because we know the list size is defined as 20
        ;; But realistically, if it's full, we might want to drop the oldest or just stop adding.
        ;; For this "practice", we will just try to append. If it fails (list full), we ignore the error and keep going.
        ;; Actually, let's keep it simple: just try to append. logic: (as-max-len? (append list item) 20)
        (var-set recent-signers (unwrap! (as-max-len? (append (var-get recent-signers) caller) u20) (ok id)))
        
        (ok id)
    )
)

;; read only functions

(define-read-only (get-message (id uint))
    (map-get? messages id)
)

(define-read-only (get-recent-signers)
    (var-get recent-signers)
)

(define-read-only (get-next-id)
    (var-get next-id)
)

;; private functions
;;
