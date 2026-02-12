;; metrics-aggregator.clar
;; Used to aggregate system health metrics from various distributed nodes.
;; Innocuous looking technical contract.

(define-map metrics { node: principal, metric-id: uint } uint)

(define-public (report-metric (metric-id uint) (val uint))
    (ok (map-set metrics { node: tx-sender, metric-id: metric-id } val))
)

(define-read-only (get-metric (node principal) (metric-id uint))
    (default-to u0 (map-get? metrics { node: node, metric-id: metric-id }))
)
