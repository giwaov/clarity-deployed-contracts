;; simple-event-log.clar

(define-public (emit (tag (string-ascii 32)) (val uint))
  (begin
    (print {tag: tag, val: val, sender: tx-sender, height: burn-block-height})
    (ok true)))
