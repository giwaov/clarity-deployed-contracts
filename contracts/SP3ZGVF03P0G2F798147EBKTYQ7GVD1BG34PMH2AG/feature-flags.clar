;; Feature Flags
(define-map flags (string-ascii 50) {enabled: bool})
(define-public (set-flag (flag (string-ascii 50)) (enabled bool))
  (begin (map-set flags flag {enabled: enabled}) (ok true)))
(define-read-only (is-enabled (flag (string-ascii 50)))
  (default-to false (get enabled (map-get? flags flag))))
