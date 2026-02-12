(impl-trait .dao-traits.proposal-script)

(define-public (execute)
  (begin
    (try! (contract-call? .dao-multisig set-threshold u3))
    (ok true)))