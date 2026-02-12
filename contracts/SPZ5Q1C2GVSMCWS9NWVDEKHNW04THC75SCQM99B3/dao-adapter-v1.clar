(define-trait dao-adapter-trait
  (
    ;; Execute an action on behalf of the DAO.
    ;; - proposal-id: the proposal that authorized this call.
    ;; - sender: who initiated execution.
    ;; - payload: structured action data for clear dispatch.
    ;;   kind: "stx-transfer" | "ft-transfer"
    ;;   token: when kind is ft-transfer, the FT contract principal; none for STX.
    ;;   memo: optional memo for FT transfer (for SIP-010 compatibility).
    (execute (uint principal (tuple (kind (string-ascii 32)) (amount uint) (recipient principal) (token (optional principal)) (memo (optional (buff 34))))) (response bool uint))
    ;; Optional: return an identifying hash for the adapter logic to allow verification.
    (adapter-hash () (response (buff 32) uint))
  )
)
