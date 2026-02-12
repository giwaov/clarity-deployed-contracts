;; title: ZenithStax
;; version:
;; summary:
;; description:

;; traits
;;

;; traits
(define-map secret-vault principal (string-ascii 50))

;; Public: Store a message for a specific recipient
(define-public (store-secret (recipient principal) (message (string-ascii 50)))
  (begin
    ;; Only allow the sender to store one message for this recipient at a time
    (map-set secret-vault recipient message)
    (ok "Message secured. It will self-destruct after one read.")
  )
)

;; Public: Recipient reads the message, which then deletes it
(define-public (read-and-burn)
  (let (
    (message (unwrap! (map-get? secret-vault tx-sender) (err u404)))
  )
    ;; 1. Delete the message from the map (The "Burn")
    (map-delete secret-vault tx-sender)
    
    ;; 2. Return the message to the user
    (ok message)
  )
)
