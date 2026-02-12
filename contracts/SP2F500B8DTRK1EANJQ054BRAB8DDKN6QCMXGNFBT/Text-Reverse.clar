;; Contract 11: Text Reverse (Mock)
(define-data-var reversed-text (string-ascii 20) "")

(define-public (set-reversed (text (string-ascii 20)))
    (ok (var-set reversed-text text))
)

(define-read-only (get-reversed)
    (ok (var-get reversed-text))
)