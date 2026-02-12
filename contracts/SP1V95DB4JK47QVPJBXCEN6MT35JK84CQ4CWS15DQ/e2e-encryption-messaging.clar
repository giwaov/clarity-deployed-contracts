(define-map public-keys
    principal
    { key: (buff 33), algorithm: (string-ascii 16), updated-at: uint }
)

(define-map messages
    { sender: principal, recipient: principal, message-id: uint }
    { 
        encrypted-content: (buff 1024),
        timestamp: uint,
        session-id: (buff 32)
    }
)

(define-map message-count
    { sender: principal, recipient: principal }
    uint
)

(define-constant err-no-public-key (err u100))
(define-constant err-invalid-algorithm (err u101))
(define-constant err-message-not-found (err u102))
(define-constant err-invalid-signature (err u103))

(define-read-only (get-public-key (user principal))
    (ok (map-get? public-keys user))
)

(define-read-only (get-message (sender principal) (recipient principal) (message-id uint))
    (ok (map-get? messages { sender: sender, recipient: recipient, message-id: message-id }))
)

(define-read-only (get-message-count (sender principal) (recipient principal))
    (ok (default-to u0 (map-get? message-count { sender: sender, recipient: recipient })))
)

(define-public (update-public-key (key (buff 33)) (algorithm (string-ascii 16)))
    (begin
        (map-set public-keys tx-sender
            { key: key, algorithm: algorithm, updated-at: stacks-block-time }
        )
        (ok true)
    )
)

(define-public (send-message 
    (recipient principal)
    (encrypted-content (buff 1024))
    (session-id (buff 32))
)
    (let
        (
            (recipient-key (unwrap! (map-get? public-keys recipient) err-no-public-key))
            (count (default-to u0 (map-get? message-count { sender: tx-sender, recipient: recipient })))
        )
        (map-set messages { sender: tx-sender, recipient: recipient, message-id: count }
            {
                encrypted-content: encrypted-content,
                timestamp: stacks-block-time,
                session-id: session-id
            }
        )
        (map-set message-count { sender: tx-sender, recipient: recipient } (+ count u1))
        (ok count)
    )
)

(define-public (verify-message-signature 
    (sender principal)
    (recipient principal)
    (message-id uint)
    (signature (buff 64))
    (message-hash (buff 32))
)
    (let
        (
            (sender-key-data (unwrap! (map-get? public-keys sender) err-no-public-key))
            (message-data (unwrap! (map-get? messages { sender: sender, recipient: recipient, message-id: message-id }) err-message-not-found))
        )
        (ok (secp256r1-verify message-hash signature (get key sender-key-data)))
    )
)

(define-public (delete-message (recipient principal) (message-id uint))
    (let
        (
            (message-data (unwrap! (map-get? messages { sender: tx-sender, recipient: recipient, message-id: message-id }) err-message-not-found))
        )
        (map-delete messages { sender: tx-sender, recipient: recipient, message-id: message-id })
        (ok true)
    )
)
