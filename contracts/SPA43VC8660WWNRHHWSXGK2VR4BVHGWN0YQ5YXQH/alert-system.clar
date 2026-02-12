;; alert-system.clar
;; System for broadcasting operational alerts

(define-data-var last-alert-id uint u0)

(define-map alerts
    uint
    { level: (string-ascii 20), message: (string-ascii 256), timestamp: uint }
)

(define-public (trigger-alert (level (string-ascii 20)) (message (string-ascii 256)))
    (let ((id (+ (var-get last-alert-id) u1)))
        (map-set alerts id { level: level, message: message, timestamp: burn-block-height })
        (var-set last-alert-id id)
        (ok id)
    )
)
