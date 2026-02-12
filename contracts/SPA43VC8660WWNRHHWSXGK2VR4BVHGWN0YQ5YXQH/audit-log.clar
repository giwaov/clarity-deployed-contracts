;; audit-log.clar
;; Immutable audit trail for operation codes.
;; Used for compliance logging of action types.

(define-map audit-events { user: principal, access-id: uint } uint)

(define-data-var global-nonce uint u0)

(define-public (log-event (op-code uint))
    (let
        (
            (current-nonce (var-get global-nonce))
        )
        (var-set global-nonce (+ current-nonce u1))
        (ok (map-set audit-events { user: tx-sender, access-id: current-nonce } op-code))
    )
)
