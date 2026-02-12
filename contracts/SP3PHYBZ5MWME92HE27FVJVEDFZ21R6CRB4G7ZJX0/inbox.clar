;; Contract: Messenger
;; Description: Sends messages only for registered users.

(define-map messages { to: principal } (string-ascii 100))

(define-public (send-msg (recipient principal) (text (string-ascii 100)))
    (let
        (
            ;; Check if sender has a registered username
            (sender-name (unwrap! (contract-call? .directory get-username tx-sender) (err u404)))
        )
        ;; Logic: Only registered users can send
        (asserts! (is-some sender-name) (err u401))
        
        ;; Save message
        (map-set messages { to: recipient } text)
        (ok "Message Sent")
    )
)