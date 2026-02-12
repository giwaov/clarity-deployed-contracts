;; Signal - A Simple On-Chain Guestbook
;; Leave your mark on the Stacks blockchain

;; Data storage
(define-map messages 
  { id: uint } 
  { 
    sender: principal,
    message: (string-ascii 280),
    timestamp: uint
  }
)

(define-data-var message-count uint u0)

;; Read-only functions
(define-read-only (get-message (id uint))
  (map-get? messages { id: id })
)

(define-read-only (get-total-messages)
  (var-get message-count)
)

;; Public functions
(define-public (leave-message (message (string-ascii 280)))
  (let
    (
      (new-id (+ (var-get message-count) u1))
    )
    (map-set messages 
      { id: new-id }
      {
        sender: tx-sender,
        message: message,
        timestamp: stacks-block-height
      }
    )
    (var-set message-count new-id)
    (ok new-id)
  )
)

;; Get recent messages (last 10)
(define-read-only (get-recent-messages)
  (let
    (
      (total (var-get message-count))
      (start (if (> total u10) (- total u9) u1))
    )
    (list 
      (get-message (- total u0))
      (get-message (- total u1))
      (get-message (- total u2))
      (get-message (- total u3))
      (get-message (- total u4))
      (get-message (- total u5))
      (get-message (- total u6))
      (get-message (- total u7))
      (get-message (- total u8))
      (get-message (- total u9))
    )
  )
)