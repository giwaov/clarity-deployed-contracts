;; Maintenance Mode
(define-data-var maintenance bool false)
(define-data-var maintenance-message (string-ascii 200) "System under maintenance")
(define-public (enable-maintenance (message (string-ascii 200)))
  (begin (var-set maintenance true) (var-set maintenance-message message) (ok true)))
(define-public (disable-maintenance)
  (begin (var-set maintenance false) (ok true)))
(define-read-only (is-maintenance)
  (ok (var-get maintenance)))
